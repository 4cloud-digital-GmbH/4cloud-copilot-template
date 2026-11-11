#requires -Version 7.0
<#
.SYNOPSIS
  Führt Offline-Tests mit temporären Konfigurationen und simulierten Diensten aus.
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
    if ($_.Exception.Message -notmatch $Pattern) { throw "Unerwarteter Fehler beim Test für: $Pattern" }
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
    catch { throw "Ungültiges JSON in CrmAccess\$name (Inhalt wird nicht ausgegeben)." }
    $script:checks++
  }
}
$settingsTemplate = Get-Content -LiteralPath (Join-Path $root "CrmAccess\appsettings.example.json") -Raw
$credentialsTemplate = Get-Content -LiteralPath (Join-Path $root "CrmAccess\credentials.example.json") -Raw
$setup = Get-Content -LiteralPath (Join-Path $root ".github\skills\project-setup\SKILL.md") -Raw
$placeholders = @([regex]::Matches("$settingsTemplate`n$credentialsTemplate", '\{\{([A-Z][A-Z0-9_]*)\}\}') |
  ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
foreach ($name in $placeholders) {
  Assert-True ($setup -match "\b$([regex]::Escape($name))\b") "Einrichtungsfrage fehlt für $name"
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
  $initialize = Join-Path $PSScriptRoot "Initialize-Project.ps1"
  $customer = Join-Path $fixture "Kundenprojekt mit Leerzeichen"
  New-Item -ItemType Directory -Path $customer | Out-Null
  $masterBefore = (Get-FileHash -LiteralPath (Join-Path $root "CrmAccess\appsettings.example.json")).Hash
  $copied = @(& $initialize -ProjectPath $customer)
  Assert-True (Test-Path -LiteralPath (Join-Path $customer ".github\skills\project-setup\SKILL.md")) "Zentralen Skill ins Ziel übernehmen"
  Assert-True (Test-Path -LiteralPath (Join-Path $customer "tools\copilot\dv.ps1")) "Hilfsskripte ins Ziel übernehmen"
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $customer ".git"))) "Keine Master-Git-Metadaten kopieren"
  foreach ($name in @("appsettings", "credentials")) {
    $local = Get-Content -LiteralPath (Join-Path $customer "CrmAccess\$name.json") -Raw
    $example = Get-Content -LiteralPath (Join-Path $root "CrmAccess\$name.example.json") -Raw
    Assert-True ($local -ceq $example) "Lokale $name nur aus dem Beispiel erzeugen"
  }
  $ignorePath = Join-Path $customer ".gitignore"
  $ignoreBefore = [IO.File]::ReadAllText($ignorePath)
  $secondCopy = @(& $initialize -ProjectPath $customer)
  Assert-True (@($secondCopy | Where-Object Status -eq "Created").Count -eq 0) "Erneuter Aufruf erzeugt keine Dateien"
  Assert-True ([IO.File]::ReadAllText($ignorePath) -ceq $ignoreBefore) "Ignore-Regeln bei Wiederholung nicht duplizieren"

  $customerReadme = Join-Path $customer "README.md"
  Set-Content -LiteralPath $customerReadme -Value "Vorhandene Kundendokumentation"
  $customerConfig = Join-Path $customer "CrmAccess\appsettings.json"
  Set-Content -LiteralPath $customerConfig -Value '{"Existing":"Kundenwert"}'
  $customerCredentials = Join-Path $customer "CrmAccess\credentials.json"
  Set-Content -LiteralPath $customerCredentials -Value '{"ClientSecret":"offline-existing-dummy"}'
  Set-Content -LiteralPath $ignorePath -Value "custom-output/`n!/CrmAccess/credentials.json"
  $preservedPaths = @($customerReadme, $customerConfig, $customerCredentials)
  $beforeHashes = @($preservedPaths | ForEach-Object { (Get-FileHash -LiteralPath $_).Hash })
  $conflicts = @(& $initialize -ProjectPath $customer)
  $afterHashes = @($preservedPaths | ForEach-Object { (Get-FileHash -LiteralPath $_).Hash })
  Assert-True (($beforeHashes -join ",") -eq ($afterHashes -join ",")) "Bestehende Dokumentation, Konfiguration und Secrets erhalten"
  Assert-True (@($conflicts | Where-Object { $_.Path -eq "README.md" -and $_.Status -eq "Conflict" }).Count -eq 1) "Dateikonflikt statt Überschreiben melden"
  $mergedIgnore = [IO.File]::ReadAllText($ignorePath)
  Assert-True ($mergedIgnore.Contains("custom-output/")) "Vorhandene Ignore-Regeln erhalten"
  Assert-True ($mergedIgnore.LastIndexOf("/CrmAccess/credentials.json") -gt $mergedIgnore.IndexOf("!/CrmAccess/credentials.json")) "Schutzregel nach vorhandener Ausnahme ergänzen"
  Assert-True ((Get-FileHash -LiteralPath (Join-Path $root "CrmAccess\appsettings.example.json")).Hash -eq $masterBefore) "Master-Beispiel bleibt unverändert"
  Assert-Throws { & $initialize -ProjectPath $root } "Mastervorlage"
  Assert-Throws { & $initialize -ProjectPath (Split-Path -Parent $root) } "Mastervorlage"
  Assert-Throws { & $initialize -ProjectPath "relative-path" } "absoluter Pfad"
  Assert-Throws { & $initialize -ProjectPath (Join-Path $fixture "missing") } "Zielverzeichnis fehlt"
  $blocked = Join-Path $fixture "blocked"
  New-Item -ItemType Directory -Path (Join-Path $blocked ".github\copilot-instructions.md") | Out-Null
  Assert-Throws { & $initialize -ProjectPath $blocked } "bereits ein Verzeichnis"
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $blocked ".gitignore"))) "Pfadkonflikt vor jeglichem Schreiben erkennen"

  $junctionTarget = Join-Path $fixture "outside-target"
  $linkedCustomer = Join-Path $fixture "linked-customer"
  New-Item -ItemType Directory -Path $junctionTarget, $linkedCustomer | Out-Null
  $junction = Join-Path $linkedCustomer ".github"
  try {
    New-Item -ItemType Junction -Path $junction -Target $junctionTarget | Out-Null
    & $initialize -ProjectPath $linkedCustomer | Out-Null
    Assert-True (Test-Path -LiteralPath (Join-Path $junctionTarget "copilot-instructions.md")) "Dateien über Junction ins verknüpfte Ziel kopieren"
  } finally {
    if (Test-Path -LiteralPath $junction) { [IO.Directory]::Delete($junction) }
  }
  $global:offlineRequests = [Collections.Generic.List[object]]::new()
  $global:offlinePacCalls = [Collections.Generic.List[string]]::new()
  $global:offlineDeployedStage = $null
  $global:offlineImportFailed = $false
  $global:offlineTestStageId = "11111111-1111-1111-1111-111111111111"
  $global:offlineProdStageId = "22222222-2222-2222-2222-222222222222"
  $global:offlineTestPipelineId = "33333333-3333-3333-3333-333333333333"
  $global:offlineProdPipelineId = "44444444-4444-4444-4444-444444444444"

  function Invoke-RestMethod {
    param($Method, $Uri, $Headers, $Body, $ContentType)
    $global:offlineRequests.Add(@{ Method = $Method; Uri = [string]$Uri; Headers = $Headers; Body = $Body })
    if ($Uri -like "https://login.microsoftonline.com/*") {
      return [pscustomobject]@{ access_token = "offline-token"; expires_in = 3600 }
    }
    if ($Uri -match '/deploymentpipelines\?') {
      $id = if ($Uri -match "ExampleTestPipeline") { $global:offlineTestPipelineId } else { $global:offlineProdPipelineId }
      return [pscustomobject]@{ value = @([pscustomobject]@{ deploymentpipelineid = $id }) }
    }
    if ($Uri -match '/deploymentstages\?') {
      if ($Uri -match "Quality Gate") {
        if (-not $Uri.Contains($global:offlineTestPipelineId)) { throw "TEST-Stage muss zur TEST-Pipeline gehören." }
        $id = $global:offlineTestStageId
      } else {
        if (-not $Uri.Contains($global:offlineProdPipelineId)) { throw "PROD-Stage muss zur PROD-Pipeline gehören." }
        $id = $global:offlineProdStageId
      }
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
    DEVOPS_PROJECT = "Example Project"; STATE_TODO = "New"; STATE_DOING = "Active"; STATE_REVIEW = "Review"; STATE_TEST = "Testing"
    STATE_READY_FOR_PROD = "Ready"; STATE_DONE = "Resolved"; STATE_CLOSED = "Closed"; STATE_REMOVED = "Removed"
    TEST_PIPELINE_NAME = "ExampleTestPipeline"; PROD_PIPELINE_NAME = "ExampleProdPipeline"
    TEST_STAGE_NAME = "Quality Gate"; PROD_STAGE_NAME = "Production"
    PAC_PROFILE_NAME = "OfflineProfile"; DEFAULT_BRANCH = "main"; PLUGIN_PATHS = "Plugins"
    WEBRESOURCE_PATH = "WebResources"; TEST_COMMAND = "node --test"; PLUGIN_BUILD_COMMAND = "dotnet build"
    TENANT_ID = "55555555-5555-5555-5555-555555555555"
    DEV_CLIENT_ID = "66666666-6666-6666-6666-666666666666"; DEV_CLIENT_SECRET = "offline-dev-dummy"
    TEST_CLIENT_ID = "77777777-7777-7777-7777-777777777777"; TEST_CLIENT_SECRET = "offline-test-dummy"
    PROD_CLIENT_ID = "88888888-8888-8888-8888-888888888888"; PROD_CLIENT_SECRET = "offline-prod-dummy"
    HOST_CLIENT_ID = "99999999-9999-9999-9999-999999999999"; HOST_CLIENT_SECRET = "offline-host-dummy"
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
  $changed = $filledConfig | ConvertFrom-Json
  $changed.Deployment.ProdStageName = $changed.Deployment.TestStageName
  $changed | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configFile
  $sameStageConfig = Get-ProjectConfig -Root $fixture
  Assert-True ($sameStageConfig.Deployment.ProdStageName -eq $sameStageConfig.Deployment.TestStageName) "Gleiche Stage-Namen in getrennten Pipelines sind zulässig"
  $changed.Deployment.ProdPipelineName = $changed.Deployment.TestPipelineName
  $changed | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configFile
  Assert-Throws { Get-ProjectConfig -Root $fixture } "derselben Pipeline"
  $legacyConfig = $filledConfig | ConvertFrom-Json
  $legacyConfig.Deployment = [pscustomobject]@{
    PipelineName = "ExampleLegacyPipeline"
    TestStageName = "Quality Gate"
    ProdStageName = "Production"
    PacProfile = "OfflineProfile"
  }
  $legacyConfig | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configFile
  $legacyPipelineConfig = Get-ProjectConfig -Root $fixture
  Assert-True ($legacyPipelineConfig.Deployment.TestPipelineName -eq "ExampleLegacyPipeline" -and
    $legacyPipelineConfig.Deployment.ProdPipelineName -eq "ExampleLegacyPipeline") "Legacy-Einzelpipeline bleibt kompatibel"
  Set-Content -LiteralPath $configFile -Value $filledConfig
  $devCredentials = Get-ProjectCredentials -Root $fixture
  $testCredentials = Get-ProjectCredentials -Env test -Root $fixture
  $prodCredentials = Get-ProjectCredentials -Env prod -Root $fixture
  Assert-True ($devCredentials.ClientId -eq $values.DEV_CLIENT_ID -and
    $testCredentials.ClientId -eq $values.TEST_CLIENT_ID -and
    $prodCredentials.ClientId -eq $values.PROD_CLIENT_ID) "Umgebungsspezifische Service Principals"
  $changed = $filledConfig | ConvertFrom-Json
  $changed.Environments.host = $changed.Environments.prod
  $changed | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configFile
  Get-DataverseConnection -Env host | Out-Null
  $prodHostTokenRequest = @($global:offlineRequests | Where-Object { $_.Uri -like "https://login.microsoftonline.com/*" } | Select-Object -Last 1)[0]
  Assert-True ($prodHostTokenRequest.Body.client_id -eq $values.PROD_CLIENT_ID) "Pipeline-Host nutzt bei gleicher PROD-URL die PROD-Identität"
  Set-Content -LiteralPath $configFile -Value $filledConfig
  $script:checks++
  $changed = $filledConfig | ConvertFrom-Json
  $changed.Environments.test = $changed.Environments.prod + "/"
  $changed | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configFile
  Assert-Throws { Get-ProjectConfig -Root $fixture } "getrennte URLs"
  Set-Content -LiteralPath $configFile -Value $filledConfig

  $tools = Join-Path $fixture "tools\copilot"
  $global:offlineRequests.Clear()
  Assert-Throws { & "$tools\dv.ps1" -Env prod -Path accounts -Method PATCH -Body @{} } "Prod"
  Assert-Throws { & "$tools\Import-Solution.ps1" -Env prod -Zip missing.zip } "Prod"
  Assert-Throws { & "$tools\Remove-ActiveCustomization.ps1" -Env prod -ComponentName WebResource -ComponentId ([guid]::Empty) } "Prod"
  Assert-Throws { & "$tools\Deploy-Pipeline.ps1" -SolutionName Task123Example -Stage PROD } "PROD"
  Assert-True ($global:offlineRequests.Count -eq 0) "Prod-Sperren müssen vor Remote-Aufrufen greifen"
  $changed = $filledConfig | ConvertFrom-Json
  $changed.Environments.host = $changed.Environments.prod
  $changed | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configFile
  Assert-Throws { & "$tools\dv.ps1" -Env host -Path accounts -Method POST -Body @{} } "Prod"
  Assert-True ($global:offlineRequests.Count -eq 0) "Prod-Alias darf Schreibsperre nicht umgehen"
  Set-Content -LiteralPath $configFile -Value $filledConfig

  $account = & "$tools\dv.ps1" -Env dev -Path accounts
  Assert-True ($account.name -eq "Offline account") "Dataverse-Collection entpacken"
  Assert-True ($global:offlineRequests[-1].Headers.Authorization -match '^Bearer\s+\S+$') "Bearer-Authentifizierung"
  & "$tools\dv.ps1" -Env test -Path accounts | Out-Null
  $testTokenRequest = @($global:offlineRequests | Where-Object { $_.Uri -like "https://login.microsoftonline.com/*" } | Select-Object -Last 1)[0]
  Assert-True ($testTokenRequest.Body.client_id -eq $values.TEST_CLIENT_ID) "Dataverse-Test verwendet Test-Identität"
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
  $hostTokenRequest = @($global:offlineRequests | Where-Object {
    $_.Uri -like "https://login.microsoftonline.com/*" -and $_.Body.scope -eq "https://host.example.invalid/.default"
  } | Select-Object -Last 1)[0]
  Assert-True ($hostTokenRequest.Body.client_id -eq $values.HOST_CLIENT_ID) "Separater Pipeline-Host verwendet eigene Identität"
  $pipelineQueries = @($global:offlineRequests | Where-Object { $_.Uri -match '/deploymentpipelines\?' })
  Assert-True (@($pipelineQueries | Where-Object Uri -match "ExampleTestPipeline").Count -ge 1) "TEST verwendet seine konfigurierte Pipeline"
  Assert-True (@($pipelineQueries | Where-Object Uri -match "ExampleProdPipeline").Count -ge 1) "PROD verwendet seine konfigurierte Pipeline"
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
"Offline-Tests erfolgreich: $script:checks Prüfungen; $($placeholders.Count) eindeutige Platzhalter mit Einrichtungsfragen."
"Lokale Kundenwerte wurden nicht auf Vollständigkeit getestet; Mastervorlagen enthalten absichtlich Platzhalter."
