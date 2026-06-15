Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
psScript = fso.BuildPath(scriptDir, "todo-desktop-widget.ps1")

command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File " & Chr(34) & psScript & Chr(34)
shell.Run command, 0, False
