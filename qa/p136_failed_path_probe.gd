extends SceneTree
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_FRAME_MODE","0")
	OS.set_environment("ESCAPE_FRAME_SETTINGS_PATH","user://p136-isolated-frame.cfg")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p136-isolated-dev.cfg")
	var game=load("res://scenes/main.tscn").instantiate()
	game.set_script(preload("res://qa/p136_pacing_game.gd"))
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.load_room("r04",["chat","chat","backpack"],136)
	game.schedule.clock_elapsed=(840.0-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.set_time_speed(0)
	game._process(0.001)
	var records: Array=[]
	var officer=game.workshop.overseer
	officer.position=Vector2(1501.775,2316.954)
	for jumping in [true,false]:
		for triple in game.world.pathfinding._navigation_sets():
			for grid in triple:grid.jumping_enabled=jumping
		for avoid in [true,false]:
			for repeat in range(3):
				game.world.begin_ai_paths()
				game.world.pathfinding.frame_records.clear()
				var result=game.world.find_path(officer.position,Vector2(1140.51,1913.58),officer,avoid)
				var trace: Dictionary=game.world.pathfinding.frame_records.back().duplicate(true)
				trace["jumping_enabled"]=jumping
				trace["avoid_actors"]=avoid
				trace["grid_region"]=str(game.world.inspection_grid.region)
				trace["budget_spent_ms"]=game.world.ai_path_spent_usec/1000.0
				records.append(trace)
				game.world.end_ai_paths()
	FileAccess.open("res://docs/dev/p136/failed-path-probe.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	print(JSON.stringify(records))
	game.queue_free()
	await frame()
	await frame()
	quit()
