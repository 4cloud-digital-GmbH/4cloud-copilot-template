#requires -Version 7.0
<#
.SYNOPSIS
  Importiert eine managed Lösungs-ZIP. Nur als dokumentierte Pipeline-Ausnahme.
#>
param(
  [Parameter(Mandatory)][ValidateSet("test", "prod")][string]$Env,
  [Parameter(Mandatory)][string]$Zip,
  [switch]$OverwriteUnmanagedCustomizations,
  [switch]$AllowProdWrite,
  [ValidateRange(1, 120)][int]$TimeoutMinutes = 30
)
$ErrorActionPreference = "Stop"
if ($Env -eq "prod" -and -not $AllowProdWrite) { throw "Prod-Import nur mit -AllowProdWrite nach Freigabe." }
. (Join-Path $PSScriptRoot "Common.ps1")
$dv = Join-Path $PSScriptRoot "dv.ps1"
$zipFile = (Resolve-Path -LiteralPath $Zip).Path
$archive = [IO.Compression.ZipFile]::OpenRead($zipFile)
try {
  $entry = $archive.GetEntry("solution.xml")
  if (-not $entry) { throw "ZIP enthält keine solution.xml." }
  $reader = [IO.StreamReader]::new($entry.Open())
  try { [xml]$manifest = $reader.ReadToEnd() } finally { $reader.Dispose() }
  if ($manifest.ImportExportXml.SolutionManifest.Managed -ne "1") {
    throw "Nach Test/Prod dürfen nur managed Lösungen importiert werden."
  }
} finally { $archive.Dispose() }
$base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($zipFile))
Wait-DataverseImport -Env $Env -TimeoutMinutes $TimeoutMinutes
$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
do {
  $jobId = [guid]::NewGuid()
  try {
    & $dv -Env $Env -Method POST -Path "ImportSolution" -AllowProdWrite:$AllowProdWrite -Body @{
      OverwriteUnmanagedCustomizations = [bool]$OverwriteUnmanagedCustomizations
      PublishWorkflows = $true; CustomizationFile = $base64; ImportJobId = $jobId
    } | Out-Null
    break
  } catch {
    $message = if ($_.ErrorDetails.Message) { $_.ErrorDetails.Message } else { $_.Exception.Message }
    if ($message -notmatch "80071151" -or (Get-Date) -ge $deadline) { throw }
    Write-Host "[$Env] konkurrierender Import, neuer Versuch in 30 s."
    Start-Sleep -Seconds 30
  }
} while ($true)
$job = & $dv -Env $Env -Path "importjobs($jobId)?`$select=progress,data,solutionname,completedon"
while (-not $job.completedon -and (Get-Date) -lt $deadline) {
  Start-Sleep -Seconds 10
  $job = & $dv -Env $Env -Path "importjobs($jobId)?`$select=progress,data,solutionname,completedon"
}
if (-not $job.completedon) { throw "Timeout: Importjob $jobId ist noch nicht abgeschlossen. Nicht erneut starten, zuerst Status prüfen." }
if (-not $job.data) { throw "Importjob $jobId enthält kein Ergebnisprotokoll." }
[xml]$result = $job.data
$failures = @($result.SelectNodes("//result") | Where-Object { $_.result -ne "success" })
foreach ($failure in $failures) { Write-Host "FEHLER: $($failure.errortext)" }
if ($failures.Count -or [decimal]$job.progress -lt 100) { throw "Importjob $jobId meldet Fehler oder unvollständigen Fortschritt." }
"[$Env] Importjob $jobId ($($job.solutionname)) erfolgreich abgeschlossen."
