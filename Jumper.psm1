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
$Jumper = @{}
$Global:JumperHistory = [System.Collections.Generic.List[string]]::new()
$JumperDataDir = Join-Path $PSScriptRoot 'data'
$DefaultDataFile = 'jumper.json'
$JumperDataFile = (Join-Path $JumperDataDir $DefaultDataFile)
$RC = "`e[0m" # Reset Console
$JumperSPF = @{}
$itemsToShow=15 # Maximal numer of the itmes (dirs or files) to show after successful jump
$showLandingInfo = $false # show look around info just after jump

<#
    Как пользоваться JpDebug:
    1. В коде добавляем значение, которое хотим отследить, с коментами, как хеш, строку и т.п.
    2. После выполняем:
        $i=0;$JpDebug | % {print "`e[2;4;7m $i `e[0m ";$_ | ft;$i++}
    3. Сбросить значения, просто `$JpDebug.Clear()`
#>
$Global:JpDebug = [Collections.ArrayList]::new()

############################# Helper functions
function Script:hr($Ch = '-', $Cnt = 0 -bor [Console]::WindowWidth / 2) { $Ch * $Cnt }

function Script:print([Parameter(ValueFromPipeline)][String[]]$Params) {
    [System.Console]::Write($Params -join '')
}

function Script:println([Parameter(ValueFromPipeline)][String[]]$Params) {
    [System.Console]::WriteLine($Params -join '')
}

function Get-ShellPredefinedFolder {
    param (
        [parameter(
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            position = 0
        )] [String] $SpecialFolderAlias
    )
    if (!$JumperSPF.Count) {
        if (1 -gt $JumperSPF.Count) {
            [Enum]::GetNames([System.Environment+SpecialFolder]).GetEnumerator().forEach({
                $path = [Environment]::GetFolderPath($_)
                if (0 -lt $path.Length) {
                    $JumperSPF.Add($_, $path)
                }
            })
        }
    }
    if( !$JumperSPF[$SpecialFolderAlias] ) {
        $JumperSPF.GetEnumerator() | Select-Object Name,Value | Sort-Object Name | Where-Object Name -match $SpecialFolderAlias
    } else {
        $JumperSPF[$SpecialFolderAlias]
    }
}
Set-Alias spf -Value Get-ShellPredefinedFolder

<#
    .synopsis
        Expand all Environment variables in the string
#>
filter Expand-ShellFolderAliases  {
    param (
        [parameter(ValueFromPipeline)]
        [string]$PathTemplate
    )
    $RegexPattern = '#\(\s*(\w+?)\s*\)'
    $PathTemplate -replace $RegexPattern, { (Get-ShellPredefinedFolder $_.Groups[1].Value) }
}

############################# Module Core

function Get-JumperDefaultDataFile {
    $JumperDataFile
}

function Set-JumperDefaultDataFile {
    param (
        [String] $Name,
        [Alias('f')][Switch] $ForceRead
    )
    if (Test-Path (Join-Path $JumperDataDir $Name)) {
        $DefaultDataFile = $Name
        $JumperDataFile = (Join-Path $JumperDataDir $DefaultDataFile -Resolve)
        Write-Verbose "Set new default data file to $Name"
        if ($ForceRead) {
            Read-JumperFile $JumperDataFile -Clear
            Write-Verbose "Force read new default data file $Name"
        } else {
            Write-Verbose "Try to set new default data file to $Name. File seems to be not layed there"
        }
    }
}

function Read-JumperFile {
    <#
        .synopsis
            Set or enhance jumper label list from JSON or text (INI) file
        .Description
            JSON file must contain plain object with no child items. Just key-value pairs where key is a label
            and value is an instruction which describes the exact filesystem path.

            INI file can contain comments of PowerShell format. Key-value pairs is need not to be enclosed with quotes.
            Separator of keys and values is a first equal sign.

            If value starts with equal sign the rest of string in INI file and rest of valid JSON value accepted as
            PowerShell instructions that have to retrun String value of valid path.
    #>

    # [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(position = 0)] $Path,
        [Parameter(position = 1)] [Alias('c')] [Switch] $Clear
    )

    # Default value actual if no params trasferred only
    # But if transmitted empty string as value
    # setting defaults skipped, so we need check value and
    # correct'em directly
    if (!$Path) {$Path = $JumperDataFile}

    if (Test-Path ($tp = Join-Path $JumperDataDir $Path)) {
        $Path = $tp
    } elseif (Test-Path ($tp = Join-Path $JumperDataDir "$Path.json")) {
        $Path = $tp
    } elseif (Test-Path ($tp = Join-Path $JumperDataDir "$Path.ini")) {
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

    if ($Clear) { $Jumper.Clear() }

    ( ('json' -ieq ($Path.Split('.')[-1])) ?
        (ReadFromJson($Path)) :
        (ReadFromText($Path)) ) | ForEach-Object {
            foreach ($key in $_.Keys) {
                if ($Jumper.ContainsKey($key)) {
                    println "`e[33m", "Link conflict: label`e[91m $key`e[33m already exists", $RC
                    println "       Exists: `e[36m", $Jumper[$key], $RC
                    println "  Want to add: `e[96m", $_[$key], $RC
                }
                else {
                    $Jumper.($key) = $_.($key)
                }
            }
        }

    Write-Verbose ( "`nLoad `e[93m{1}${RC} jumps from `e[93m{0}${RC}." -f $Path, $Jumper.Count )
}

function Get-Jumper {
    <#
    .synopsis
        Get full or filtered jumper link list
    #>
    param (
        # Filter registerd links by partial case insensetive match
        [String] $Filter,
        # Evaluate and show targets
        [Alias('t')][Switch] $ShowTargets,
        # Filter by Links too
        [Alias('l')][Switch] $ByLink
    )
    $list = $Jumper.GetEnumerator() | Where-Object { $_.Name -imatch $Filter -or ($ByLink -and $_.Value -imatch $Filter) }
    if (0 -eq $list.Count) {
        return ( $Filter ? "Nothing found for `e[33m$Filter`e[0m" : 'Jumper list is empty' )
    }
    $list | Sort-Object Name |
        ForEach-Object -Begin {$SNo = 1} -Process {
            $JumpRecord = [PSCustomObject]@{
                ' #' = $SNo++;
                'Label' = $_.Name;
                'Link' = $_.Value;
            }
            if ($ShowTargets) {
                Add-Member -InputObject $JumpRecord -MemberType NoteProperty -Name 'Target' -Value (Expand-JumperLink $_.Name)
            }
            $JumpRecord
        }
}

function Show-JumperHistory ([Alias('r')] [Switch] $Reverse) {
    <#
    .synopsis
        Just show saved history of jumps
    #>
    if ($JumperHistory.Count) { hr } else { "`e[33mNo Jumper history yet${RC}"; return; }
    ($Reverse ? ( $JumperHistory.Reverse() ) : ( $JumperHistory )) |
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
    $Jumper[$Label] = $Path
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
    $Jumper.Add($Label, $Path)
}

function Disable-JumperLink ([Parameter(mandatory)] $Label) {
    <#
    .synopsis
        Remove record from jumper label list
    #>
    $Jumper.Remove($Label)
}

function Clear-Jumper {
    <#
    .synopsis
        Clear jumper label list
    #>
    $Jumper.Clear()
}

function Save-JumperList {
    <#
    .synopsis
        Save current Jumper Links List to the file
    #>
    Param (
        $Path = $DefaultDataFile
    )
    if(!$Path) {
        $Path = $DefaultDataFile
    }
    if ($Path -notmatch '\\') { $Path = Join-Path $JumperDataDir $Path }
    if ($Path -notmatch '\.json$') { $Path += '.json' }

    Write-Verbose $Path
    ConvertTo-Json $Jumper | Set-Content -Path $Path
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
        if ($Label -in $Jumper.Keys -and '=' -eq $Jumper[$Label][0]) {
            Invoke-Expression $Jumper[$Label].Substring(1)
        }
        else {
            [System.Environment]::ExpandEnvironmentVariables($Jumper[$Label]) | Expand-ShellFolderAliases
        }
    }
}

function Resolve-JumperList {
    <#
    .synopsis
        Expand all links in list
    #>
    foreach ($Label in $Jumper.Keys) {
        $Jumper[$Label] = Expand-JumperLink $Label
    }
}

function Use-Jumper {
    <#
        .synopsis
            Jump to target using label and added path or get the resolved path
        .Description
            Provides the main functionality by making transit or getting the complex long path
            just by short alias. Initially provided 2 aliases for this function: `~` and `g` (abbreviation
            of Get or Go). Also provided default link alias `~` for user's home dir (%UserProfile%, ussually `C:\Users\<UserName>\`),
            so to jump to profile home dir just use `~` command. `~ ~` or `g ~` do the same.

            In addition Jumper have its own history of jumps and one more "magic" label -- `=` (equal sign) which mean
            to jump to location that is last in history of transitions made using `Use-Jumper`. So `g =` is an analogue
            of "Back button" in the browsers.

            Of course you may browse throguh history with magic dot:
                g =-1 # back over 1, i.e. pred last in history list
                g =-2 # back over 2
                g =1 # to first record of history
                g =30 # to record of history with label `30.`
                g =0  # same as `g =`, that is -- just back in time, 0h-h! in history of jumps of course!

            `Use-Jumper` automatically evaluates the pathes of system folders such as `My Documents`, `Application Data`, and so on. To see
            what aliases are valid for those folders use `Get-ShellPredefinedFolder` function.

            If first positional parameter or parameter `-Path` is a string or path of real location then `Use-Jumper` use it as a result of
            evaluations and can jump to it. Such way may replace original `Set-Location` and in addition save this transit in jump history.
            (see Show-JumperHistory help). Path can contain valid environment variables expanded automatically.

            `Use-Jumper` automatically jumps when only one parameter provided and just return evaluated path if provided second positional
            parameter which automatically joins to evaluated label.

            To force transit use `-f` (`-Force`) switch. To force return the expanded path use `-s` (`-AsString`) switch.

        .Example

            Jump by label:

                g lbl
        .Example

            Correspond to full path by label:

                ls (g lbl .)

            Here dot represent a part of path, that will be joined to path evaluated by label. Same result can be recived with:

                ls (g lbl -s)

            Where we force return of string value without jump.

        .Example

            Jump to Programs folder of Windows Start Button Menu:

                g programs

        .Example

            Jump using environment variable:

                g %appdata%
    #>
    param (
        # Label identifies a some place in file system
        [Parameter(position = 0)]
        [ArgumentCompleter({
            # receive information about current state:
            param($CommandName, $ParameterName, $WordToComplete, $CommandAst, $FakeBoundParameters)

            Get-Jumper | Where-Object {$_.Label -like "$WordToComplete*" } |
                Foreach-Object {
                    $LinkType = $_.Label.Substring(0,1) -eq '=' ? 'powershell explression' : 'path string'
                    [System.Management.Automation.CompletionResult]::new($_.Label, $_.Label, 'ParameterValue', "Jumper Link for $LinkType")
                }
            [Enum]::GetNames([System.Environment+SpecialFolder]) | Where-Object {$_ -like '$WordToComplete*'}|
                Foreach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', "Shell Folder Alias")
                }
        })]
        [String]
        $Label = '~',

        # Path can be as an actual filesystem path as a some instruction that evaluates to exact path
        # [ArgumentCompleter({
        #     param($CommandName, $ParameterName, $WordToComplete, $CommandAst, $FakeBoundParameters)
        #     if($FakeBoundParameters.ContainsKey('Label')) {
        #         $LookupPath = Expand-JumperLink $FakeBoundParameters['Label']
        #         [void]$JpDebug.add("Found <Label> param with value: $LookupPath")
        #     }
        # })]
        [Parameter(position = 1)] [String] $Path = '',

        # Insturct the Jumper to not jump just evaluate the target path and return (show) it as string
        [Alias('s')] [Switch]     $AsString = $false,

        # Instruct the Jumper to force actual jump to the place described by evaluated path
        [Alias('f')] [Switch]     $Force = $false
    )

    switch ($Label) {
        '~' {
            $Target = $Env:USERPROFILE;
            break;
        }

        { '=' -eq $Label[0] } {
            if ($JumperHistory.Count) {

                $n = [int]($Label.Substring(1))
                if (-1 -lt $n) {$n--}
                if (0 -gt $n) {$n += $JumperHistory.Count}
                $Target = $JumperHistory[$n]

                $JumpMessage = "${RC} Go back to `e[33m", $Target,
                "${RC} from`nwhere Jumper were `e[33m", $PWD, $RC
                $JumperHistory.RemoveAt($n)
                break;
            }
            else {
                Write-Warning 'Jumper history is empty';
                return;
            }
        }

        { [bool]$Jumper[$Label] } {
            $JumpMessage = "Label `e[33m", $Label, "${RC} from Jumper list: `e[33m", $Jumper[$Label], $RC
            $Target = Expand-JumperLink $Label
            break;
        }

        { Test-Path (Get-ShellPredefinedFolder $Label) } {
            $Target = $TestPath
            $JumpMessage = "${RC} Label `e[33m", $Label, "${RC} is present.",
            "Found shell folder for it: `e[33m", $Target, $RC -join ''
            break;
        }

        { Test-Path ($TestPath = (Expand-JumperLink $Label) ) }{
            $Target = $TestPath
            $JumpMessage = "${RC} Label `e[33m", $Label, " is a real path with environment variables: `e[93m", $Target, $RC
            break;
        }

        { Test-Path $Label } {
            $Target = Resolve-Path $Label;
            $JumpMessage = "${RC} Label `e[33m", $Label, " is a real path: `e[93m", $Target, $RC
            break;
        }

        default {
            $JumpMessage = "${RC}Probably `e[91mno correct label${RC} provided.`n",
            "Target will be set to the current location: `e[33m", $PWD, $RC
        }
    }

    if ($null -ne $Target) {
        if ($Path) {
            $Target = Join-Path $Target $Path -Resolve
        }
    } else {
        $Target = $PWD
    }

    $Force = $Force -or (('' -eq $Path) -and !$Force)
    if ($Force -and !$AsString) {
        if ($JumperHistory[-1] -ne $PWD) {
            $JumperHistory.Add( "$PWD" )
        }

        if ($Verbose) { println $JumpMessage }
        Set-Location $Target

        # information about location where we landed now (where we jump in)
        if ($showLandingInfo) {
            # actual path
            println "`e[33m$PWD`e[0;1m"

            # list some (exact $itemsToShow) dirs of the current location
            $cntDirs = (Get-ChildItem $Target -Force -Directory).Count
            print ((Get-ChildItem $Target -Force -Directory | Select-Object -First $itemsToShow Name | Foreach-Object {" `e[1;4m{0}`e[0m " -f $_.Name}) -join " "," ")
            print "`e[0;2m"
            if ($itemsToShow -lt $cntDirs) {print "... And `e[97;2m$($cntDirs - $itemsToShow)`e[0;2m dirs more`n"}

            # ...and some files
            $cntFiles = (Get-ChildItem $Target -Force -File).Count
            print ((Get-ChildItem $Target -Force -File | Select-Object -First $itemsToShow Name | ForEach-Object { " `e[2;4m{0}`e[0m " -f $_.Name }) -join "  ")
            if ($itemsToShow -lt $cntFiles) {print "`e[0;2m... And `e[33;2m$($cntFiles - $itemsToShow)`e[0;2m files more"}
        }
        print "`e[0m"
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

    $ModuleName = (Split-Path $PSScriptRoot -LeafBase)
    Write-Verbose "JUMPER: try to UNload $ModuleName ($PSScriptRoot)"
    Remove-Module $ModuleName -Force -Verbose:$Verbose
    Write-Verbose "JUMPER: try to LOAD $ModuleName ($PSScriptRoot)"
    Import-Module $ModuleName -Force -Verbose:$Verbose
}

function Get-JumperHelp {
    "To get help about this command itself use `e[32mGet-Help Get-JumperHelp`e[0m or `e[32mhelp j`e[31m😉😁`e[0m"
    "`n"
    'Jumper Commands'
    '==============='
    Get-Help Jumper|Sort-Object Name|Format-Table Name,Synopsis
    'Jumper Aliases'
    '=============='
    Get-Alias | Where-Object Definition -match '-Jumper' | Select-Object Name,Definition,Description
}

function Invoke-JumperCommand {
    <#
        .synopsis
            Main command centre of module

        .Description
            Launch Jumper commands.

            Note: only direct call of Jumper command can be used with additional switches.
            This shortcut can call commands only using positional parameters

            Registered commands:

                go            Jump to target using label and added path or get the resolved path.

                 a | add      Add label to jumper list:
                                 j add <Label> <Target_Dir | SpecialFolder_Alias | Expression>
                 c | clear    Clear jumper label list
            rm | d | disable  Remove record from jumper label list by label: j disable <Label>
                 e | expand   Expand path variables and evaluate expressions in value of jumper link
                 g | get      Get full or filtered jumper link list: j get [match_mask]
                sh | history  Show session history of jumps
                rd | read     Set or enhance jumper label list from JSON or text (INI) file: j read <FullPath | FileName_in_Data_Dir>
                rv | resolve  Expand all links in list. May be need for further save a file with list of all link targets expanded
                rt | restart  Try to reload module itself
                sv | save     Save current Jumper Links List to the file: j save [FullPath | FileName_in_Data_Dir]
                 s | set      Direct updates the Jumper Link: j set <Label> <Target_Dir | SpecialFolder_Alias | Expression>
             ? | l | list     Get list of available jump labels with links
    #>

    param(
        [Parameter(position = 0)]
        [ArgumentCompleter({
            param($CommandName, $ParameterName, $WordToComplete, $CommandAst, $FakeBoundParameters)
            'Add', 'Clear', 'Data', 'Disable', 'Expand', 'Get', 'Help', 'History', 'Read', 'Resolve', 'Restart', 'Save', 'Set', 'List' |
            Where-Object {$_ -like "$WordToComplete*"} |
            Foreach-Object {
                [System.Management.Automation.CompletionResult]::new($_, $_, "ParameterValue", $_)
            }
        })]
        [String]
        $Command = 'Help',
        [Parameter(Position = 1, ValueFromRemainingArguments)]
        [string[]]
        $Params
    )

    switch ($Command) {
        { $_ -in ( 'Add', 'a'           ) } { Add-Jumper @Params;                     break }
        { $_ -in ( 'Clear', 'c'         ) } { Clear-Jumper;                           break }
        { $_ -in ( 'Data', 'df'         ) } { Set-DefaultDataFile @Params -ForceRead; break }
        { $_ -in ( 'Disable', 'd', 'rm' ) } { Disable-JumperLink @Params;             break }
        { $_ -in ( 'Expand', 'e'        ) } { Expand-JumperLink @Params;              break }
        { $_ -in ( 'Get', 'g'           ) } { Get-Jumper @Params;                     break }
        { $_ -in ( 'History', 'sh'      ) } { Show-JumperHistory @Params;             break }
        { $_ -in ( 'Read', 'rd', 'load' ) } { Read-JumperFile @Params;                break }
        { $_ -in ( 'Resolve', 'rv'      ) } { Resolve-JumperList;                     break }
        { $_ -in ( 'Restart', 'rt'      ) } { Restart-JumperModule;                   break }
        { $_ -in ( 'Save', 'sv'         ) } { Save-JumperList @Params;                break }
        { $_ -in ( 'Set', 's'           ) } { Set-JumperLink @Params;                 break }
        { $_ -in ( 'Help', 'h'          ) } { Get-JumperHelp;                         break }
        { $_ -in ( '?', 'l', 'list'     ) } { Get-Jumper @Params;                     break }
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

    Set-Alias j     -Value Invoke-JumperCommand -Description 'Main command centre of module. Try autocomplete to get list available commands'
    Set-Alias g     -Value Use-Jumper           -Description 'Abbr for GO or GET. One more shortcut the clone of ~.'

############################## Initialisation, Read default Data

    if (Test-Path $JumperDataFile) {
        Read-JumperFile $JumperDataFile
    }
