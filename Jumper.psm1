<#
    Jumper
    PowerShell Console filesystem folders quick links.
    (c)CLosk, 2020
    https://github.com/SynCap/ps-jumper
#>

$Script:Jumper = @{}
$Script:JumperHistory = @()

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
        ( Get-Content $Path | ConvertFrom-Json -AsHashtable):
        ( Get-Content $Path | Select-String | ConvertFrom-StringData)
    )
    $ErrorActionPreference = 'Continue';
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

function Set-Jumper {
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

function Remove-Jumper ($Label) { $Global:Jumper.Remove($Label) }
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

function Expand-JumperLink  {
    param (
        [Parameter(Mandatory,ValueFromPipeline,Position=0)]
        $Label
    )
    Process {
        if ('=' -eq $Script:Jumper[$Label][0]) {
            ( Invoke-Expression ( $Script:Jumper[$Label].Substring(1) ) -ErrorAction SilentlyContinue )
        } else {
            [System.Environment]::ExpandEnvironmentVariables($Script:Jumper[$Label])
        }
    }
}

function Resolve-JumperLinks {
    foreach ($Label in $Global:Jumper.Keys) {
        $Global:Jumper[$Label] = Expand-JumperLink $Label
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
                    $Script:JumperHistory[-1] = $null;
                    break;
                }else{
                    Write-Warning 'Jumper history is empty';
                    return;
                }
            }
        {$Script:Jumper.Keys.Contains($Label)}
            {
                $Target =  $Path ?
                    (Join-Path (Expand-JumperLink $Label) $Path -Resolve) :
                    (Expand-JumperLink $Label)
            }
    }
    $Force = $Force -or (('' -eq $Path) -and !$Force)
    if ($Force -and !$AsString) {
        $Script:JumperHistory += "$PWD"
        Write-Debug $Script:JumperHistory
        Set-Location $Target
    } else {
        return $Target
    }
}

Set-Alias JMP -Value Get-Jumper -Description "Gets the list of the Jumper links"

Set-Alias  ~   -Value Use-Jumper          -Description 'Jump to target using label and added path or get the resolved path'
Set-Alias ajr  -Value Add-Jumper          -Description 'Add label to jumper list'
Set-Alias rdjr -Value Read-JumperFile     -Description 'Set or enhance jumper label list from JSON or text (INI) file'
Set-Alias cjr  -Value Clear-Jumper        -Description 'Clear jumper label list'
Set-Alias gjr  -Value Get-Jumper          -Description 'Get full or filtered jumper link list'
Set-Alias rjr  -Value Remove-Jumper       -Description 'Remove record from jumper label list by label'
Set-Alias ejr  -Value Expand-JumperLink   -Description 'Expand path variables and evaluate expressions in value of jumper link'
Set-Alias rvjr -Value Resolve-JumperLinks -Description 'Expand all links in list'
Set-Alias sjr  -Value Set-Jumper          -Description 'Direct updates the Jumper Link'
Set-Alias svjr -Value Save-JumperList     -Description 'Save current Jumper Links List to the file'

# Read default Data
rdjr jumper.json