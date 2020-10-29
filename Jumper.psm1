$Global:Jumper = @{
    'appd' = $env:APPDATA;
    'temp' = $env:TEMP;

    'psh'  = (Get-Item ($env:PSModulePath -Split ";")[0]).Parent;
    'psm'  = ($env:PSModulePath -Split ";")[0];
    'jmpr' = 'D:\JOB\PowerShell\Modules\Jumper\'; # (Get-ItemProperty $ps | select *).DirectoryName;

    'cli'    = 'C:\CLI';
    'closk'  = 'D:\JOB\CLosk.Work';
    'closkd' = 'D:\JOB\CLosk.Work\Dev._default';
    'ds'     = 'D:\JOB\DS';
    'fnt'    = 'D:\Downloads\Fonts\Styled\Mono';
    'gg'     = 'D:\JOB\LAB\GG';
    'gh'     = 'D:\Alpha\GitHub';
    'its'    = 'D:\JOB\DS\IT-School\Dev.DS-IT-School';
    'pgf'    = 'C:\Program Files';
    'qrn'    = 'D:\JOB\DS\Quran\Dev.Quran';
    'tmp'    = 'D:\TMP';
    'wsa'    = 'D:\JOB\WSA\Dev';
    'evd'    = 'D:\JOB\PowerShell\Modules\EveryDay';
    'evd/tm' = 'D:\JOB\PowerShell\Modules\EveryDay\Themes';
}
# $Global:J = $Global:Jumper;

$DataDir = Join-Path $PSScriptRoot 'data'

function Set-Jumper {
    param (
        $Path = ( Join-Path $DataDir 'jumper.json' ),
        [Switch]
        $EvaluatedJumpers
    )

    if (!(Test-Path $Path)) {
        Write-Warning "Jumper file `e[33m$Path`e[0m not found"
        return
    }

    $Global:Jumper = (Get-Content $Path | ConvertFrom-Json -AsHashtable)

    if ($EvaluatedJumpers) {
        $Global:Jumper.GetEnumerator() | Where-Object { $_.Value[0] -eq '=' } |
            ForEach-Object { $Global:Jumper[$_.Name] = ( Invoke-Expression $_.Value.Substring(1) ) } -ErrorAction SilentlyContinue
    }

    Write-Verbose ( "`nLoad `e[93m{1}`e[0m jumps from `e[93m{0}`e[0m." -f $Path,$Global:Jumper.Count )
}

function Get-Jumper($filter) {
    $Global:Jumper.GetEnumerator() | Where-Object { $_.Name, $_.Value -imatch $filter } | Sort-Object Name
}

Set-Alias Get-JMP -Value Get-Jumper -Description "Gets the list of the Jumper links"


function ~ {
    param (
        [Parameter(position=0)]
        $Label='~',
        [Parameter(position=1)]
        $Path,
        [Alias('e')]
        [Switch]
        $EnforceJump=$false
    )
    # если метки нет -- ничего не делаем
    if ($Global:Jumper.Keys.Contains($Label)) {
        # если есть ещё добавка, пришпилим её к пути
        # например, если нам не надо прыгать, а просто получить
        # путь по метке можно сделать так: PS> ~ label .
        # Вернёт то же самое, что и $Jumper.label
        if ($null -ne $Path) {
            $target = Join-Path $Global:Jumper[$Label] $Path -Resolve
            if ($EnforceJump) {
                Set-Location ($target)
            }
            return ( $target )
        }
        # с одной только меткой, просто прыгаем по ней
        Set-Location ($Global:Jumper[$Label])
    }
}

function Add-Jumper ($Label, $Path) { $Global:Jumper.Add($Label, $Path) }
function Remove-Jumper ($Label) { $Global:Jumper.Remove($Label) }
function Clear-Jumper () {$Global:Jumper.Clear()}

Set-Alias addj -Value Add-Jumper
Set-Alias rmj -Value Remove-Jumper
Set-Alias clrj -Value Clear-Jumper

