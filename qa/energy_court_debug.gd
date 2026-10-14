extends SceneTree
func _initialize(): call_deferred("run")
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	var game=load("res://scenes/main.tscn").instantiate()
	game.room_id="r04"
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var world=game.world
	var player=game.actors[0]
	world.set_access_closed("energy-entry",false)
	world.set_access_closed("energy-court-entry",false)
	var start=Vector2(2670,3020)
	for p in [start,Vector2(2670,3670),Vector2(3100,3670),Vector2(3100,3800),Vector2(3100,3860)]:
		var solids=[]
		for r in world.body_solids:
			if r.has_point(p): solids.append(str(r))
		print("DEBUG ",p," place=",world.can_place_circle(p,8,player,false,false)," path=",world.find_path(start,p,player,false,true)," bodies=",solids," sealed=",world.pathfinding._sealed_room_separates(start,p))
	print("parts ",game.room_visibility.room_at(start)," ",game.room_visibility.room_at(Vector2(3100,3800)))
	quit()
