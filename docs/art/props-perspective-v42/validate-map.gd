extends SceneTree
func _initialize() -> void:
	var doc=load("res://scripts/editor/map_document.gd").new()
	var ok: bool=doc.open_file("res://data/rooms/r04.json")
	print(JSON.stringify({"opened":ok,"error":doc.last_error,"validation":doc.validate() if ok else {}}))
	quit(0 if ok else 1)
