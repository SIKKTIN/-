extends SceneTree
const Assembly=preload("res://docs/art/architecture-v26/assembly.gd")
func _initialize() -> void:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/architecture/v53/manifest.json"))
	var asset: Dictionary=manifest.assets[0]
	var code:=ResourceSaver.save(Assembly.mesh_icon(asset,load(asset.texture)),asset.editor_icon)
	print("Three-way junction thumbnail: ",code)
	quit(code)
