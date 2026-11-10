#requires -Version 7.0
<#
.SYNOPSIS
  Fuehrt Offline-Tests mit temporaeren Konfigurationen und simulierten Diensten aus.
#>
$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$script:checks = 0

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "TEST FEHLGESCHLAGEN: $Message" }
  $script:checks++
}

function Assert-Throws([scriptblock]$Action, [string]$Pattern) {
  $caught = $false
  try { & $Action | Out-Null }
  catch {
    if ($_.Exception.Message -notmatch $Pattern) { throw "Unerwarteter Fehler beim Test fuer: $Pattern" }
    $caught = $true
  }
  Assert-True $caught "Erwarteter Fehler fehlt: $Pattern"
}

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot -Filter "*.ps1") {
  $tokens = $null
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
  Assert-True ($errors.Count -eq 0) "PowerShell-Syntax: $($file.Name)"
}
foreach ($name in @("appsettings.example.json", "credentials.example.json", "appsettings.json", "credentials.json")) {
  $file = Join-Path $root "CrmAccess\$name"
  if (Test-Path -LiteralPath $file) {
    try { Get-Content -LiteralPath $file -Raw | ConvertFrom-Json | Out-Null }
    catch { throw "Ungueltiges JSON in CrmAccess\$name (Inhalt wird nicht ausgegeben)." }
    $script:checks++
  }
}
$settingsTemplate = Get-Content -LiteralPath (Join-Path $root "CrmAccess\appsettings.example.json") -Raw
$credentialsTemplate = Get-Content -LiteralPath (Join-Path $root "CrmAccess\credentials.example.json") -Raw
$setup = Get-Content -LiteralPath (Join-Path $root ".github\skills\project-setup\SKILL.md") -Raw
$placeholders = @([regex]::Matches("$settingsTemplate`n$credentialsTemplate", '\{\{([A-Z][A-Z0-9_]*)\}\}') |
  ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
foreach ($name in $placeholders) {
  Assert-True ($setup -match "\b$([regex]::Escape($name))\b") "Einrichtungsfrage fehlt fuer $name"
}
$ignore = Get-Content -LiteralPath (Join-Path $root ".gitignore")
foreach ($entry in @("/CrmAccess/credentials.json", "/CrmAccess/appsettings.json", "/.copilot-work/")) {
  Assert-True ($ignore -contains $entry) "Ignore-Regel fehlt: $entry"
}

$fixture = Join-Path ([IO.Path]::GetTempPath()) ("4cloud-template-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path (Join-Path $fixture "CrmAccess"), (Join-Path $fixture "tools\copilot") | Out-Null
try {
  Get-ChildItem -LiteralPath $PSScriptRoot -Filter "*.ps1" |
    Where-Object Name -ne "Test-Template.ps1" |
    Copy-Item -Destination (Join-Path $fixture "tools\copilot")
  $global:offlineRequests = [Collections.Generic.List[object]]::new()
  $global:offlinePacCalls = [Collections.Generic.List[string]]::new()
  $global:offlineDeployedStage = $null
  $global:offlineImportFailed = $false
  $global:offlineTestStageId = "11111111-1111-1111-1111-111111111111"
  $global:offlineProdStageId = "22222222-2222-2222-2222-222222222222"

  function Invoke-RestMethod {
    param($Method, $Uri, $Headers, $Body, $ContentType)
    $global:offlineRequests.Add(@{ Method = $Method; Uri = [string]$Uri; Headers = $Headers; Body = $Body })
    if ($Uri -like "https://login.microsoftonline.com/*") {
      return [pscustomobject]@{ access_token = "offline-token"; expires_in = 3600 }
    }
    if ($Uri -match '/deploymentpipelines\?') {
      return [pscustomobject]@{ value = @([pscustomobject]@{ deploymentpipelineid = "33333333-3333-3333-3333-333333333333" }) }
    }
    if ($Uri -match '/deploymentstages\?') {
      $id = if ($Uri -match "Quality Gate") { $global:offlineTestStageId } else { $global:offlineProdStageId }
      return [pscustomobject]@{ value = @([pscustomobject]@{ deploymentstageid = $id }) }
    }
    if ($Uri -match '/deploymentstageruns\?') {
      if ($Uri -match 'stagerunstatus eq') {
        return [pscustomobject]@{ value = @([pscustomobject]@{
          deploymentstagerunid = "old-test"; artifactversion = "1.0.0.1"; operation = 0; stagerunstatus = 200000002
        }) }
      }
      if ($global:offlineDeployedStage -and $Uri.Contains($global:offlineDeployedStage)) {
        return [pscustomobject]@{ value = @([pscustomobject]@{
          deploymentstagerunid = "new-run"; artifactversion = "1.0.0.1"; operation = 0; stagerunstatus = 200000002
        }) }
      }
      return [pscustomobject]@{ value = @() }
    }
    if ($Uri -match '/RetrieveCurrentOrganization') {
      return [pscustomobject]@{ Detail = [pscustomobject]@{ EnvironmentId = "44444444-4444-4444-4444-444444444444" } }
    }
    if ($Uri -match '/solutions\?') {
      return [pscustomobject]@{ value = @([pscustomobject]@{ version = "1.0.0.0"; ismanaged = $false }) }
    }
    if ($Uri -match '/ExportSolution$') {
      return [pscustomobject]@{ ExportSolutionFile = [Convert]::ToBase64String([byte[]]@(1, 2, 3)) }
    }
    if ($Uri -match '/importjobs\?') { return [pscustomobject]@{ value = @() } }
    if ($Uri -match '/ImportSolution$') { return $null }
    if ($Uri -match '/importjobs\(') {
      $data = if ($global:offlineImportFailed) { '<root><result result="failure" errortext="offline failure"/></root>' }
        else { '<root><result result="success"/></root>' }
      return [pscustomobject]@{ progress = 100; data = $data; solutionname = "Task123Example"; completedon = "2026-01-01" }
    }
    if ($Uri -match '/_apis/wit/wiql') { return [pscustomobject]@{ workItems = @() } }
    if ($Uri -match '/_apis/wit/workitems/123\?') {
      return [pscustomobject]@{ id = 123; fields = [pscustomobject]@{ "System.Title" = "Offline item" } }
    }
    if ($Uri -match '/api/data/v9.2/accounts') {
      return [pscustomobject]@{ value = @([pscustomobject]@{ name = "Offline account" }) }
    }
    throw "Offline-Test: unerwarteter API-Aufruf."
  }

  function Invoke-WebRequest {
    param($Method, $Uri, $Headers, $Body, $ContentType)
    $global:offlineRequests.Add(@{ Method = $Method; Uri = [string]$Uri; Headers = $Headers; Body = $Body })
    if ($Uri -notlike "https://dev.example.invalid/XRMServices/*") { throw "Unerwarteter SOAP-Aufruf." }
    [pscustomobject]@{ StatusCode = 200 }
  }

  function az {
    $global:LASTEXITCODE = 0
    "offline-devops-token"
  }

  function pac {
    $arguments = @($args)
    $global:offlinePacCalls.Add(($arguments -join " "))
    $global:LASTEXITCODE = 0
    if (($arguments -join " ") -eq "auth list") { return "[1] * OfflineProfile" }
    if ($arguments[0] -eq "pipeline") {
      $index = [Array]::IndexOf($arguments, "--stageId")
      $global:offlineDeployedStage = [string]$arguments[$index + 1]
    }
  }

  $configFile = Join-Path $fixture "CrmAccess\appsettings.json"
  Set-Content -LiteralPath $configFile -Value $settingsTemplate
  Set-Content -LiteralPath (Join-Path $fixture "CrmAccess\credentials.json") -Value $credentialsTemplate
  . (Join-Path $fixture "tools\copilot\Common.ps1")
  Assert-Throws { Get-ProjectConfig -Root $fixture } "Platzhalter"
  Assert-Throws { Get-ProjectCredentials -Root $fixture } "Platzhalter"

  $values = @{
    PROJECT_NAME = "Offline Project"; CUSTOMER_NAME = "Example Customer"; COMMUNICATION_LANGUAGE = "de-DE"
    SOLUTION_PUBLISHER_PREFIX = "example"; DEV_URL = "https://dev.example.invalid"
    TEST_URL = "https://test.example.invalid"; PROD_URL = "https://prod.example.invalid"
    PIPELINE_HOST_URL = "https://host.example.invalid"; DEVOPS_ORGANIZATION = "example-org"
    DEVOPS_PROJECT = "Example Project"; STATE_TODO = "New"; STATE_DOING = "Active"; STATE_TEST = "Testing"
    STATE_READY_FOR_PROD = "Ready"; STATE_DONE = "Resolved"; STATE_CLOSED = "Closed"; STATE_REMOVED = "Removed"
    PIPELINE_NAME = "Example Pipeline"; TEST_STAGE_NAME = "Quality Gate"; PROD_STAGE_NAME = "Production"
    PAC_PROFILE_NAME = "OfflineProfile"; DEFAULT_BRANCH = "main"; PLUGIN_PATHS = "Plugins"
    WEBRESOURCE_PATH = "WebResources"; TEST_COMMAND = "node --test"; PLUGIN_BUILD_COMMAND = "dotnet build"
    TENANT_ID = "55555555-5555-5555-5555-555555555555"; CLIENT_ID = "66666666-6666-6666-6666-666666666666"
    CLIENT_SECRET = "offline-dummy-not-a-real-secret"
  }
  $filledConfig = [regex]::Replace($settingsTemplate, '\{\{([A-Z][A-Z0-9_]*)\}\}', {
    param($match)
    $values[$match.Groups[1].Value]
  })
  $filledCredentials = [regex]::Replace($credentialsTemplate, '\{\{([A-Z][A-Z0-9_]*)\}\}', {
    param($match)
    $values[$match.Groups[1].Value]
  })
  Set-Content -LiteralPath $configFile -Value $filledConfig
  Set-Content -LiteralPath (Join-Path $fixture "CrmAccess\credentials.json") -Value $filledCredentials
  $config = Get-ProjectConfig -Root $fixture
  Assert-True ($config.Environments.host -ne $config.Environments.dev) "Separater Pipeline-Host"
  Get-ProjectCredentials -Root $fixture | Out-Null
  $script:checks++
  $changed = $filledConfig | ConvertFrom-Json
  $changed.Environments.test = $changed.Environments.prod + "/"
  $changed | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configFile
  Assert-Throws { Get-ProjectConfig -Root $fixture } "getrennte URLs"
  Set-Content -LiteralPath $configFile -Value $filledConfig

  $tools = Join-Path $fixture "tools\copilot"
  Assert-Throws { & "$tools\dv.ps1" -Env prod -Path accounts -Method PATCH -Body @{} } "Prod"
  Assert-Throws { & "$tools\Import-Solution.ps1" -Env prod -Zip missing.zip } "Prod"
  Assert-Throws { & "$tools\Remove-ActiveCustomization.ps1" -Env prod -ComponentName WebResource -ComponentId ([guid]::Empty) } "Prod"
  Assert-Throws { & "$tools\Deploy-Pipeline.ps1" -SolutionName Task123Example -Stage PROD } "PROD"
  Assert-True ($global:offlineRequests.Count -eq 0) "Prod-Sperren muessen vor Remote-Aufrufen greifen"
  $changed = $filledConfig | ConvertFrom-Json
  $changed.Environments.host = $changed.Environments.prod
  $changed | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configFile
  Assert-Throws { & "$tools\dv.ps1" -Env host -Path accounts -Method POST -Body @{} } "Prod"
  Assert-True ($global:offlineRequests.Count -eq 0) "Prod-Alias darf Schreibsperre nicht umgehen"
  Set-Content -LiteralPath $configFile -Value $filledConfig

  $account = & "$tools\dv.ps1" -Env dev -Path accounts
  Assert-True ($account.name -eq "Offline account") "Dataverse-Collection entpacken"
  Assert-True ($global:offlineRequests[-1].Headers.Authorization -match '^Bearer\s+\S+$') "Bearer-Authentifizierung"
  $raw = & "$tools\dv.ps1" -Env dev -Path accounts -Raw
  Assert-True ($raw.value[0].name -eq "Offline account") "Raw-Antwort erhalten"
  Assert-Throws { & "$tools\dv.ps1" -Env dev -Path "https://other.example.invalid/" } "relativer"

  $export = & "$tools\Export-Solution.ps1" -SolutionName Task123Example
  Assert-True ((Test-Path -LiteralPath $export) -and $export.EndsWith("_managed.zip")) "Managed-Export"
  $exportRequest = $global:offlineRequests | Where-Object { $_.Uri -match '/ExportSolution$' } | Select-Object -Last 1
  $exportBody = [Text.Encoding]::UTF8.GetString($exportRequest.Body) | ConvertFrom-Json
  Assert-True $exportBody.Managed "Export standardmaessig managed"

  $zip = Join-Path $fixture "solution.zip"
  foreach ($managed in @("0", "1")) {
    $archive = [IO.Compression.ZipFile]::Open($zip, [IO.Compression.ZipArchiveMode]::Create)
    try {
      $writer = [IO.StreamWriter]::new($archive.CreateEntry("solution.xml").Open())
      try { $writer.Write("<ImportExportXml><SolutionManifest><Managed>$managed</Managed></SolutionManifest></ImportExportXml>") }
      finally { $writer.Dispose() }
    } finally { $archive.Dispose() }
    if ($managed -eq "0") {
      Assert-Throws { & "$tools\Import-Solution.ps1" -Env test -Zip $zip } "nur managed"
      Remove-Item -LiteralPath $zip
    } else {
      $importResult = & "$tools\Import-Solution.ps1" -Env test -Zip $zip
      Assert-True ($importResult -match "erfolgreich") "Erfolgreicher managed Import"
      $global:offlineImportFailed = $true
      Assert-Throws { & "$tools\Import-Solution.ps1" -Env test -Zip $zip 6>$null } "meldet Fehler"
      $global:offlineImportFailed = $false
    }
  }
  & "$tools\Remove-ActiveCustomization.ps1" -Env dev -ComponentName "A&B" -ComponentId ([guid]::Empty) | Out-Null
  $soap = [Text.Encoding]::UTF8.GetString($global:offlineRequests[-1].Body)
  Assert-True ($soap -match 'A&amp;B') "SOAP-Komponentenname XML-escapen"
  Assert-True ($global:offlineRequests[-1].Headers.Authorization -match '^Bearer\s+\S+$') "SOAP-Authentifizierung ohne Token-Datei"

  $item = & "$tools\DevOps.ps1" -Action Get -Id 123
  Assert-True ($item.Title -eq "Offline item") "DevOps-Projekt aus Konfiguration"
  & "$tools\DevOps.ps1" -Action Mine | Out-Null
  $wiqlRequest = $global:offlineRequests | Where-Object { $_.Uri -match '/wiql' } | Select-Object -Last 1
  $wiql = [Text.Encoding]::UTF8.GetString($wiqlRequest.Body) | ConvertFrom-Json
  Assert-True ($wiql.query -match "'Resolved'") "Kundenspezifische Endstatus in WIQL"
  Assert-True ($wiqlRequest.Uri -match 'example-org/Example%20Project/') "Projektname URL-kodieren"

  $deployResult = & "$tools\Deploy-Pipeline.ps1" -SolutionName Task123Example -Stage TEST
  Assert-True ($deployResult -match "erfolgreich") "TEST-Pipeline mit konfigurierten Stage-Namen"
  Assert-True ($global:offlinePacCalls[-1] -eq "auth select --index 1") "Aktives pac-Profil wiederherstellen"
  $hostRequests = @($global:offlineRequests | Where-Object { $_.Uri -match '/deployment(pipelines|stages|stageruns)' })
  Assert-True (@($hostRequests | Where-Object { $_.Uri -notlike 'https://host.example.invalid/*' }).Count -eq 0) "Pipeline-Abfragen auf separatem Host"
  $global:offlineDeployedStage = $null
  Assert-Throws {
    & "$tools\Deploy-Pipeline.ps1" -SolutionName Task123Example -Stage PROD -AllowProdWrite -NewVersion 2.0.0.0
  } "dieselbe Version"
  $deployResult = & "$tools\Deploy-Pipeline.ps1" -SolutionName Task123Example -Stage PROD -AllowProdWrite
  Assert-True ($deployResult -match "erfolgreich") "PROD verwendet erfolgreich getestete Version"
  $prodCall = $global:offlinePacCalls | Where-Object { $_ -like "pipeline deploy*" } | Select-Object -Last 1
  Assert-True ($prodCall -match '--currentVersion 1.0.0.1 --newVersion 1.0.0.1') "Identische TEST-/PROD-Artefaktversion"
} finally {
  Remove-Item -LiteralPath $fixture -Recurse -Force
}
"Offline-Tests erfolgreich: $script:checks Pruefungen; $($placeholders.Count) eindeutige Platzhalter mit Einrichtungsfragen."
"Lokale Kundenwerte wurden nicht auf Vollstaendigkeit getestet; Mastervorlagen enthalten absichtlich Platzhalter."
