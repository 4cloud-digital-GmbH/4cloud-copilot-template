#requires -Version 7.0

function Get-ProjectConfig {
  param([string]$Root = (Join-Path $PSScriptRoot "..\.."))
  $file = Join-Path $Root "CrmAccess\appsettings.json"
  if (-not (Test-Path -LiteralPath $file)) { throw "Lokale appsettings.json fehlt. Skill project-setup verwenden." }
  $json = Get-Content -LiteralPath $file -Raw
  if ($json -match '\{\{[A-Z][A-Z0-9_]*\}\}') {
    throw "Projektkonfiguration enthaelt Platzhalter. Skill project-setup verwenden."
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
  if (@($urls | Sort-Object -Unique).Count -ne 3) { throw "Dev, Test und Prod muessen getrennte URLs haben." }
  foreach ($key in @("Organization", "Project")) {
    if ([string]::IsNullOrWhiteSpace($config.AzureDevOps.$key)) { throw "AzureDevOps.$key fehlt." }
  }
  if ($config.AzureDevOps.Organization -notmatch '^[A-Za-z0-9][A-Za-z0-9-]*$') {
    throw "AzureDevOps.Organization muss ein Organisations-Slug ohne URL sein."
  }
  foreach ($key in @("PipelineName", "TestStageName", "ProdStageName", "PacProfile")) {
    if ([string]::IsNullOrWhiteSpace($config.Deployment.$key)) { throw "Deployment.$key fehlt." }
  }
  if ($config.Deployment.TestStageName -eq $config.Deployment.ProdStageName) {
    throw "Test- und Prod-Stage muessen verschieden sein."
  }
  $config
}

function Get-ProjectCredentials {
  param([string]$Root = (Join-Path $PSScriptRoot "..\.."))
  $file = Join-Path $Root "CrmAccess\credentials.json"
  if (-not (Test-Path -LiteralPath $file)) { throw "Lokale credentials.json fehlt." }
  $credentials = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
  foreach ($key in @("TenantId", "ClientId", "ClientSecret")) {
    $value = [string]$credentials.$key
    if ([string]::IsNullOrWhiteSpace($value) -or $value -match '\{\{[A-Z][A-Z0-9_]*\}\}') {
      throw "credentials.json: $key fehlt oder ist noch ein Platzhalter. Lokal ausfuellen, nicht im Chat."
    }
  }
  foreach ($key in @("TenantId", "ClientId")) {
    $guid = [guid]::Empty
    if (-not [guid]::TryParse($credentials.$key, [ref]$guid)) { throw "credentials.json: $key ist keine GUID." }
  }
  $credentials
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
    throw "Prod ist nur lesend erlaubt. Schreiben nur mit -AllowProdWrite nach ausdruecklicher Freigabe."
  }
  $credentials = Get-ProjectCredentials
  $token = Invoke-RestMethod -Method Post `
    -Uri "https://login.microsoftonline.com/$($credentials.TenantId)/oauth2/v2.0/token" -Body @{
      client_id = $credentials.ClientId
      client_secret = $credentials.ClientSecret
      scope = "$base/.default"
      grant_type = "client_credentials"
    }
  if (-not $token.access_token) { throw "Kein Dataverse-Zugriffstoken erhalten." }
  # Tokens bleiben im Prozess; keine kundenuebergreifenden Token-Dateien.
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
    if ((Get-Date) -ge $deadline) { throw "Timeout: Auf $Env laeuft weiterhin ein Import. Kein neuer Import gestartet." }
    Write-Host "[$Env] anderer Import laeuft, warte 30 s."
    Start-Sleep -Seconds 30
  }
}
