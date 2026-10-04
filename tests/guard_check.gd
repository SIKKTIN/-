extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var guard = game.guard
	var world = game.world
	var checks := {}
	guard.position = Vector2(620,250)
	guard.facing = Vector2.RIGHT
	checks.in_cone_visible = guard.sees(Vector2(700,250))
	checks.outside_radius_hidden = not guard.sees(Vector2(731,250))
	checks.behind_hidden = not guard.sees(Vector2(580,250))
	checks.outside_cone_hidden = not guard.sees(Vector2(620,330))
	guard.position = Vector2(450,250)
	guard.facing = Vector2.RIGHT
	checks.wall_blocks_guard = not guard.sees(Vector2(550,250))
	guard.position = Vector2(430,395)
	guard.facing = Vector2.RIGHT
	checks.door_blocks_guard = not guard.sees(Vector2(535,395))
	world.open_door()
	checks.open_door_visible = guard.sees(Vector2(535,395))
	world.crate = Rect2(650,500,94,92)
	guard.position = Vector2(630,523)
	checks.crate_blocks_guard = not guard.sees(Vector2(673,480))
	world.crate = world.original_crate
	game.actors[0].position = Vector2(670,250)
	guard.position = Vector2(620,250)
	guard.facing = Vector2.RIGHT
	guard.state = "patrol"
	guard.tick(0.01)
	checks.immediate_chase = guard.state == "chasing" and guard.target_id == 0
	game.actors[0].position = Vector2(180,235)
	guard.tick(1.49)
	checks.chase_persists_before_timeout = guard.state == "chasing"
	guard.tick(0.02)
	checks.patrol_after_timeout = guard.state == "patrol"
	world.open_door()
	world.lock_progress = 1.0
	world._move_crate(Vector2(70,0))
	var box_before: Rect2 = world.crate
	game.actors[1].escaped = true
	game.actors[0].skill_id = "lockpick"
	game.actors[0].position = Vector2(650,250)
	guard.position = Vector2(620,250)
	guard.facing = Vector2.RIGHT
	guard.state = "chasing"
	guard.target_id = 0
	guard._capture_if_touching()
	checks.capture_returns_only_target = game.actors[0].position == game.actors[0].home and game.actors[1].escaped and not game.actors[2].escaped
	checks.capture_keeps_environment = world.door_open and world.crate == box_before and world.lock_progress == 1.0 and game.actors[0].skill_id == "lockpick"
	checks.capture_has_one_second_immunity = game.actors[0].immune_until == game.elapsed+1.0
	guard.position = game.actors[0].position + Vector2(-30,0)
	guard.facing = Vector2.RIGHT
	guard.tick(0.01)
	checks.immunity_prevents_repeat = game.captures == 1 and guard.state == "patrol"
	checks.view_radius_unchanged = guard.VIEW_RADIUS == 110.0
	checks.view_polygon_clipped = guard.view_polygon().size() >= 41
	var passed := true
	for value in checks.values():
		passed = passed and bool(value)
	checks.passed = passed
	var file := FileAccess.open("res://docs/tests/p11-guard.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(checks,"\t"))
	file.close()
	print("P03_RESULT ",JSON.stringify(checks))
	quit(0 if passed else 1)
