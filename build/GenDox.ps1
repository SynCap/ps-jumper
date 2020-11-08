Import-Module platyps

Import-Module Jumper -Force

$OutputFolder = '.\Docs'
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
