extends SceneTree
const Assembly=preload("res://docs/art/architecture-v26/assembly.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/architecture/v37/manifest.json"))
	var failed=[]
	for asset in manifest.assets:
		var texture: Texture2D=load(asset.texture)
		var definition: Dictionary=asset.duplicate(true)
		if not definition.has("assembly_patches"):
			definition.assembly_patches=[{"source":asset.region,"destination":[0,0,asset.render_size[0],asset.render_size[1]]}]
		var icon:=Assembly.mesh_icon(definition,texture)
		if ResourceSaver.save(icon,asset.editor_icon)!=OK: failed.append(asset.id)
	print(JSON.stringify({"icons":manifest.assets.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)
