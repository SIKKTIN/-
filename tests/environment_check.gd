extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/props/environment_fixture.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var world = game.world
	var checks := {}
	checks.wall_blocks_move = not world.can_place_circle(Vector2(486,220))
	checks.wall_blocks_sight = not world.line_clear(Vector2(450,220),Vector2(560,220))
	checks.locked_door_blocks_move = not world.can_place_circle(Vector2(497,395))
	checks.locked_door_blocks_sight = not world.line_clear(Vector2(450,395),Vector2(560,395))
	var closed_path = world.find_path(Vector2(440,395),Vector2(570,395))
	checks.closed_partition_has_no_path = closed_path.is_empty()
	world.open_door()
	checks.open_door_allows_move = world.can_place_circle(Vector2(497,395))
	checks.open_door_allows_sight = world.line_clear(Vector2(450,395),Vector2(560,395))
	checks.open_door_allows_path = not world.find_path(Vector2(440,395),Vector2(570,395)).is_empty()
	world.reset_world()
	var pusher = game.actors[2]
	pusher.position = Vector2(447,610)
	var before: Rect2 = world.crate
	world.move_actor(pusher,Vector2(8,0),true,8)
	checks.contact_push_moves_box = world.crate.position.x > before.position.x
	checks.box_updates_navigation = world.nav_dirty
	checks.box_updates_sight = not world.line_clear(Vector2(450,620),Vector2(590,620))
	checks.box_cannot_cross_wall = not world._move_crate(Vector2(0,-100),pusher)
	checks.box_cannot_cross_bound = not world._move_crate(Vector2(1000,0),pusher)
	world.open_door()
	for index in range(3):
		var actor = game.actors[index]
		actor.position = Vector2(1001,400 + index*40)
		world.check_exit(actor)
		checks["escaped_%d"%index] = actor.escaped
		if index == 0:
			checks.single_exit_not_whole_team = not game.actors[1].escaped and not game.actors[2].escaped
	game.reset_round()
	checks.reset_all_state = not world.door_open and world.lock_progress == 0 and world.crate == world.original_crate and game.actors.all(func(actor): return not actor.escaped and actor.position == actor.home)
	var passed := true
	for value in checks.values():
		passed = passed and bool(value)
	checks.passed = passed
	var file := FileAccess.open("res://docs/tests/p11-environment.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(checks,"\t"))
	file.close()
	print("P02_RESULT ",JSON.stringify(checks))
	quit(0 if passed else 1)
