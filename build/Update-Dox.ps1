$ModuleName = 'Jumper'
$DocsFolder = Join-Path $PSScriptRoot '..\Docs' -Resolve
$LogPath    = Join-Path $PSScriptRoot 'logs' 'help-update.log' -Resolve

Get-Variable DocsFolder, LogPath
"`e[33m---`e[0m"
Get-Variable * -Scope Script
"`e[33m---`e[0m"

Import-Module platyps
Import-Module $ModuleName -Force

$parameters = @{
    Path = $DocsFolder
    RefreshModulePage = $true
    AlphabeticParamsOrder = $true
    UpdateInputOutput = $true
    ExcludeDontShow = $true
    LogPath = $LogPath
    Encoding = [System.Text.Encoding]::UTF8
}
Update-MarkdownHelpModule @parameters
