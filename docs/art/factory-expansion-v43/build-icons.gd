extends SceneTree
const Assembly = preload("res://docs/art/architecture-v26/assembly.gd")
func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/props/factory_v43/manifest.json"))
	var failed: Array = []
	for a in manifest.assets:
		var definition: Dictionary = a.duplicate(true)
		definition.assembly_patches = [{"source":a.region,"destination":[0,0,a.render_size[0],a.render_size[1]]}]
		var texture: Texture2D = load(a.texture)
		if ResourceSaver.save(Assembly.mesh_icon(definition,texture),a.editor_icon) != OK: failed.append(a.id)
	print(JSON.stringify({"icons":manifest.assets.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)
