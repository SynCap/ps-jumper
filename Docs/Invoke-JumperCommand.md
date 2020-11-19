---
external help file: Jumper-help.xml
Module Name: Jumper
online version:
schema: 2.0.0
---

# Invoke-JumperCommand

## SYNOPSIS
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

## SYNTAX

```
Invoke-JumperCommand [[-Command] <String>] [[-Params] <String[]>] [<CommonParameters>]
```

## DESCRIPTION
{{ Fill in the Description }}

## EXAMPLES

### Example 1
```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -Command
{{ Fill Command Description }}

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: Help
Accept pipeline input: False
Accept wildcard characters: False
```

### -Params
{{ Fill Params Description }}

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
