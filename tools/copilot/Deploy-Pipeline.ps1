#requires -Version 7.0
<#
.SYNOPSIS
  Stellt Loesungen ueber die konfigurierte Power-Platform-Pipeline bereit.
.DESCRIPTION
  Benoetigt ein lokal eingerichtetes pac-Auth-Profil fuer den Pipeline-Host.
  Erst TEST, dann dieselbe Version nach PROD. Keine automatische Profilerstellung.
.EXAMPLE
  .\tools\copilot\Deploy-Pipeline.ps1 -SolutionName Task123Example -Stage TEST
.EXAMPLE
  .\tools\copilot\Deploy-Pipeline.ps1 -SolutionName Task123Example -Status
#>
param(
  [Parameter(Mandatory)][ValidatePattern('^[A-Za-z][A-Za-z0-9_]*$')][string]$SolutionName,
  [ValidateSet("TEST", "PROD")][string]$Stage = "TEST",
  [version]$NewVersion,
  [switch]$AllowProdWrite,
  [switch]$Status,
  [ValidateRange(1, 120)][int]$TimeoutMinutes = 30
)
$ErrorActionPreference = "Stop"
if (-not $Status -and $Stage -eq "PROD" -and -not $AllowProdWrite) {
  throw "PROD-Deploy nur mit -AllowProdWrite nach ausdruecklicher Freigabe."
}
. (Join-Path $PSScriptRoot "Common.ps1")
$config = Get-ProjectConfig
$dv = Join-Path $PSScriptRoot "dv.ps1"
$pipelineName = ConvertTo-ODataLiteral $config.Deployment.PipelineName
$pipelines = @(& $dv -Env host -Path "deploymentpipelines?`$select=deploymentpipelineid&`$filter=name eq '$pipelineName'")
if ($pipelines.Count -ne 1) { throw "Pipeline muss im konfigurierten Host eindeutig vorhanden sein." }
$pipelineId = $pipelines[0].deploymentpipelineid
$stages = @{}
foreach ($key in @("TEST", "PROD")) {
  $name = if ($key -eq "TEST") { $config.Deployment.TestStageName } else { $config.Deployment.ProdStageName }
  $name = ConvertTo-ODataLiteral $name
  $records = @(& $dv -Env host -Path "deploymentstages?`$select=deploymentstageid&`$filter=name eq '$name' and _deploymentpipelineid_value eq $pipelineId")
  if ($records.Count -ne 1) { throw "Stage $key muss innerhalb der Pipeline eindeutig vorhanden sein." }
  $stages[$key] = $records[0].deploymentstageid
}

function Get-Runs([string]$StageId, [switch]$Successful) {
  $filter = "artifactname eq '$SolutionName' and _deploymentstageid_value eq $StageId"
  if ($Successful) { $filter += " and stagerunstatus eq 200000002" }
  & $dv -Env host -Path ("deploymentstageruns?`$select=deploymentstagerunid,artifactversion,stagerunstatus,operation,errormessage,createdon,_deploymentstageid_value" +
    "&`$filter=$filter&`$orderby=createdon desc&`$top=20")
}

if ($Status) {
  foreach ($key in @("TEST", "PROD")) {
    Get-Runs $stages[$key] | Select-Object createdon, @{ n = "Stage"; e = { $key } }, artifactversion,
      @{ n = "Status"; e = { $_.'stagerunstatus@OData.Community.Display.V1.FormattedValue' } }, errormessage
  }
  return
}
if ($config.Environments.host -eq $config.Environments.prod -and -not $AllowProdWrite) {
  throw "Pipeline-Host entspricht Prod. Auch hier ist eine ausdrueckliche Freigabe erforderlich."
}
$solutions = @(& $dv -Env dev -Path "solutions?`$select=version,ismanaged&`$filter=uniquename eq '$SolutionName'")
if ($solutions.Count -ne 1 -or $solutions[0].ismanaged) { throw "Unmanaged Loesung muss auf Dev eindeutig vorhanden sein." }
$current = [version]$solutions[0].version
if ($Stage -eq "TEST") {
  if (-not $NewVersion) {
    $NewVersion = [version]::new($current.Major, $current.Minor, [Math]::Max($current.Build, 0), ([Math]::Max($current.Revision, 0) + 1))
  }
  if ($NewVersion -le $current -or $NewVersion.Revision -lt 0) {
    throw "TEST benoetigt eine hoehere vierteilige Loesungsversion."
  }
} else {
  $lastTest = Get-Runs $stages.TEST -Successful | Where-Object { $null -ne $_.operation } | Select-Object -First 1
  if (-not $lastTest -or -not $lastTest.artifactversion) { throw "Keine erfolgreiche TEST-Bereitstellung gefunden." }
  $testedVersion = [version]$lastTest.artifactversion
  if ($NewVersion -and $NewVersion -ne $testedVersion) { throw "PROD muss dieselbe Version wie TEST verwenden." }
  $current = $testedVersion
  $NewVersion = $testedVersion
}

Wait-DataverseImport -Env $(if ($Stage -eq "TEST") { "test" } else { "prod" }) -TimeoutMinutes $TimeoutMinutes
$authList = pac auth list 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { throw "pac auth list fehlgeschlagen. Power Platform CLI lokal einrichten." }
$previousIndex = ([regex]::Match($authList, '\[(\d+)\]\s+\*')).Groups[1].Value
if (-not $previousIndex) { throw "Aktives pac-Profil nicht erkennbar. Kein Profilwechsel vorgenommen; CLI-Ausgabe pruefen." }
$lastRunId = (Get-Runs $stages[$Stage] | Select-Object -First 1).deploymentstagerunid
$devEnvironmentId = (& $dv -Env dev -Path "RetrieveCurrentOrganization(AccessType=Microsoft.Dynamics.CRM.EndpointAccessType'Default')").Detail.EnvironmentId
if (-not $devEnvironmentId) { throw "Dev-Environment-ID konnte nicht ermittelt werden." }
try {
  pac auth select --name $config.Deployment.PacProfile | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Konfiguriertes pac-Profil fehlt oder ist nicht verwendbar. Lokal fuer den Pipeline-Host einrichten." }
  pac pipeline deploy --environment $devEnvironmentId --solutionName $SolutionName `
    --stageId $stages[$Stage] --currentVersion $current.ToString() --newVersion $NewVersion.ToString() --wait
  if ($LASTEXITCODE -ne 0) { throw "pac pipeline deploy fehlgeschlagen." }
} finally {
  pac auth select --index $previousIndex | Out-Null
  if ($LASTEXITCODE -ne 0) { Write-Warning "Vorheriges pac-Profil konnte nicht wiederhergestellt werden." }
}
$run = Get-Runs $stages[$Stage] | Select-Object -First 1
if (-not $run -or $run.deploymentstagerunid -eq $lastRunId -or [version]$run.artifactversion -ne $NewVersion) {
  throw "Kein neuer Pipeline-Lauf mit der erwarteten Version gefunden. Status manuell pruefen."
}
$runId = $run.deploymentstagerunid
$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
while ($run.stagerunstatus -ne 200000002 -and -not $run.errormessage -and (Get-Date) -lt $deadline) {
  Start-Sleep -Seconds 20
  $run = & $dv -Env host -Path "deploymentstageruns($runId)?`$select=artifactversion,stagerunstatus,errormessage"
}
if ($run.stagerunstatus -ne 200000002) { throw "Deployment nicht erfolgreich oder Timeout. Lauf $runId pruefen: $($run.errormessage)" }
"[$Stage] $SolutionName $($run.artifactversion) erfolgreich bereitgestellt (Lauf $runId)."
