Import-Module platyps

Import-Module Jumper -Force

$OutputFolder = Join-Path $PSScriptRoot '..\Docs' -Resolve -Force
$parameters = @{
    Module = 'Jumper'
    OutputFolder = $OutputFolder
    AlphabeticParamsOrder = $true
    WithModulePage = $true
    ExcludeDontShow = $true
    Encoding = 'UTF8BOM'
}
New-MarkdownHelp @parameters

New-MarkdownAboutHelp -OutputFolder $OutputFolder -AboutName 'about_Jumper'

# New-ExternalHelp –Path <folder with MDs> -OutputPath <output help folder>
# Get-HelpPreview -Path "<ModuleName>-Help.xml"

