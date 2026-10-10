extends SceneTree

func _initialize(): call_deferred("run")

func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_FRAME_SETTINGS_PATH","user://p104-legacy.cfg")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var checks := {}
	for room in ["r01","r02","r03"]:
		game.load_room(room,["backpack","chat","backpack"],72)
		game.schedule.set_time_speed(1)
		game.actors[0].immune_until = INF
		var foot: Vector2 = game.actors[0].position
		for i in range(20): game._process(0.2)
		checks[room+"_player_manual"] = game.actors[0].position==foot and not game.routines.records.has(0) and not game.orders.active.has(0)
		checks[room+"_npc_life_bound"] = game.npc_life.people.size()==game.social.people.size()-1
		checks[room+"_npc_goals_valid"] = game.routines.records.values().all(func(r):return game.world.bounds.has_point(r.goal))
	var failed: Array = checks.keys().filter(func(k):return not checks[k])
	FileAccess.open("res://docs/tests/p104-legacy-life.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks,"failed":failed}))
	quit(0 if failed.is_empty() else 1)
