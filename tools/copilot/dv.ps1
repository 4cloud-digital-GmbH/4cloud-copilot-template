#requires -Version 7.0
<#
.SYNOPSIS
  Ruft die Dataverse-Web-API mit lokaler Projektkonfiguration auf.
.EXAMPLE
  .\tools\copilot\dv.ps1 -Env test -Path 'solutions?$select=uniquename,version'
#>
param(
  [Parameter(Mandatory)][ValidateSet("dev", "test", "prod", "host")][string]$Env,
  [Parameter(Mandatory)][string]$Path,
  [ValidateSet("GET", "POST", "PATCH", "PUT", "DELETE", "HEAD", "OPTIONS")][string]$Method = "GET",
  $Body = $null,
  [hashtable]$Headers = @{},
  [switch]$Raw,
  [switch]$AllowProdWrite
)
$ErrorActionPreference = "Stop"
if ($Env -eq "prod" -and $Method -ne "GET" -and -not $AllowProdWrite) {
  throw "Prod ist nur lesend erlaubt. Schreiben nur mit -AllowProdWrite nach Freigabe."
}
if ($Path -match '^\w+:' -or $Path.StartsWith('/') -or $Path.Contains('\') -or
    $Path -match '(^|/)\.\.(/|$)' -or $Path -match '(?i)%2e|%2f|%5c') {
  throw "-Path muss ein relativer Dataverse-API-Pfad sein."
}
. (Join-Path $PSScriptRoot "Common.ps1")
$connection = Get-DataverseConnection -Env $Env -Write:($Method -ne "GET") -AllowProdWrite:$AllowProdWrite
$h = @{
  Accept = "application/json"
  "OData-Version" = "4.0"
  "OData-MaxVersion" = "4.0"
  Prefer = 'odata.include-annotations="*"'
}
foreach ($key in $Headers.Keys) { $h[$key] = $Headers[$key] }
$h.Authorization = $connection.Headers.Authorization
$request = @{ Method = $Method; Headers = $h; Uri = "$($connection.Base)/api/data/v9.2/$Path" }
if ($null -ne $Body) {
  $json = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Depth 30 }
  $request.Body = [Text.Encoding]::UTF8.GetBytes($json)
  $request.ContentType = "application/json; charset=utf-8"
}
$result = Invoke-RestMethod @request
if ($Raw) { $result }
elseif ($null -ne $result -and $result.PSObject.Properties["value"]) { $result.value }
else { $result }
