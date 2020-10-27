$Global:Jumper = @{
    'appd' = $env:APPDATA;
    'temp' = $env:TEMP;

    'psh'  = (Get-Item ($env:PSModulePath -Split ";")[0]).Parent;
    'psm'  = ($env:PSModulePath -Split ";")[0];
    'jmpr' = $PSScriptRoot; #(Get-ItemProperty $ps | select *).DirectoryName;

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
        Write-Output "Jumper file `e[33m$Path`e[0m not found"
        return
    }

    $Global:Jumper = (Get-Content $Path | ConvertFrom-Json -AsHashtable)

    if ($EvaluatedJumpers) {
        $Global:Jumper.GetEnumerator() | Where-Object { $_.Value[0] -eq '=' } |
            ForEach-Object { $Global:Jumper[$_.Name] = ( Invoke-Expression $_.Value.Substring(1) ) } -ErrorAction SilentlyContinue
    }

    Write-Output ( "`nLoad `e[93m{1}`e[0m jumps from `e[93m{0}`e[0m." -f $Path,$Global:Jumper.Count )
}

function Get-Jumper($filter) {
    $Global:Jumper.GetEnumerator() | Where-Object { $_.Name, $_.Value -imatch $filter } | Sort-Object Name
}

Set-Alias Get-JMP -Value Get-Jumper -Description "Gets the list of the Jumper links"

function ~ ($Label, $Path) {
    # Вызов без метки -- уходим в $env:USERPROFILE
    if ($null -eq $Label) { Set-Location ($env:USERPROFILE); return }


    # метка указана, если есть -- прыгаем по ней,
    # если такой нет -- ничего не делаем
    if ($Global:Jumper.Keys.Contains($Label)) {
        # если есть ещё добавка, пришпилим её к пути
        # например, если нам не надо прыгать, а просто получить
        # путь по метке можно сделать так: PS> ~ label .
        # Вернёт то же самое, что и $Jumper.label
        if ($null -ne $Path) {
            Join-Path $Global:Jumper[$Label] $Path -Resolve
        }
        # с одной только меткой, просто прыгаем по ней
        Set-Location ($Global:Jumper[$Label])
    }
}

function Debug-Jumper {
    $MyInvocation
}