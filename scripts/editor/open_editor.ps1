param(
    [string]$GodotExecutable = 'E:\Godot\4.7\Godot_v4.7.2-stable_win64_console.exe'
)
$mapProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
if (-not (Test-Path -LiteralPath $GodotExecutable -PathType Leaf)) {
    throw "Godot executable not found: $GodotExecutable"
}
& $GodotExecutable --path $mapProjectRoot --resolution 1280x800 'res://scenes/editor/map_editor.tscn'
