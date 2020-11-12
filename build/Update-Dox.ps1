$ModuleName = 'Jumper'
$DocsFolder = Join-Path $PSScriptRoot '..\Docs' -Resolve
$HelpFileFolder = Join-Path $DocsFolder '..' -Resolve

Import-Module platyps
Import-Module $ModuleName -Force

$parameters = @{
    # Encoding = 'UTF8BOM'
    AlphabeticParamsOrder = $true
    ExcludeDontShow = $true
    LogPath = $HelpFileFolder
    Module = $ModuleName
    OutputFolder = $DocsFolder
    RefreshModulePage = $true
    UpdateInputOutput = $true
    WithModulePage = $true
}
Update-MarkdownHelpModule @parameters

# New-ExternalHelp –Path $DocsFolder -OutputPath $HelpFileFolder
# Get-HelpPreview -Path "$ModuleName-Help.xml"
