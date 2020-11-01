# PS Jumper

Module to provide folders' shortcuts in PowerShell console - quick jumps by labels - the aliases of the target.

## Features

- Links stored in JSON and/or INI files;
- Target of links can contain environment variables;
- Target of links can contain native PowerShell expressions evaluated at call time;
- Lists of links can be combined from several files

TODO:
[] Automatic expansions of links with shortcuts of shell folders

## Sample link list file (INI format):

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

## Sample usage

Jump to home (User Profile) dir:

	PS> ~

Jump by label:

	PS> ~ tmp

Whith additional part of path Jumper returns whole path combined of link target
and additional part.
Get link target:

	PS> ~ temp .
	C:\Temp

	PS> ~ appd nuget
	C:\Users\SynCap\AppData\Roaming\nuget

To get path without jump to target use `-ToString` switch or its alias - `-s`.

	PS> ~ temp -s
	C:\Temp

Force change location even additional path given (`-Force` or `-f` switch)

	PS: ~ > ~ appd nuget -f
	PS: C:\Users\SynCap\AppData\Roaming\NuGet >

Use shortcuts in commands and code:

	PS> Get-ChildItem (~ appd .)
	...
	PS> ls