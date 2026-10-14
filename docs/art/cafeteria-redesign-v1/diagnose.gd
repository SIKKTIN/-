extends SceneTree
func _initialize():
	var map:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/rooms/r04.json"))
	print("SHAPE: "+preload("res://scripts/editor/map_document.gd").check_shape(map))
	var doc=preload("res://scripts/editor/map_document.gd").new()
	print("OPEN: ",doc.open_file("res://data/rooms/r04.json")," ",doc.last_error)
	doc.data=map
	print("VALIDATE: ",doc.validate())
	quit()
