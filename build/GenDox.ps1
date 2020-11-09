$ModuleName = 'Jumper'
$DocsFolder = Join-Path $PSScriptRoot '..\Docs' -Resolve
$HelpFileFolder = Join-Path $DocsFolder '..' -Resolve

Import-Module platyps
Import-Module $ModuleName -Force

$parameters = @{
    Module = $ModuleName
    OutputFolder = $DocsFolder
    AlphabeticParamsOrder = $true
    WithModulePage = $true
    ExcludeDontShow = $true
    # Encoding = 'UTF8BOM'
}
New-MarkdownHelp @parameters
New-MarkdownAboutHelp -OutputFolder $DocsFolder -AboutName "about_$ModuleName"

# New-ExternalHelp –Path $DocsFolder -OutputPath $HelpFileFolder
# Get-HelpPreview -Path "$ModuleName-Help.xml"

