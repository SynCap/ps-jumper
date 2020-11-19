---
Module Name: Jumper
Module Guid: 00000000-0000-0000-0000-000000000000
Download Help Link: {{ Update Download Link }}
Help Version: {{ Please enter version of help manually (X.X.X.X) format }}
Locale: en-US
---

# Jumper Module
## Description
{{ Fill in the Description }}

## Jumper Cmdlets
### [Add-Jumper](Add-Jumper.md)
Add label + link to jumper list

### [Clear-Jumper](Clear-Jumper.md)
Clear jumper label list

### [Disable-JumperLink](Disable-JumperLink.md)
Remove record from jumper label list

### [Expand-JumperLink](Expand-JumperLink.md)
Expand path variables and evaluate expressions in value of jumper link

### [Get-Jumper](Get-Jumper.md)
Get full or filtered jumper link list

### [Get-JumperHelp](Get-JumperHelp.md)
{{ Fill in the Synopsis }}

### [Invoke-JumperCommand](Invoke-JumperCommand.md)
Main command centre of module

.Description.
Allow to launch Jumper commands in unified manner like a single cmdlet or app.

Registered commands:

    go            Jump to target using label and added path or get the resolved path.

    add           Add label to jumper list:
                     jr add \<Label\> \<Target_Dir | SpecialFolder_Alias | Expression\>
    c  | clear    Clear jumper label list
    d  | disable  Remove record from jumper label list by label: jr disable \<Label\>
    e  | expand   Expand path variables and evaluate expressions in value of jumper link
    g  | get      Get full or filtered jumper link list: jr get \[match_mask\]
    rd | history  Show session history of jumps
    rt | read     Set or enhance jumper label list from JSON or text (INI) file: jr read \<FullPath | FileName_in_Data_Dir\>
    rv | resolve  Expand all links in list.
May be need for further save a file with list of all link targets expanded
    s  | restart  Try to reload module itself
    sh | save     Save current Jumper Links List to the file: jr save \<FullPath | FileName_in_Data_Dir\>
    sv | set      Direct updates the Jumper Link: jr set \<Label\> \<Target_Dir | SpecialFolder_Alias | Expression\>

### [Read-JumperFile](Read-JumperFile.md)
Set or enhance jumper label list from JSON or text (INI) file

### [Resolve-JumperList](Resolve-JumperList.md)
Expand all links in list

### [Restart-JumperModule](Restart-JumperModule.md)
{{ Fill in the Synopsis }}

### [Save-JumperList](Save-JumperList.md)
Save current Jumper Links List to the file

### [Set-JumperLink](Set-JumperLink.md)
Direct updates the Jumper Link

### [Show-JumperHistory](Show-JumperHistory.md)
Just show saved history of jumps

### [Use-Jumper](Use-Jumper.md)
Jump to target using label and added path or get the resolved path

