#!/usr/bin/env pwsh
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

        Jump to system's "Start Menu" system folder

            PS> ~ startMenu
            ~\AppData\Roaming\Microsoft\Windows\Start Menu

    .Example

        Jump to existing folders with saving jump history. Path complition works fine.

            PS C:\> ~ $HOME/.vscode/extensions/ms-vscode.powershell-2020.6.0/logs/
            PS ~\.vscode\extensions\ms-vscode.powershell-2020.6.0\logs> _

#>

############################# Code Analysis Suppress Rules

############################# Data
$Script:Jumper = @{}
$Script:JumperHistory = [System.Collections.Generic.List[string]]::new()
$Script:JumperDataDir = Join-Path $PSScriptRoot 'data'
$Script:DefaultDataFile = 'jumper.json'
$RC = "`e[0m" # Reset Console
$Script:JumperSPF = @{}

############################# Helper functions
function Script:hr($Ch = '-', $Cnt = 0 -bor [Console]::WindowWidth / 2) { $Ch * $Cnt }

function Script:print([Parameter(ValueFromPipeline)][String[]]$Params) {
    [System.Console]::Write($Params -join '')
}

function Script:println([Parameter(ValueFromPipeline)][String[]]$Params) {
    [System.Console]::WriteLine($Params -join '')
}

function Get-ShellPredefinedFolder ([parameter(ValueFromPipeline,ValueFromPipelineByPropertyName,position = 0)][string] $SpecialFolderAlias) {
    if ([Enum]::GetNames([System.Environment+SpecialFolder]) -contains $SpecialFolderAlias) {
        [Environment]::GetFolderPath($SpecialFolderAlias)
    } else {
        if (1 -gt $Script:JumperSPF.Count) {
            [Enum]::GetNames([System.Environment+SpecialFolder]).GetEnumerator().forEach({
                $path = [Environment]::GetFolderPath($_)
                if (0 -lt $path.Length) {
                    $Script:JumperSPF.Add($_, $path)
                }
            })
        }
        $Script:JumperSPF.GetEnumerator() | Select-Object Name,Value | Sort-Object Name | Where-Object Name -match $SpecialFolderAlias
    }
}
Set-Alias spf -Value Get-ShellPredefinedFolder

function Script:exps ([parameter(ValueFromPipeline)][string]$s) {
    $re = '#\(\s*(\w+?)\s*\)'
    $s -replace $re, { Get-ShellPredefinedFolder $_.Groups[1].Value }
}

############################# Module Core

function Read-JumperFile {
    <#
    .synopsis
        Set or enhance jumper label list from JSON or text (INI) file
    #>

    # [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(position = 0)] $Path = ( Join-Path $Script:JumperDataDir $Script:DefaultDataFile ),
        [Parameter(position = 1)] [Alias('c')] [Switch] $Clear
    )

    # println "      Direct `$Path : `e[33m" , $Path              , $RC
    # println "     Direct `$Clear : `e[33m" , $Clear             , $RC
    # println "             `$Args : `e[33m" , $Args              , $RC
    # println "`$PSBoundParameters : `e[33m" , $PSBoundParameters , $RC
    # $PSBoundParameters | Format-List *

    if (Test-Path ($tp = Join-Path $Script:JumperDataDir $Path)) {
        $Path = $tp
    } elseif (Test-Path ($tp = Join-Path $Script:JumperDataDir "$Path.json")) {
        $Path = $tp
    } elseif (Test-Path ($tp = Join-Path $Script:JumperDataDir "$Path.ini")) {
        $Path = $tp
    } if (!(Test-Path $Path)) {
        Write-Warning "Jumper file `e[33m$Path${RC} not found"
        return
    }

    function ReadFromJson($JsonPath) { Get-Content $JsonPath | ConvertFrom-Json -AsHashtable };
    function ReadFromText($TextPath) {
        $Out = @{}; Get-Content $TextPath |
            ConvertFrom-StringData | ForEach-Object { $Out += $_ }; $Out
    };

    if ($Clear) { $Script:Jumper.Clear() }

    ( ('json' -ieq ($Path.Split('.')[-1])) ?
        (ReadFromJson($Path)) :
        (ReadFromText($Path)) ) | ForEach-Object {
            foreach ($key in $_.Keys) {
                if ($Script:Jumper.ContainsKey($key)) {
                    println "`e[33m",
                            "Link conflict: label`e[91m $key`e[33m already exists", $RC
                    println "       Exists: `e[36m", $Script:Jumper[$key], $RC
                    println "  Want to add: `e[96m", $_[$key], $RC
                }
                else {
                    $Script:Jumper.($key) = $_.($key)
                }
            }
        }

    Write-Verbose ( "`nLoad `e[93m{1}${RC} jumps from `e[93m{0}${RC}." -f $Path, $Script:Jumper.Count )
}

function Get-Jumper($Filter, [Alias('w')][switch]$Wide) {
    <#
    .synopsis
        Get full or filtered jumper link list
    #>
    $Script:Jumper.GetEnumerator() | Where-Object { $_.Name -imatch $filter } | Sort-Object Name |
        ForEach-Object -Begin {$SNo = 1} -Process {
            [PSCustomObject]@{
                '###' = $SNo++;
                'Label' = $_.Name;
                'Link' = $_.Value;
                'Target' = Expand-JumperLink $_.Name
            }
        }
}

function Show-JumperHistory ([Alias('r')] [Switch] $Reverse) {
    <#
    .synopsis
        Just show saved history of jumps
    #>
    if ($Script:JumperHistory.Count) { hr } else { "`e[33mNo Jumper history yet${RC}"; return; }
    ($Reverse ? ( $Script:JumperHistory.Reverse() ) : ( $Script:JumperHistory )) |
        ForEach-Object -Begin {$Index = 1} -Process {
            println "`e[32m", $Index, ". ", $RC, $_
            $index++
        }
}

function Set-JumperLink {
    <#
    .synopsis
        Direct updates the Jumper Link
    #>
    param(
        [Parameter(mandatory, position = 0)]                   $Label,
        [Parameter(mandatory, position = 1, ValueFromPipeline)] $Path
    )
    $Script:Jumper[$Label] = $Path
}

function Add-Jumper {
    <#
    .synopsis
        Add label + link to jumper list
    .example
        PS> Add-Jumper prj '#(MyDocuments)\\Projects'
        PS> Add-Jumper tls '%ProgramFiles%\\Microsoft\\Build Tools'
    #>
    param(
        [Parameter(mandatory, position = 0)]                   $Label,
        [Parameter(mandatory, position = 1, ValueFromPipeline)] $Path
    )
    $Script:Jumper.Add($Label, $Path)
}

function Disable-JumperLink ([Parameter(mandatory)] $Label) {
    <#
    .synopsis
        Remove record from jumper label list
    #>
    $Script:Jumper.Remove($Label)
}

function Clear-Jumper {
    <#
    .synopsis
        Clear jumper label list
    #>
    $Script:Jumper.Clear()
}

function Save-JumperList {
    <#
    .synopsis
        Save current Jumper Links List to the file
    #>
    Param (
        $Path = (Join-Path $Script:JumperDataDir $Script:DefaultDataFile)
    )
    if ($Path -notmatch '\\') { $Path = Join-Path $Script:JumperDataDir $Path }
    if ($Path -notmatch '\.json$') { $Path += '.json' }

    Write-Verbose $Path
    ConvertTo-Json $Script:Jumper | Set-Content -Path $Path
}

function Expand-JumperLink {
    <#
    .synopsis
        Expand path variables and evaluate expressions in value of jumper link
    #>
    param (
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        $Label
    )
    Process {
        if ($Label -in $Script:Jumper.Keys -and '=' -eq $Script:Jumper[$Label][0]) {
            Invoke-Expression $Script:Jumper[$Label].Substring(1)
        }
        else {
            [System.Environment]::ExpandEnvironmentVariables($Script:Jumper[$Label]) | exps
        }
    }
}

function Resolve-JumperList {
    <#
    .synopsis
        Expand all links in list
    #>
    foreach ($Label in $Script:Jumper.Keys) {
        $Script:Jumper[$Label] = Expand-JumperLink $Label
    }
}

function Use-Jumper {
    <#
    .synopsis
        Jump to target using label and added path or get the resolved path
    #>
    param (
        [Parameter(position = 0)] $Label = '~',
        [Parameter(position = 1)] $Path = '',
        [Alias('s')] [Switch]     $AsString = $false,
        [Alias('f')] [Switch]     $Force = $false
    )

    switch ($Label) {
        '~' {
            $Target = $Env:USERPROFILE;
            break;
        }

        '-' {
            if ($Script:JumperHistory.Count) {
                $Target = $Script:JumperHistory[-1];
                $JumpMessage = "${RC} Go back to `e[33m", $Target,
                "${RC} from`nwhere Jumper were `e[33m", $PWD, $RC
                $Script:JumperHistory.RemoveAt($Script:JumperHistory.Count - 1)
                break;
            }
            else {
                Write-Warning 'Jumper history is empty';
                return;
            }
        }

        { [bool]$Script:Jumper[$Label] } {
            $JumpMessage = "Label `e[33m", $Label, "${RC} from Jumper list: `e[33m", $Script:Jumper[$Label], $RC
            $Target = $Path ?
            (Join-Path (Expand-JumperLink $Label) $Path -Resolve) :
            (Expand-JumperLink $Label)
            break;
        }

        { $Label -in [System.Environment+SpecialFolder].GetEnumNames() } {
            $Target = spf $Label;
            $JumpMessage = "${RC} Label `e[33m", $Label, "${RC} presented.",
            "Found shell folder for it: `e[33m", $Target, $RC -join ''
            if (Test-Path $Target) {
                break;
            }
        }

        { Test-Path $Label } {
            $Target = Resolve-Path $Label;
            $JumpMessage = "${RC} Label `e[33m", $Label, " is a real path: `e[93m", $Target, $RC
            break;
        }

        { $expandedLabel = [System.Environment]::ExpandEnvironmentVariables($Label); Test-Path $expandedLabel}{
            $Target = Resolve-Path $expandedLabel;
            $JumpMessage = "${RC} Label `e[33m", $Label, " is a real path with environment variables: `e[93m", $Target, $RC
            break;
        }

        default {
            $JumpMessage = "${RC}Probably `e[91mno correct label${RC} provided.`n",
            "Target will be set to the current location: `e[33m", $PWD, $RC
            $Target = $PWD
        }
    }

    $Force = $Force -or (('' -eq $Path) -and !$Force)
    if ($Force -and !$AsString) {
        if ('-' -ne $Label) {
            if ($Script:JumperHistory[-1] -ne $PWD) {
                $Script:JumperHistory.Add( "$PWD" )
            }
        }
        if ($Verbose) { println $JumpMessage }
        Set-Location $Target
    }
    else {
        return $Target
    }
}

function Restart-JumperModule {
    <#
        .synopsis
            Try to force reload the Jumper module itself.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    Param(
    )
    $ModuleName = (Split-Path $PSScriptRoot -LeafBase)
    Write-Verbose "JUMPER: try to UNload $ModuleName ($PSScriptRoot)"
    Remove-Module $ModuleName -Force -Verbose:$Verbose
    Write-Verbose "JUMPER: try to LOAD $ModuleName ($PSScriptRoot)"
    Import-Module $ModuleName -Force -Verbose:$Verbose
}

function Get-JumperHelp {
    Get-Help Jumper|Sort-Object Name|Format-Table Name,Synopsis
}

function Invoke-JumperCommand {
    <#
        .synopsis
            Main command centre of module

        .Description
            Launch Jumper commands.

            Registered commands:

                go            Jump to target using label and added path or get the resolved path.

                 a | add      Add label to jumper list:
                                 jr add <Label> <Target_Dir | SpecialFolder_Alias | Expression>
                 c | clear    Clear jumper label list
            rm | d | disable  Remove record from jumper label list by label: jr disable <Label>
                 e | expand   Expand path variables and evaluate expressions in value of jumper link
                 g | get      Get full or filtered jumper link list: jr get [match_mask]
                sh | history  Show session history of jumps
                rd | read     Set or enhance jumper label list from JSON or text (INI) file: jr read <FullPath | FileName_in_Data_Dir>
                rv | resolve  Expand all links in list. May be need for further save a file with list of all link targets expanded
                rt | restart  Try to reload module itself
                sv | save     Save current Jumper Links List to the file: jr save <FullPath | FileName_in_Data_Dir>
                 s | set      Direct updates the Jumper Link: jr set <Label> <Target_Dir | SpecialFolder_Alias | Expression>
    #>

    param(
        [Parameter(position = 0)] [String] $Command = 'Help',
        [Parameter(Position = 1, ValueFromRemainingArguments)] [string[]] $Params
    )

    switch ($Command) {
        { $_ -in ( 'Add', 'a'           ) } { Add-Jumper @Params;         break }
        { $_ -in ( 'Clear', 'c'         ) } { Clear-Jumper;               break }
        { $_ -in ( 'Disable', 'd', 'rm' ) } { Disable-JumperLink @Params; break }
        { $_ -in ( 'Expand', 'e'        ) } { Expand-JumperLink @Params;  break }
        { $_ -in ( 'Get', 'g'           ) } { Get-Jumper @Params;         break }
        { $_ -in ( 'History', 'sh'      ) } { Show-JumperHistory @Params; break }
        { $_ -in ( 'Read', 'rd', 'load' ) } {
            $Clear = '-c' -in $Params -or '-Clear' -in $Params;
            Read-JumperFile $Params[0] -Clear:$Clear;
            break
        }
        { $_ -in ( 'Resolve', 'rv' ) } { Resolve-JumperList;      break }
        { $_ -in ( 'Restart', 'rt' ) } { Restart-JumperModule;    break }
        { $_ -in ( 'Save', 'sv'    ) } { Save-JumperList @Params; break }
        { $_ -in ( 'Set', 's'      ) } { Set-JumperLink @Params;  break }
        { $_ -in ( 'Help', 'h'     ) } { Get-JumperHelp;          break }
    }
}

############################# Module specific Aliases

    Set-Alias JMP   -Value Get-Jumper           -Description "Gets the list of the Jumper links"

    Set-Alias  ~    -Value Use-Jumper           -Description 'Jump to target using label and added path or get the resolved path'
    Set-Alias ajr   -Value Add-Jumper           -Description 'Add label to jumper list'
    Set-Alias cjr   -Value Clear-Jumper         -Description 'Clear jumper label list'
    Set-Alias djr   -Value Disable-JumperLink   -Description 'Remove record from jumper label list by label'
    Set-Alias ejr   -Value Expand-JumperLink    -Description 'Expand path variables and evaluate expressions in value of jumper link'
    Set-Alias gjr   -Value Get-Jumper           -Description 'Get full or filtered jumper link list'
    Set-Alias rdjr  -Value Read-JumperFile      -Description 'Set or enhance jumper label list from JSON or text (INI) file'
    Set-Alias rtjr  -Value Restart-JumperModule -Description 'Trye to reload module itself'
    Set-Alias rvjr  -Value Resolve-JumperList   -Description 'Expand all links in list'
    Set-Alias shjrh -Value Show-JumperHistory   -Description 'Just show saved history of jumps'
    Set-Alias sjr   -Value Set-JumperLink       -Description 'Direct updates the Jumper Link'
    Set-Alias svjr  -Value Save-JumperList      -Description 'Save current Jumper Links List to the file'

    Set-Alias jr    -Value Invoke-JumperCommand -Description 'Main command centre of module'
    Set-Alias g     -Value ~                    -Description 'Abbr for GO or GET, the clone of ~.'

############################## Initialisation, Read default Data

    Read-JumperFile jumper.json
