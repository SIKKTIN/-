extends SceneTree
const Assembly=preload("res://docs/art/architecture-v26/assembly.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/props/prison_v42/manifest.json"))
	var failed=[]
	for a in manifest.assets:
		var def: Dictionary=a.duplicate(true)
		def.assembly_patches=[{"source":a.region,"destination":[0,0,a.render_size[0],a.render_size[1]]}]
		if ResourceSaver.save(Assembly.mesh_icon(def,load(a.texture)),a.editor_icon)!=OK:failed.append(a.id)
	print(JSON.stringify({"icons":manifest.assets.size(),"failed":failed}));quit(0 if failed.is_empty() else 1)
