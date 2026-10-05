extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var checks := {}
	for room in ["r01","r02","r03","r04"]:
		game.load_room(room,["chat","lockpick","strong"],24)
		var world = game.world
		var guard = game.guard
		checks[room+"_safe_path_rejected"] = world.find_path(guard.position,game.actors[0].home,guard).is_empty()
		var previous: int = guard.route_index
		var transitions := 0
		var inside := true
		for step in range(3600):
			game.elapsed += 1.0/60.0
			guard.tick(1.0/60.0)
			inside = inside and guard.movement_allowed(guard.position)
			if previous != guard.route_index:
				transitions += 1
				previous = guard.route_index
		checks[room+"_60s_patrol"] = inside and transitions >= 3 and game.captures == 0
		world.open_door()
		guard.position = Vector2(world.guard_zone.position.x+20,world.door.get_center().y)
		game.actors[0].position = Vector2(world.guard_zone.position.x-1,guard.position.y)
		guard.state = "chasing"
		guard.target_id = 0
		guard.tick(0.01)
		checks[room+"_safe_target_released"] = guard.state == "patrol" and game.captures == 0
	var passed: bool = checks.values().all(func(v): return v == true)
	var report := {"passed":passed,"checks":checks,"scope":"Continuous 60Hz guard logic in four unchanged maps, 60 seconds each. No human/phone evidence."}
	FileAccess.open("res://docs/tests/p24-guard.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	root.remove_child(game)
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
