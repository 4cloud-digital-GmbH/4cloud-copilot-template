#requires -Version 7.0
<#
.SYNOPSIS
  Übernimmt die zentrale Vorlage ohne Überschreiben in ein Kundenverzeichnis.
.DESCRIPTION
  Kopiert ausschließlich Vorlagendateien und erzeugt lokale Konfigurationen aus
  den Beispielen. Vorhandene Dateien bleiben erhalten; Unterschiede werden als
  Konflikt gemeldet. Die Auswertung des Kundenprojekts übernimmt project-setup.
.EXAMPLE
  .\tools\copilot\Initialize-Project.ps1 -ProjectPath 'C:\Repos\Kundenprojekt'
#>
param(
  [Parameter(Mandatory)][string]$ProjectPath
)
$ErrorActionPreference = "Stop"
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..")).TrimEnd('\')
if (-not [IO.Path]::IsPathFullyQualified($ProjectPath)) { throw "ProjectPath muss ein absoluter Pfad sein." }
if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
  throw "Zielverzeichnis fehlt. Zuerst das Kundenrepository klonen oder das Zielverzeichnis anlegen."
}
$targetRoot = (Get-Item -LiteralPath $ProjectPath).FullName.TrimEnd('\')
if ($targetRoot -eq $sourceRoot -or
    $targetRoot.StartsWith("$sourceRoot\", [StringComparison]::OrdinalIgnoreCase) -or
    $sourceRoot.StartsWith("$targetRoot\", [StringComparison]::OrdinalIgnoreCase)) {
  throw "Mastervorlage und Ziel dürfen nicht identisch oder ineinander verschachtelt sein."
}

$files = @(
  ".github\copilot-instructions.md",
  ".github\instructions\dataverse-plugins.instructions.md",
  ".github\instructions\webresources.instructions.md",
  ".github\skills\project-setup\SKILL.md",
  ".github\skills\devops-task\SKILL.md",
  "CrmAccess\appsettings.example.json",
  "CrmAccess\credentials.example.json",
  "README.md",
  "tools\copilot\Common.ps1",
  "tools\copilot\dv.ps1",
  "tools\copilot\DevOps.ps1",
  "tools\copilot\Deploy-Pipeline.ps1",
  "tools\copilot\Export-Solution.ps1",
  "tools\copilot\Import-Solution.ps1",
  "tools\copilot\Remove-ActiveCustomization.ps1",
  "tools\copilot\Initialize-Project.ps1",
  "tools\copilot\Test-Template.ps1"
)
$localFiles = @("CrmAccess\appsettings.json", "CrmAccess\credentials.json")
foreach ($relative in @($files) + @($localFiles) + @(".gitignore")) {
  $destination = Join-Path $targetRoot $relative
  if (Test-Path -LiteralPath $destination -PathType Container) {
    throw "Dateipfad ist bereits ein Verzeichnis: $relative"
  }
}
foreach ($relative in @($files) + @(".gitignore")) {
  $source = Join-Path $sourceRoot $relative
  if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Vorlagendatei fehlt: $relative" }
}

# Schutzregeln vor dem Erzeugen lokaler Konfigurationen ergänzen.
$ignoreFile = Join-Path $targetRoot ".gitignore"
$rules = (Get-Content -LiteralPath (Join-Path $sourceRoot ".gitignore") |
  Where-Object { $_ -and -not $_.StartsWith("#") }) -join "`n"
$existingIgnore = if (Test-Path -LiteralPath $ignoreFile) { [IO.File]::ReadAllText($ignoreFile) } else { "" }
$normalized = $existingIgnore.Replace("`r`n", "`n").TrimEnd()
if (-not $normalized.EndsWith($rules, [StringComparison]::Ordinal)) {
  $prefix = if ($existingIgnore) { $existingIgnore.TrimEnd() + "`n`n" } else { "" }
  [IO.File]::WriteAllText($ignoreFile, "$prefix$rules`n", [Text.UTF8Encoding]::new($false))
  [pscustomobject]@{ Path = ".gitignore"; Status = "Merged" }
}
foreach ($relative in $files) {
  $source = Join-Path $sourceRoot $relative
  $destination = Join-Path $targetRoot $relative
  if (Test-Path -LiteralPath $destination) {
    $same = (Get-FileHash -LiteralPath $source).Hash -eq (Get-FileHash -LiteralPath $destination).Hash
    [pscustomobject]@{ Path = $relative; Status = $(if ($same) { "Unchanged" } else { "Conflict" }) }
    continue
  }
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
  Copy-Item -LiteralPath $source -Destination $destination -ErrorAction Stop
  [pscustomobject]@{ Path = $relative; Status = "Created" }
}
foreach ($relative in $localFiles) {
  $destination = Join-Path $targetRoot $relative
  if (Test-Path -LiteralPath $destination) {
    [pscustomobject]@{ Path = $relative; Status = "Preserved" }
    continue
  }
  # Immer zentrale Beispiele verwenden, niemals lokale Master-Zugangsdaten.
  $example = $relative.Replace(".json", ".example.json")
  Copy-Item -LiteralPath (Join-Path $sourceRoot $example) -Destination $destination -ErrorAction Stop
  [pscustomobject]@{ Path = $relative; Status = "Created" }
}
