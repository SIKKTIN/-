extends SceneTree
const Assembly=preload("res://docs/art/architecture-v26/assembly.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/architecture/v38/manifest.json"))
	var failed=[]
	for asset in manifest.assets:
		var texture: Texture2D=load(asset.texture)
		if ResourceSaver.save(Assembly.mesh_icon(asset,texture),asset.editor_icon)!=OK:failed.append(asset.id)
	print(JSON.stringify({"icons":4,"failed":failed}))
	quit(0 if failed.is_empty() else 1)
