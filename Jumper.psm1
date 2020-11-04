<#
    Jumper
    PowerShell Console filesystem folders quick links.
    (c)CLosk, 2020
    https://github.com/SynCap/ps-jumper
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'Jumper')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '?')]

$Script:Jumper = @{}
$Script:JumperHistory = [System.Collections.Generic.List[string]]::new()

$DataDir = Join-Path $PSScriptRoot 'data'

function .hr($Ch='-',$Cnt=[Math]::Floor($Host.Ui.RawUI.WindowSize.Width/2)){println "`e[33m",(($Ch)*$Cnt),"`e[0m"}

function Read-JumperFile {
    param (
        $Path = ( Join-Path $DataDir 'jumper.json' ),
        [Alias('a')] [Switch] $Append
    )
    if (Test-Path ($tp = Join-Path $DataDir $Path)) {
        $Path = $tp
    } elseif (Test-Path ($tp = Join-Path $DataDir "$Path.json")) {
        $Path = $tp
    } elseif (Test-Path ($tp = Join-Path $DataDir "$Path.ini")) {
        $Path = $tp
    }
    if (!(Test-Path $Path)) {
        Write-Warning "Jumper file `e[33m$Path`e[0m not found"
        return
    }
    if (!$Append) { $Script:Jumper = @{} }
    $ErrorActionPreference = 'SilentlyContinue';
    $Script:Jumper += (
        ('json' -ieq ($Path.Split('.')[-1]))?
        ( Get-Content $Path | ConvertFrom-Json -AsHashtable -ErrorVariable ErrConvert):
        ( Get-Content $Path | Select-String | ConvertFrom-StringData -ErrorVariable ErrConvert)
    )
    $ErrorActionPreference = 'Continue';
    $ErrConvert  | %{println "`e[31m",$_.Exception.Message}
    # if ($Script:Jumper.Count) { Expand-JumperLink }
    Write-Verbose ( "`nLoad `e[93m{1}`e[0m jumps from `e[93m{0}`e[0m." -f $Path,$Script:Jumper.Count )
    $Script:Jumper
}

function Get-Jumper($filter) {
    $Script:Jumper.GetEnumerator() | Where-Object { $_.Name -imatch $filter } |
        %{
            [PSCustomObject]@{ 'Label'= $_.Name; 'Link'= $_.Value; 'Target'= Expand-JumperLink $_.Name }
        } | Sort-Object Label
}

function Show-JumperHistory ([Alias('r')] [Switch] $Reverse) {
    ($Reverse ? ( $Script:JumperHistory.Reverse() ) : ( $Script:JumperHistory )) | Foreach-Object { println "`e[0m",$_ }
}

function Set-JumperLink {
    param(
        [Parameter(mandatory,position=0)]                   $Label,
        [Parameter(mandatory,position=1,ValueFromPipeline)] $Path
    )
    $Script:Jumper[$Label] = $Path
}

function Add-Jumper  {
    param(
        [Parameter(mandatory,position=0)]                   $Label,
        [Parameter(mandatory,position=1,ValueFromPipeline)] $Path
    )
    $Script:Jumper.Add($Label, $Path)
}

function Disable-JumperLink ($Label) { $Script:Jumper.Remove($Label) }
function Clear-Jumper {$Script:Jumper.Clear()}

function Save-JumperList {
    Param (
        $Path = (Join-Path $DataDir 'jumper.json')
    )
    if ($Path -notmatch '\\') {$Path = Join-Path $DataDir $Path }
    if ($Path -notmatch '\.') {$Path += '.json' }

    Write-Verbose $Path
    ConvertTo-Json $Script:Jumper | Set-Content -Path $Path
}

function local:spf ([parameter(ValueFromPipeline,position=0)][string] $ShFName) {
    try {
        [Environment]::GetFolderPath($ShFName)
    } catch {
        $ShFName
    }
}

function local:exps ([parameter(ValueFromPipeline)][string]$s) {
    $re = '#\(\s*(\w+?)\s*\)'
    $s -replace $re, { $_.Groups[1].Value | spf }
}

function Expand-JumperLink  {
    param (
        [Parameter(Mandatory,ValueFromPipeline,Position=0)]
        $Label
    )
    Process {
        if ($Label -in $Script:Jumper.Keys -and '=' -eq $Script:Jumper[$Label][0]) {
            Invoke-Expression $Script:Jumper[$Label].Substring(1)
        } else {
            [System.Environment]::ExpandEnvironmentVariables($Script:Jumper[$Label]) | exps
        }
    }
}

function Resolve-JumperList {
    foreach ($Label in $Script:Jumper.Keys) {
        $Script:Jumper[$Label] = Expand-JumperLink $Label
    }
}

function Use-Jumper {
    param (
        [Parameter(position=0)] $Label='~',
        [Parameter(position=1)] $Path='',
        [Alias('f')] [Switch]   $Force=$false,
        [Alias('s')] [Switch]   $AsString=$false
    )

    switch ($Label) {
        '~' {
                $Target = $Env:USERPROFILE;
                break;
            }
        '-' {
                if($Script:JumperHistory.Count) {
                    $Target = $Script:JumperHistory[-1];
                    $JumpMessage = "`e[33m",$Label,"`e[0m - go back to `e[93m",$Target,
                        "`e[0m from`nwhere Jumper were `e[33m",$PWD,"`e[0m" -join ''
                    $Script:JumperHistory.RemoveAt($Script:JumperHistory.Count -1)
                    break;
                }else{
                    Write-Warning 'Jumper history is empty';
                    return;
                }
            }
        {[bool]$Script:Jumper[$Label]} {
                $JumpMessage = "`e[1;33m",$Label,"`e[0m - label from Jumper list: `e[93m",$Script:Jumper[$Label],"`e[0m" -join ''
                $Target =  $Path ?
                    (Join-Path (Expand-JumperLink $Label) $Path -Resolve) :
                    (Expand-JumperLink $Label)
                break;
            }
        {$Label -in [System.Environment+SpecialFolder].GetEnumNames()} {
                $Target = spf $Label;
                $JumpMessage = "`e[1;33m",$Label,"`e[0m - label presented.",
                    "Found shell folder for it: `e[93m", $Target,"`e[0m" -join ''
                if (Test-Path $Target) {
                    break;
                }
            }
        {Test-Path $Label} {
                $Target = Resolve-Path $Label;
                $JumpMessage = "`e[1;33m",$Label,"`e[0m - label is a real path: `e[93m",$Target,"`e[0m" -join ''
                break;
            }
        default {
                $JumpMessage = "`e[0mProbably `e[91mno correct label`e[0m provided.`n",
                    "Target will be set to the current location: `e[93m",$PWD,"`e[0m" -join ''
                $Target = $PWD
            }
    }
    $Force = $Force -or (('' -eq $Path) -and !$Force)
    if ($Force -and !$AsString) {
        if ('-' -ne $Label){
            if ($Script:JumperHistory[-1] -ne $PWD){
                 $Script:JumperHistory.Add( "$PWD" )
            }
        }
        println $JumpMessage
        Set-Location $Target
    } else {
        return $Target
    }
}

Set-Alias JMP -Value Get-Jumper -Description "Gets the list of the Jumper links"

Set-Alias  ~    -Value Use-Jumper         -Description 'Jump to target using label and added path or get the resolved path'
Set-Alias ajr   -Value Add-Jumper         -Description 'Add label to jumper list'
Set-Alias rdjr  -Value Read-JumperFile    -Description 'Set or enhance jumper label list from JSON or text (INI) file'
Set-Alias cjr   -Value Clear-Jumper       -Description 'Clear jumper label list'
Set-Alias gjr   -Value Get-Jumper         -Description 'Get full or filtered jumper link list'
Set-Alias djr   -Value Disable-JumperLink -Description 'Remove record from jumper label list by label'
Set-Alias ejr   -Value Expand-JumperLink  -Description 'Expand path variables and evaluate expressions in value of jumper link'
Set-Alias rvjr  -Value Resolve-JumperList -Description 'Expand all links in list'
Set-Alias sjr   -Value Set-JumperLink     -Description 'Direct updates the Jumper Link'
Set-Alias svjr  -Value Save-JumperList    -Description 'Save current Jumper Links List to the file'
Set-Alias shjrh -Value Show-JumperHistory -Description 'Just show saved history of jumps'

# Read default Data
Read-JumperFile jumper.json
