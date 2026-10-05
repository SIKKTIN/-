extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r04",["chat","lockpick","backpack"],34)
	var checks := {}
	game.actors[0].position = Vector2(540,320)
	checks.left_common_zone = game.schedule.in_dorm_zone(0)
	game.actors[0].position = game.actors[0].home
	checks.own_room = game.schedule.in_dorm_zone(0)
	game.actors[0].position = Vector2(2100,1000)
	checks.exit_corridor_not_dorm = not game.schedule.in_dorm_zone(0)
	game.actors[0].position = Vector2(800,700)
	checks.workshop_not_dorm = not game.schedule.in_dorm_zone(0)
	game.actors[0].position = Vector2(50,320)
	checks.out_of_bounds_not_dorm = not game.schedule.in_dorm_zone(0)
	for actor in game.actors:
		actor.position = actor.home
	game.actors[0].position = Vector2(540,320)
	game.schedule.clock_elapsed = 0.5*game.schedule.day_seconds
	game.schedule.tick(false)
	checks.evening_common_zone_free = not game.orders.active.has(0)
	var passed: bool = checks.values().all(func(x): return x)
	FileAccess.open("res://docs/tests/p34-dorm-boundary.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks},"\t")+"\n")
	print("P34_BOUNDARY passed=",passed)
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
