param(
    [string]$GodotExecutable = 'E:\Godot\4.7\Godot_v4.7.2-stable_win64.exe',
    [string]$CharacterId = ''
)
$characterProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
if (-not (Test-Path -LiteralPath $GodotExecutable -PathType Leaf)) {
    throw "Godot executable not found: $GodotExecutable"
}
$characterArguments = @('--path', ('"' + $characterProjectRoot + '"'), '--resolution', '1280x800', 'res://scenes/editor/character_previewer.tscn')
if ($CharacterId) {
    if ($CharacterId -notmatch '^[a-z0-9_]+$') { throw 'Invalid character ID' }
    $characterArguments += @('--', ('--character=' + $CharacterId))
}
Start-Process -FilePath $GodotExecutable -ArgumentList $characterArguments -WindowStyle Normal
