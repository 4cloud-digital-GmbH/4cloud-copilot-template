#requires -Version 7.0

function Get-ProjectConfig {
  param([string]$Root = (Join-Path $PSScriptRoot "..\.."))
  $file = Join-Path $Root "CrmAccess\appsettings.json"
  if (-not (Test-Path -LiteralPath $file)) { throw "Lokale appsettings.json fehlt. Skill project-setup verwenden." }
  $json = Get-Content -LiteralPath $file -Raw
  if ($json -match '\{\{[A-Z][A-Z0-9_]*\}\}') {
    throw "Projektkonfiguration enthält Platzhalter. Skill project-setup verwenden."
  }
  $config = $json | ConvertFrom-Json
  foreach ($section in @("Project", "Environments", "AzureDevOps", "Deployment", "Repository")) {
    if (-not $config.$section) { throw "Konfigurationsabschnitt fehlt: $section" }
  }
  foreach ($key in @("dev", "test", "prod", "host")) {
    $value = $config.Environments.$key
    $uri = $null
    if (-not [uri]::TryCreate($value, [UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -ne "https" -or $uri.UserInfo -or $uri.Query -or
        $uri.Fragment -or $uri.AbsolutePath -ne "/") {
      throw "Environments.$key muss eine HTTPS-Basis-URL ohne Pfad oder Zugangsdaten sein."
    }
    $config.Environments.$key = $uri.GetLeftPart([UriPartial]::Authority).TrimEnd('/')
  }
  $urls = @($config.Environments.dev, $config.Environments.test, $config.Environments.prod)
  if (@($urls | Sort-Object -Unique).Count -ne 3) { throw "Dev, Test und Prod müssen getrennte URLs haben." }
  foreach ($key in @("Organization", "Project")) {
    if ([string]::IsNullOrWhiteSpace($config.AzureDevOps.$key)) { throw "AzureDevOps.$key fehlt." }
  }
  if ($config.AzureDevOps.Organization -notmatch '^[A-Za-z0-9][A-Za-z0-9-]*$') {
    throw "AzureDevOps.Organization muss ein Organisations-Slug ohne URL sein."
  }
  $legacyPipelineName = [string]$config.Deployment.PipelineName
  if (-not [string]::IsNullOrWhiteSpace($legacyPipelineName) -and
      [string]::IsNullOrWhiteSpace($config.Deployment.TestPipelineName) -and
      [string]::IsNullOrWhiteSpace($config.Deployment.ProdPipelineName)) {
    $config.Deployment | Add-Member -NotePropertyName TestPipelineName -NotePropertyValue $legacyPipelineName
    $config.Deployment | Add-Member -NotePropertyName ProdPipelineName -NotePropertyValue $legacyPipelineName
  }
  foreach ($key in @("TestPipelineName", "ProdPipelineName", "TestStageName", "ProdStageName", "PacProfile")) {
    if ([string]::IsNullOrWhiteSpace($config.Deployment.$key)) { throw "Deployment.$key fehlt." }
  }
  if ($config.Deployment.TestPipelineName -eq $config.Deployment.ProdPipelineName -and
      $config.Deployment.TestStageName -eq $config.Deployment.ProdStageName) {
    throw "Test- und Prod-Stage derselben Pipeline müssen verschieden sein."
  }
  $config
}

function Get-ProjectCredentials {
  param(
    [ValidateSet("dev", "test", "prod", "host")][string]$Env = "dev",
    [string]$Root = (Join-Path $PSScriptRoot "..\..")
  )
  $file = Join-Path $Root "CrmAccess\credentials.json"
  if (-not (Test-Path -LiteralPath $file)) { throw "Lokale credentials.json fehlt." }
  $credentials = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
  $environmentCredentials = if ($credentials.Environments) {
    $credentials.Environments.$Env
  } else {
    $credentials
  }
  if (-not $environmentCredentials) { throw "credentials.json: Eintrag für $Env fehlt." }
  foreach ($key in @("TenantId", "ClientId", "ClientSecret")) {
    $value = [string]$(if ($key -eq "TenantId") { $credentials.TenantId } else { $environmentCredentials.$key })
    if ([string]::IsNullOrWhiteSpace($value) -or $value -match '\{\{[A-Z][A-Z0-9_]*\}\}') {
      $field = if ($key -eq "TenantId") { "TenantId" } else { "Environments.$Env.$key" }
      throw "credentials.json: $field fehlt oder ist noch ein Platzhalter. Lokal ausfüllen, nicht im Chat."
    }
  }
  $resolvedCredentials = [pscustomobject]@{
    TenantId = [string]$credentials.TenantId
    ClientId = [string]$environmentCredentials.ClientId
    ClientSecret = [string]$environmentCredentials.ClientSecret
  }
  foreach ($key in @("TenantId", "ClientId")) {
    $guid = [guid]::Empty
    if (-not [guid]::TryParse($resolvedCredentials.$key, [ref]$guid)) { throw "credentials.json: $Env.$key ist keine GUID." }
  }
  $resolvedCredentials
}

function Get-DataverseConnection {
  param(
    [Parameter(Mandatory)][ValidateSet("dev", "test", "prod", "host")][string]$Env,
    [switch]$Write,
    [switch]$AllowProdWrite
  )
  $config = Get-ProjectConfig
  $base = $config.Environments.$Env
  if ($Write -and ($Env -eq "prod" -or $base -eq $config.Environments.prod) -and -not $AllowProdWrite) {
    throw "Prod ist nur lesend erlaubt. Schreiben nur mit -AllowProdWrite nach ausdrücklicher Freigabe."
  }
  $credentialEnv = $Env
  if ($Env -eq "host") {
    $matchingEnvironments = @(@("dev", "test", "prod") | Where-Object { $config.Environments.$_ -eq $base })
    if ($matchingEnvironments.Count -eq 1) { $credentialEnv = $matchingEnvironments[0] }
  }
  $credentials = Get-ProjectCredentials -Env $credentialEnv
  $token = Invoke-RestMethod -Method Post `
    -Uri "https://login.microsoftonline.com/$($credentials.TenantId)/oauth2/v2.0/token" -Body @{
      client_id = $credentials.ClientId
      client_secret = $credentials.ClientSecret
      scope = "$base/.default"
      grant_type = "client_credentials"
    }
  if (-not $token.access_token) { throw "Kein Dataverse-Zugriffstoken erhalten." }
  # Tokens bleiben im Prozess; keine kundenübergreifenden Token-Dateien.
  @{ Base = $base; Headers = @{ Authorization = ("Bearer " + [string]$token.access_token) } }
}

function ConvertTo-ODataLiteral {
  param([Parameter(Mandatory)][string]$Value)
  $Value.Replace("'", "''")
}

function Wait-DataverseImport {
  param(
    [Parameter(Mandatory)][ValidateSet("test", "prod")][string]$Env,
    [ValidateRange(1, 120)][int]$TimeoutMinutes = 30
  )
  $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
  $dv = Join-Path $PSScriptRoot "dv.ps1"
  while (& $dv -Env $Env -Path "importjobs?`$select=solutionname&`$filter=completedon eq null and startedon ne null") {
    if ((Get-Date) -ge $deadline) { throw "Timeout: Auf $Env läuft weiterhin ein Import. Kein neuer Import gestartet." }
    Write-Host "[$Env] anderer Import läuft, warte 30 s."
    Start-Sleep -Seconds 30
  }
}
