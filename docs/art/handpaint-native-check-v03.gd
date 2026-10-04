extends SceneTree
const ROOT := "E:/Project/Godot/这次怎么逃/"
func _init() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"docs/art/delivery-v03.json"))
	var report: Dictionary = {"version":d.version,"png":[],"regions":[],"frames":[],"passed":true,"scope":"native decode/atlas and anchor checks only; no scene integration"}
	var seen: Dictionary = {}
	for a in d.assets+d.actors:
		var path: String = str(a.texture).replace("res://",ROOT)
		if not seen.has(path):
			var im: Image = Image.load_from_file(path)
			if im == null or im.is_empty():
				report.passed=false
				continue
			seen[path]=ImageTexture.create_from_image(im)
			report.png.append({"path":path,"size":[im.get_width(),im.get_height()],"alpha":im.detect_alpha()})
		var tex: Texture2D = seen[path]
		if a.has("region"):
			var r: Array = a.region
			var rect := Rect2(r[0],r[1],r[2],r[3])
			var valid: bool = Rect2(Vector2.ZERO,tex.get_size()).encloses(rect)
			var atlas := AtlasTexture.new()
			atlas.atlas=tex
			atlas.region=rect
			report.regions.append({"id":a.id,"region":r,"valid":valid,"size":[atlas.get_width(),atlas.get_height()]})
			report.passed=report.passed and valid
		if a.has("frames"):
			for state in ["idle","walk_a","walk_b"]:
				var r: Array = a.frames[state]
				var anchor: Array = a.anchor[state]
				var valid: bool = Rect2(Vector2.ZERO,tex.get_size()).encloses(Rect2(r[0],r[1],r[2],r[3])) and Rect2(0,0,r[2],r[3]).has_point(Vector2(anchor[0],anchor[1]))
				report.frames.append({"actor_id":a.actor_id,"state":state,"valid":valid})
				report.passed=report.passed and valid
	var out: FileAccess = FileAccess.open(ROOT+"docs/art/qa-native-v03.json",FileAccess.WRITE)
	out.store_string(JSON.stringify(report,"\t"))
	out.close()
	print(JSON.stringify({"version":report.version,"png":report.png.size(),"frames":report.frames.size(),"passed":report.passed}))
	quit(0 if report.passed else 1)
