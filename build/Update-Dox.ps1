$ModuleName = 'Jumper'
$DocsFolder = Join-Path $PSScriptRoot '..\Docs' -Resolve
$HelpFileFolder = Join-Path $DocsFolder '..' -Resolve

Import-Module platyps
Import-Module $ModuleName -Force

$parameters = @{
    Path = $DocsFolder
    RefreshModulePage = $true
    AlphabeticParamsOrder = $true
    UpdateInputOutput = $true
    ExcludeDontShow = $true
    LogPath = Join-Path $DocsFolder 'logs'
    Encoding = 'UTF8BOM'
}
Update-MarkdownHelpModule @parameters
