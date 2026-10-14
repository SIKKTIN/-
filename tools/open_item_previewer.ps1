param([string]$Godot = 'E:/Godot/4.7/Godot_v4.7.2-stable_win64.exe')
$itemProject = Split-Path -Parent $PSScriptRoot
Start-Process -FilePath $Godot -ArgumentList '--path', ('"' + $itemProject + '"'), 'res://scenes/editor/item_previewer.tscn' -WindowStyle Normal
