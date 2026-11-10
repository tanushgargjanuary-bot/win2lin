#Requires -Version 5.1
Import-Module PSScriptAnalyzer -ErrorAction Stop
$r = Invoke-ScriptAnalyzer -Path 'C:\Users\Tanush Garg\Win2Lin\scripts' -Recurse -Severity Warning,Error
if ($r) {
  $r | Format-Table -AutoSize
  Write-Host "Total: $(@($r).Count) issue(s)"
} else {
  Write-Host "No Warning/Error issues found."
}
