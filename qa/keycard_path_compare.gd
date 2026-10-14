extends SceneTree
var game
func _initialize():call_deferred("run")
func meal_path(label: String) -> Dictionary:
	game.actors[0].position=Vector2(1320,2170)
	for actor in game.room_access.dorm_occupants():
		if actor!=game.actors[0]:actor.position=Vector2(2800,3000)
	game.room_access.tick();game.room_visibility.tick(0,true)
	var goal:=Vector2(966,2310)
	var result: Dictionary={"label":label,"start_valid":game.world.can_place_circle(game.actors[0].position,8,game.actors[0],true),"seat_valid":game.world.can_place_circle(goal,8,game.actors[0],true),"path_size":game.world.find_path(game.actors[0].position,goal,game.actors[0],true).size()}
	print("KEYCARD_PATH_COMPARE ",result)
	return result
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	game=load("res://scenes/main.tscn").instantiate();game.room_id="r04";root.add_child(game)
	await process_frame;game.set_process(false);game.fullscreen_ui.set_process(false)
	game.schedule.close();game.phase="playing"
	game.schedule.clock_elapsed=(720-float(game.schedule.config.start_minutes))*game.schedule.day_seconds/1440
	var results: Array=[meal_path("card-integrated")]
	game.room_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/rooms/r04.json"))
	game.world.configure(game.room_config,game.actors)
	game.world.reset_world();game.keycards.reset();game.room_visibility.reset()
	results.append(meal_path("original-map-without-card-decoration"))
	game.world.admission_filter=Callable()
	results.append(meal_path("original-map-without-admission"))
	FileAccess.open("res://docs/tests/keycards-v1/path-compare.json",FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
	game.queue_free();await process_frame;quit()
