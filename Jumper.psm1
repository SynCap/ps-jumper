# $Global:Jumper = @{
#     'appd' = $env:APPDATA;
#     'temp' = $env:TEMP;

#     'psh'  = (Get-Item ($env:PSModulePath -Split ";")[0]).Parent;
#     'psm'  = ($env:PSModulePath -Split ";")[0];
#     'jmpr' = 'D:\JOB\PowerShell\Modules\Jumper\'; # (Get-ItemProperty $ps | select *).DirectoryName;

#     'cli'    = 'C:\CLI';
#     'closk'  = 'D:\JOB\CLosk.Work';
#     'closkd' = 'D:\JOB\CLosk.Work\Dev._default';
#     'ds'     = 'D:\JOB\DS';
#     'fnt'    = 'D:\Downloads\Fonts\Styled\Mono';
#     'gg'     = 'D:\JOB\LAB\GG';
#     'gh'     = 'D:\Alpha\GitHub';
#     'its'    = 'D:\JOB\DS\IT-School\Dev.DS-IT-School';
#     'pgf'    = 'C:\Program Files';
#     'qrn'    = 'D:\JOB\DS\Quran\Dev.Quran';
#     'tmp'    = 'D:\TMP';
#     'wsa'    = 'D:\JOB\WSA\Dev';
#     'evd'    = 'D:\JOB\PowerShell\Modules\EveryDay';
#     'evd/tm' = 'D:\JOB\PowerShell\Modules\EveryDay\Themes';
# }

$Global:Jumper = @{}
$Global:J = $Global:Jumper;

$DataDir = Join-Path $PSScriptRoot 'data'

function .hr($Ch='-',$Cnt=[Math]::Floor($Host.Ui.RawUI.WindowSize.Width/2)){println "`e[33m",(($Ch)*$Cnt),"`e[0m"}

function Expand-JumperLink ([Parameter(Mandatory,ValueFromPipeline)]$Label) {
    if ('=' -eq $Global:Jumper[$Label][0]) {
        ( Invoke-Expression ( $Global:Jumper[$Label].Substring(1) ) -ErrorAction SilentlyContinue )
    } else {
        [System.Environment]::ExpandEnvironmentVariables($Global:Jumper[$Label])
    }
}

function Resolve-JumperLinks {
    foreach ($Label in $Global:Jumper.Keys) {
        $Global:Jumper[$Label] = Expand-JumperLink $Label
    }
}

# function Expand-JumperLinks {
#     $Res = @{}
#     foreach ($Item in $Global:Jumper.GetEnumerator()) {
#         println $Item.Name,"`t= `e[91m",$Item.Value,"`e[0m"
#         if ('=' -eq $Item.Value[0]) {
#             $Res[$Item.Name] = ( Invoke-Expression ( $Item.Value.Substring(1) ) -ErrorAction SilentlyContinue )
#         } else {
#             $Res[$Item.Name] = [System.Environment]::ExpandEnvironmentVariables($Item.Value)
#         }
#         println $Item.Name,"`t= `e[93m",$Res[$Item.Name],"`e[0m"
#     }
#     $Global:Jumper = $Res
#     .hr
#     Jumper
# }

function Read-JumperFile {
    param (
        $Path = ( Join-Path $DataDir 'jumper.json' ),
        [Alias('a')] [Switch] $Append
    )
    if (Test-Path (Join-Path $DataDir $Path)) {
        $Path = Join-Path $DataDir $Path
    }
    if (!(Test-Path $Path)) {
        Write-Warning "Jumper file `e[33m$Path`e[0m not found"
        return
    }
    if (!$Append) { $Global:Jumper.Clear() }
    $Global:Jumper += ('json' -ieq ($Path.Split('.')[-1])) ?
            $( Get-Content $Path | ConvertFrom-Json -AsHashtable ) :
            $( Get-Content $Path | ConvertFrom-StringData )
    # if ($Global:Jumper.Count) { Expand-JumperLinks }
    Write-Verbose ( "`nLoad `e[93m{1}`e[0m jumps from `e[93m{0}`e[0m." -f $Path,$Global:Jumper.Count )
    $Global:Jumper
}

function Get-Jumper($filter) {
    $Global:Jumper.GetEnumerator() | Where-Object { $_.Name, $_.Value -imatch $filter } | Sort-Object Name
}

function Use-Jumper {
    param (
        [Parameter(position=0)] $Label='~',
        [Parameter(position=1)] $Path='',
        [Alias('f')] [Switch]   $Force=$false
    )
    if ($Global:Jumper.Keys.Contains($Label)) {
        $Force = $Force -or (('' -eq $Path) -and !$Force)
        $Target = $Path ? (Join-Path $Global:Jumper[$Label] $Path -Resolve) : $Global:Jumper[$Label]
        if ($Force) {
            Set-Location $Target
        } else {
            return $Target
        }
    }
}

function Set-Jumper {
    param(
        [Parameter(mandatory,position=0)]                   $Label,
        [Parameter(mandatory,position=1,ValueFromPipeline)] $Path
    )
    $Global:Jumper.SetValue($Label, $Path)
}

function Add-Jumper  {
    param(
        [Parameter(mandatory,position=0)]                   $Label,
        [Parameter(mandatory,position=1,ValueFromPipeline)] $Path
    )
    $Global:Jumper.Add($Label, $Path)
}

function Remove-Jumper ($Label) { $Global:Jumper.Remove($Label) }
function Clear-Jumper {$Global:Jumper.Clear()}

function Save-JumperList {
    Param (
        $Path = (Join-Path $DataDir 'jumper.json')
    )
    if ($Path -notmatch '\\') {$Path = Join-Path $DataDir $Path }
    if ($Path -notmatch '\.') {$Path += '.json' }

    Write-Verbose $Path
    ConvertTo-Json $Global:Jumper | Set-Content -Path $Path
}

Set-Alias Get-JMP -Value Get-Jumper -Description "Gets the list of the Jumper links"

Set-Alias  ~   -Value Use-Jumper         -Description 'Jump to target using label and added path or get the resolved path'
Set-Alias ajr  -Value Add-Jumper         -Description 'Add label to jumper list'
Set-Alias rdjr -Value Read-JumperFile    -Description 'Set or enhance jumper label list from JSON or text (INI) file'
Set-Alias cjr  -Value Clear-Jumper       -Description 'Clear jumper label list'
Set-Alias gjr  -Value Get-Jumper         -Description 'Get full or filtered jumper link list'
Set-Alias rjr  -Value Remove-Jumper      -Description 'Remove record from jumper label list by label'
Set-Alias ejr  -Value Expand-JumperLink  -Description 'Expand path variables and evaluate expressions in value of jumper link'
Set-Alias rvjr -Value Expand-JumperLinks -Description 'Expand all links in list'
Set-Alias sjr  -Value Set-Jumper         -Description 'Direct updates the Jumper Link'
Set-Alias svjr -Value Save-JumperList    -Description 'Save current Jumper Links List to the file'

# Read default Data
rdjr jumper.json