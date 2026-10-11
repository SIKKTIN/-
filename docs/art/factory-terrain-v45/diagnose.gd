extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var d: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/rooms/r04.json"))
	var w=load("res://scripts/world/prison_world.gd").new();w.configure(d,[])
	for p in [Vector2(2850,1200),Vector2(3750,1600),Vector2(3555,1908.75),Vector2(3338,680),Vector2(3400,680),Vector2(3340,1620),Vector2(3420,1620)]:
		print(p," clear=",w.can_place_circle(p,17,null,false)," path=",w.find_path(Vector2(2850,1200),p,null,false).size())
		for r in w.solid_rects():
			if w._circle_hits_rect(p,17,r):print(" hits ",r)
	for y in range(560,801,40):
		var line: String=str(y)+" "
		for x in range(3260,3461,20):line+="." if w.can_place_circle(Vector2(x,y),17,null,false) else "X"
		print(line)
	for y in range(1500,1761,40):
		var line: String=str(y)+" "
		for x in range(3260,3461,20):line+="." if w.can_place_circle(Vector2(x,y),17,null,false) else "X"
		print(line)
	w.free();quit()
