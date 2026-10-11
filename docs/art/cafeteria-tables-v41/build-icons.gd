extends SceneTree
const Assembly=preload("res://docs/art/architecture-v26/assembly.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/props/cafeteria_v41/manifest.json"))
	var failures=[]
	for a in manifest.assets:
		var definition: Dictionary=a.duplicate(true)
		definition.assembly_patches=[{"source":a.region,"destination":[0,0,a.render_size[0],a.render_size[1]]}]
		if ResourceSaver.save(Assembly.mesh_icon(definition,load(a.texture)),a.editor_icon)!=OK:failures.append(a.id)
	print(JSON.stringify({"icons":2,"failed":failures}));quit(0 if failures.is_empty() else 1)
