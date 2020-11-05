<#
    .Synopsis

        Jumper
        PowerShell Console filesystem folders quick links.
        (c)CLosk, 2020
        https://github.com/SynCap/ps-jumper

    .Description

        # PS Jumper

            Module to provide folders' shortcuts in PowerShell console - quick jumps by labels - the aliases of the target.

        ## Features

            - Links stored in JSON and/or INI files;
            - Target of links can contain environment variables;
            - Target of links can contain native PowerShell expressions evaluated at call time;
            - Lists of links can be combined from several files
            - Automatic expansions of links with shortcuts of shell folders
            - History of locations only in addition to yours' CLI history

        ## Sample link list file (INI format):

            ```PowerShell
            appd = =$env:APPDATA # PS expression that returns value of env variable

            pfl = =(Get-ChildItem $PROFILE).DirectoryName # PS expressions that returns
            psh = =(Get-ChildItem $PROFILE).DirectoryName # path string

            pgfl = %ProgramFiles% # Targets can contains common legacy env vars
            temp = %Temp%         # Env vars evaluates at call time

            # Ordinal link can contain plain target path
            jmpr     = D:\\JOB\\PowerShell\\Modules\\Jumper\\

            # Label name can contain some non word symbols
            jmpr/d   = D:\\JOB\\PowerShell\\Modules\\Jumper\\data

            # even blank
            jmpr d   = D:\\JOB\\PowerShell\\Modules\\Jumper\\data

            # target path can be valid path of any type of providers:
            reg/win = HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion
            ```
    .Example

        Jump to home (User Profile) dir:

            PS> ~

    .Example

        Jump by label:

            PS> ~ tmp

    .Example

        Whith additional part of path Jumper returns whole path combined of link
        target and additional part.

        Get link target:

            PS> ~ temp .
            C:\Temp

            PS> ~ appd nuget
            C:\Users\SynCap\AppData\Roaming\nuget

    .Example

        To get path without jump to target use `-ToString` switch or its alias - `-s`.

            PS> ~ temp -s
            C:\Temp

    .Example

        Force change location even additional path given (`-Force` or `-f` switch)

            PS: ~ > ~ appd nuget -f
            PS: C:\Users\SynCap\AppData\Roaming\NuGet >

    .Example

        Use shortcuts in commands and code:

            PS> Get-ChildItem (~ appd .)
            ...
            PS> ls

    .Example

        Jump to system's "Start Menu"

            PS> ~ startMenu
            ~\AppData\Roaming\Microsoft\Windows\Start Menu

#>

############################# Code Analysis Suppress Rules

############################# Data
$Script:Jumper = @{}
$Script:JumperHistory = [System.Collections.Generic.List[string]]::new()
$Script:DataDir = Join-Path $PSScriptRoot 'data'

############################# Helper functions
function local:hr($Ch='-',$Cnt=0-bor[Console]::WindowWidth/2){$Ch*$Cnt}
function local:print([Parameter(ValueFromPipeline)][String[]]$Params){[System.Console]::Write($Params -join '')}
function local:println([Parameter(ValueFromPipeline)][String[]]$Params){[System.Console]::WriteLine($Params -join '')}

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

############################# Module Core

function Read-JumperFile {
    param (
        $Path = ( Join-Path $Script:DataDir 'jumper.json' ),
        [Alias('a')] [Switch] $Append
    )
    if (Test-Path ($tp = Join-Path $Script:DataDir $Path)) {
        $Path = $tp
    } elseif (Test-Path ($tp = Join-Path $Script:DataDir "$Path.json")) {
        $Path = $tp
    } elseif (Test-Path ($tp = Join-Path $Script:DataDir "$Path.ini")) {
        $Path = $tp
    }
    if (!(Test-Path $Path)) {
        Write-Warning "Jumper file `e[33m$Path`e[0m not found"
        return
    }
    if (!$Append) { $Script:Jumper.Clear() }
    $Conflicts = [System.Collections.Generic.List[string]]::new()
    if ('json' -ieq ($Path.Split('.')[-1])) {
        ( Get-Content $Path | ConvertFrom-Json -AsHashtable ).GetEnumerator() | Foreach-Object {
            $Script:Jumper.Add($_.Name, $_.Value)
        }
    } else {
        Get-Content $Path | ConvertFrom-StringData | Foreach-Object { $Script:Jumper += $_}
    }
    Write-Verbose ( "`nLoad `e[93m{1}`e[0m jumps from `e[93m{0}`e[0m." -f $Path,$Script:Jumper.Count )
}

function Get-Jumper($Filter,[Alias('w')][switch]$Wide) {
    $Script:Jumper.GetEnumerator() | Where-Object { $_.Name -imatch $filter } | Sort-Object Name |
        Foreach-Object -Begin {$SNo=1} -Process {
            [PSCustomObject]@{ '###'=$SNo; 'Label'= $_.Name; 'Link'= "`e[32m$($_.Value)`e[0m"; 'Target'= Expand-JumperLink $_.Name }
            $SNo++
        }
}

function Show-JumperHistory ([Alias('r')] [Switch] $Reverse) {
    if ($Script:JumperHistory.Count) { hr } else {  "`e[33mNo Jumper history yet`e[0m"; return;  }
    ($Reverse ? ( $Script:JumperHistory.Reverse() ) : ( $Script:JumperHistory )) |
        Foreach-Object -Begin{$Index=1} -Process {
            println "`e[32m",$Index,". `e[0m",$_
            $index++
        }
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
        $Path = (Join-Path $Script:DataDir 'jumper.json')
    )
    if ($Path -notmatch '\\') {$Path = Join-Path $Script:DataDir $Path }
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
                    $JumpMessage = "`e[0m Go back to `e[33m",$Target,
                        "`e[0m from`nwhere Jumper were `e[33m",$PWD,"`e[0m"
                    $Script:JumperHistory.RemoveAt($Script:JumperHistory.Count -1)
                    break;
                }else{
                    Write-Warning 'Jumper history is empty';
                    return;
                }
            }
        {[bool]$Script:Jumper[$Label]} {
                $JumpMessage = "Label `e[33m",$Label,"`e[0m from Jumper list: `e[33m",$Script:Jumper[$Label],"`e[0m"
                $Target =  $Path ?
                    (Join-Path (Expand-JumperLink $Label) $Path -Resolve) :
                    (Expand-JumperLink $Label)
                break;
            }
        {$Label -in [System.Environment+SpecialFolder].GetEnumNames()} {
                $Target = spf $Label;
                $JumpMessage = "`e[0m Label `e[33m",$Label,"`e[0m presented.",
                    "Found shell folder for it: `e[33m", $Target,"`e[0m" -join ''
                if (Test-Path $Target) {
                    break;
                }
            }
        {Test-Path $Label} {
                $Target = Resolve-Path $Label;
                $JumpMessage = "`e[0m Label `e[33m",$Label," is a real path: `e[93m",$Target,"`e[0m"
                break;
            }
        default {
                $JumpMessage = "`e[0mProbably `e[91mno correct label`e[0m provided.`n",
                    "Target will be set to the current location: `e[33m",$PWD,"`e[0m"
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
        if ($Verbose){println $JumpMessage}
        Set-Location $Target
    } else {
        return $Target
    }
}

function Restart-JumperModule {
    $Verbose = $Args.Verbose
    println "Verbose: ", $Verbose
    println "ARGS Count ", $Args.Count
    hr
    $ModuleName = (Split-Path $PSScriptRoot -LeafBase)
    Write-Verbose "JUMPER: try to UNload $ModuleName ($PSScriptRoot)"
    Remove-Module $ModuleName -Force -Verbose:($Args.Verbose)
    Write-Verbose "JUMPER: try to LOAD $ModuleName ($PSScriptRoot)"
    Import-Module $ModuleName -Force -Verbose:($Args.Verbose)
}

function Invoke-JumperCommand {
    param(
        [Parameter(position=0)] [String] $Command='Help'
    )
    "Command to execute: ", $Command

    switch ($Command) {
        {$_ -in ('a','add')}      {add-jumper $args; break}
        {$_ -in ('rd','read')}    {Read-JumperFile $args;    break}
        {$_ -in ('c','clear')}    {Clear-Jumper;             break}
        {$_ -in ('g','get')}      {Get-Jumper $args;         break}
        {$_ -in ('d','disable')}  {Disable-JumperLink $args; break}
        {$_ -in ('e','expand')}   {Expand-JumperLink $args;  break}
        {$_ -in ('rv','resolve')} {Resolve-JumperList;       break}
        {$_ -in ('s','set')}      {Set-JumperLink $args;     break}
        {$_ -in ('sv','save')}    {Save-JumperList $args;    break}
        {$_ -in ('history')}      {Show-JumperHistory $args; break}
        {$_ -in ('rt','restart')} {Restart-JumperModule;     break}
        {$_ -in ('h','Help')}     {Get-Help ($PSScriptRoot)}
    }
}

############################# Module specific Aliases

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

Set-Alias jr   -Value Invoke-JumperCommand -Description 'Main command centre of module'
Set-Alias g    -Value ~                    -Description 'Clone of ~. By reason could be J but `J` key on keyboard already poor 😥'

############################## Initialisation, Read default Data
Read-JumperFile jumper.json
