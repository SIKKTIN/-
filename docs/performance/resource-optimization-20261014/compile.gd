extends SceneTree
var scripts: Array=[]
func _initialize():
	scan("res://scripts")
	var failures: Array=[]
	for path in scripts:
		var script=load(path)
		if script==null or not script.can_instantiate():failures.append(path)
	var result: Dictionary={"scripts":scripts.size(),"failed":failures}
	FileAccess.open("res://docs/performance/resource-optimization-20261014/compile.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("COMPILE "+JSON.stringify(result));quit(0 if failures.is_empty() else 1)
func scan(path: String):
	for file in DirAccess.get_files_at(path):
		if file.ends_with(".gd"):scripts.append(path.path_join(file))
	for dir in DirAccess.get_directories_at(path):scan(path.path_join(dir))
