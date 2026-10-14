extends SceneTree
var scripts: Array = []
func _initialize():
	scan("res://scripts")
	var failed := []
	for path in scripts:
		var resource = load(path)
		if resource == null or not resource.can_instantiate(): failed.append(path)
	FileAccess.open("res://docs/art/nine-point-v1/compile.json",FileAccess.WRITE).store_string(JSON.stringify({"scripts":scripts.size(),"failed":failed},"\t"))
	print("COMPILE ",scripts.size()," failed ",failed)
	quit(0 if failed.is_empty() else 1)
func scan(path: String):
	for file in DirAccess.get_files_at(path):
		if file.ends_with(".gd"): scripts.append(path.path_join(file))
	for directory in DirAccess.get_directories_at(path): scan(path.path_join(directory))
