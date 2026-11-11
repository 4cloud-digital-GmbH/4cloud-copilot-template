#requires -Version 7.0
<#
.SYNOPSIS
  Exportiert eine Lösung standardmäßig managed nach .copilot-work.
#>
param(
  [Parameter(Mandatory)][ValidatePattern('^[A-Za-z][A-Za-z0-9_]*$')][string]$SolutionName,
  [string]$OutDir = (Join-Path $PSScriptRoot "..\..\.copilot-work"),
  [ValidateSet("dev", "test")][string]$Env = "dev",
  [switch]$Unmanaged
)
$ErrorActionPreference = "Stop"
$dv = Join-Path $PSScriptRoot "dv.ps1"
$solution = & $dv -Env $Env -Path "solutions?`$select=version&`$filter=uniquename eq '$SolutionName'"
if (-not $solution) { throw "Lösung $SolutionName nicht auf $Env gefunden." }
$result = & $dv -Env $Env -Method POST -Path "ExportSolution" -Body @{
  SolutionName = $SolutionName; Managed = (-not $Unmanaged)
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$suffix = if ($Unmanaged) { "unmanaged" } else { "managed" }
$file = Join-Path $OutDir ("{0}_{1}_{2}.zip" -f $SolutionName, ($solution.version -replace '\.', '_'), $suffix)
[IO.File]::WriteAllBytes($file, [Convert]::FromBase64String($result.ExportSolutionFile))
$file
