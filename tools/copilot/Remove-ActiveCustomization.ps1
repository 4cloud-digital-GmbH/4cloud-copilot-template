#requires -Version 7.0
<#
.SYNOPSIS
  Entfernt eine Active-Schicht per SOAP. Zuvor vergleichen und Backup erstellen.
#>
param(
  [Parameter(Mandatory)][ValidateSet("dev", "test", "prod")][string]$Env,
  [Parameter(Mandatory)][string]$ComponentName,
  [Parameter(Mandatory)][guid]$ComponentId,
  [switch]$AllowProdWrite
)
$ErrorActionPreference = "Stop"
if ($Env -eq "prod" -and -not $AllowProdWrite) { throw "Prod nur mit -AllowProdWrite nach Freigabe." }
. (Join-Path $PSScriptRoot "Common.ps1")
$connection = Get-DataverseConnection -Env $Env -Write -AllowProdWrite:$AllowProdWrite
$name = [System.Security.SecurityElement]::Escape($ComponentName)
$soap = @"
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
 <s:Body>
  <Execute xmlns="http://schemas.microsoft.com/xrm/2011/Contracts/Services" xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
   <request xmlns:a="http://schemas.microsoft.com/xrm/2011/Contracts">
    <a:Parameters xmlns:b="http://schemas.datacontract.org/2004/07/System.Collections.Generic">
     <a:KeyValuePairOfstringanyType><b:key>SolutionComponentName</b:key><b:value i:type="c:string" xmlns:c="http://www.w3.org/2001/XMLSchema">$name</b:value></a:KeyValuePairOfstringanyType>
     <a:KeyValuePairOfstringanyType><b:key>ComponentId</b:key><b:value i:type="c:guid" xmlns:c="http://schemas.microsoft.com/2003/10/Serialization/">$ComponentId</b:value></a:KeyValuePairOfstringanyType>
    </a:Parameters>
    <a:RequestId i:nil="true"/>
    <a:RequestName>RemoveActiveCustomizations</a:RequestName>
   </request>
  </Execute>
 </s:Body>
</s:Envelope>
"@
$headers = @{
  Authorization = $connection.Headers.Authorization
  SOAPAction = "http://schemas.microsoft.com/xrm/2011/Contracts/Services/IOrganizationService/Execute"
}
$response = Invoke-WebRequest -Method Post -Uri "$($connection.Base)/XRMServices/2011/Organization.svc/web" `
  -ContentType "text/xml; charset=utf-8" -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($soap))
if ($response.Content -match '<(?:\w+:)?Fault\b|<faultstring\b') {
  throw "Dataverse meldet einen SOAP-Fehler beim Entfernen der Active-Schicht."
}
"[$Env] $ComponentName $ComponentId : Active-Schicht entfernt."
