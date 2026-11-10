#requires -Version 7.0
<#
.SYNOPSIS
  Liest und bearbeitet Azure-DevOps-Work-Items fuer das konfigurierte Projekt.
.DESCRIPTION
  Azure CLI und az login erforderlich. Kommentare als HTML uebergeben.
#>
param(
  [Parameter(Mandatory)][ValidateSet("Get", "Comments", "Mine", "Comment", "SetState", "Assign")][string]$Action,
  [int]$Id,
  [string]$Html,
  [string]$HtmlFile,
  [string[]]$Mention = @(),
  [string]$State,
  [string]$AssignTo
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Common.ps1")
$config = Get-ProjectConfig
if ($Action -ne "Mine" -and $Id -le 0) { throw "-Id muss eine positive Work-Item-Nummer sein." }
if ($Action -eq "SetState" -and -not $State) { throw "-State angeben." }
if ($Action -eq "Assign" -and -not $AssignTo) { throw "-AssignTo angeben." }
$organization = $config.AzureDevOps.Organization
$project = [uri]::EscapeDataString($config.AzureDevOps.Project)
$token = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv
if ($LASTEXITCODE -ne 0 -or -not $token) { throw "Kein Azure-DevOps-Token. Lokal az login ausfuehren." }
$headers = @{ Authorization = "Bearer $token" }
$base = "https://dev.azure.com/$organization/$project/_apis/wit"

function Send-WorkItemRequest($Method, $Uri, $Body, $ContentType = "application/json; charset=utf-8") {
  Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -ContentType $ContentType `
    -Body ([Text.Encoding]::UTF8.GetBytes($Body))
}

function Resolve-Identity([string]$Mail) {
  $uri = "https://vssps.dev.azure.com/$organization/_apis/identities?searchFilter=General&filterValue=$([uri]::EscapeDataString($Mail))&api-version=7.1"
  $identities = @( (Invoke-RestMethod -Headers $headers -Uri $uri).value )
  $matches = @($identities | Where-Object {
    $_.properties.Mail.'$value' -eq $Mail -or $_.properties.Account.'$value' -eq $Mail
  })
  if ($matches.Count -ne 1) { throw "Identitaet nicht eindeutig ueber E-Mail aufloesbar." }
  $matches[0]
}

switch ($Action) {
  "Get" {
    $item = Invoke-RestMethod -Headers $headers -Uri "$base/workitems/$($Id)?`$expand=relations&api-version=7.1"
    $fields = $item.fields
    [pscustomobject]@{
      Id = $item.id; Type = $fields.'System.WorkItemType'; Title = $fields.'System.Title'
      State = $fields.'System.State'; AssignedTo = $fields.'System.AssignedTo'.uniqueName
      CreatedBy = $fields.'System.CreatedBy'.uniqueName; Priority = $fields.'Microsoft.VSTS.Common.Priority'
      Parent = @($item.relations | Where-Object rel -eq "System.LinkTypes.Hierarchy-Reverse" |
        ForEach-Object { ($_.url -split "/")[-1] })
      Description = $fields.'System.Description'; ReproSteps = $fields.'Microsoft.VSTS.TCM.ReproSteps'
      AcceptanceCriteria = $fields.'Microsoft.VSTS.Common.AcceptanceCriteria'
      Attachments = @($item.relations | Where-Object rel -eq "AttachedFile" | ForEach-Object url)
    }
  }
  "Comments" {
    $continuation = $null
    do {
      $uri = "$base/workitems/$Id/comments?order=asc&api-version=7.1-preview.4"
      if ($continuation) { $uri += "&continuationToken=$([uri]::EscapeDataString($continuation))" }
      $page = Invoke-RestMethod -Headers $headers -Uri $uri
      $page.comments | Select-Object id, @{ n = "by"; e = { $_.createdBy.displayName } }, createdDate, text
      $continuation = $page.continuationToken
    } while ($continuation)
  }
  "Mine" {
    $terminal = @($config.AzureDevOps.TerminalStates | Where-Object { $_ } | Sort-Object -Unique)
    if (-not $terminal.Count) { throw "AzureDevOps.TerminalStates fehlt." }
    $states = ($terminal | ForEach-Object { "'$(ConvertTo-ODataLiteral $_)'" }) -join ","
    $query = "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = @project AND [System.AssignedTo] = @me AND [System.State] NOT IN ($states) ORDER BY [System.ChangedDate] DESC"
    $ids = @((Send-WorkItemRequest Post "$base/wiql?api-version=7.1" (@{ query = $query } | ConvertTo-Json)).workItems.id |
      Where-Object { $_ })
    for ($offset = 0; $offset -lt $ids.Count; $offset += 200) {
      $batch = $ids[$offset..([Math]::Min($offset + 199, $ids.Count - 1))]
      $uri = "$base/workitems?ids=$($batch -join ',')&fields=System.Id,System.WorkItemType,System.Title,System.State,System.ChangedDate&api-version=7.1"
      (Invoke-RestMethod -Headers $headers -Uri $uri).value | ForEach-Object {
        [pscustomobject]@{
          Id = $_.id; Type = $_.fields.'System.WorkItemType'; Title = $_.fields.'System.Title'
          State = $_.fields.'System.State'; Changed = $_.fields.'System.ChangedDate'
        }
      }
    }
  }
  "Comment" {
    $text = if ($HtmlFile) { Get-Content -LiteralPath $HtmlFile -Raw -Encoding utf8 } else { $Html }
    if (-not $text) { throw "-Html oder -HtmlFile angeben." }
    $prefix = ($Mention | ForEach-Object {
      $identity = Resolve-Identity $_
      $name = if ($identity.customDisplayName) { $identity.customDisplayName } else { $identity.providerDisplayName }
      $name = [System.Net.WebUtility]::HtmlEncode($name)
      "<a href=`"#`" data-vss-mention=`"version:2.0,$($identity.id)`">@$name</a> "
    }) -join ""
    if ($prefix) { $text = "<div>$prefix</div>$text" }
    $result = Send-WorkItemRequest Post "$base/workitems/$Id/comments?api-version=7.1-preview.4" `
      (@{ text = $text; format = "html" } | ConvertTo-Json)
    "Kommentar $($result.id) an $Id"
  }
  "SetState" {
    $body = ConvertTo-Json -InputObject @(@{ op = "add"; path = "/fields/System.State"; value = $State })
    $result = Send-WorkItemRequest Patch "$base/workitems/$($Id)?api-version=7.1" $body "application/json-patch+json"
    "$Id -> $($result.fields.'System.State')"
  }
  "Assign" {
    $body = ConvertTo-Json -InputObject @(@{ op = "add"; path = "/fields/System.AssignedTo"; value = $AssignTo })
    $result = Send-WorkItemRequest Patch "$base/workitems/$($Id)?api-version=7.1" $body "application/json-patch+json"
    "$Id -> $($result.fields.'System.AssignedTo'.uniqueName)"
  }
}
