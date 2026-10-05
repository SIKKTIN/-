extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r04",["lockpick","chat","strong"],24)
	var world = game.world
	var actor = game.actors[0]
	var checks := {}
	var goal := Vector2(1020,310)
	checks.initial_route = not world.find_path(actor.position,goal,actor,true).is_empty()
	var builds: int = world.navigation_builds
	for repeat in range(30):
		world.find_path(actor.position,goal,actor,true)
	checks.static_grid_reused = world.navigation_builds == builds
	checks.local_dynamic_overlay = world.last_overlay_cells > 0 and world.last_overlay_cells < 150
	checks.overlay_restored = world.grid.get_point_path(Vector2i(25,48),Vector2i(26,48)).size() > 0
	checks.locked_gate_has_no_route = world.find_path(Vector2(1817,770),Vector2(1950,770),actor,true).is_empty()
	world.open_door()
	checks.open_gate_has_route = not world.find_path(actor.position,Vector2(1950,770),actor,true).is_empty()
	checks.door_invalidates_static_grid = world.navigation_builds == builds+1
	builds = world.navigation_builds
	world._move_crate(Vector2(40,0))
	world.find_path(actor.position,goal,actor,true)
	checks.box_does_not_rebuild_static_grid = world.navigation_builds == builds
	checks.moved_box_still_collides = not world.can_place_circle(world.crate.get_center())
	checks.push_path_ignores_crate = world.find_path(world.crate.get_center(),world.crate.get_center()+Vector2(100,0),game.actors[2],false,true).size() > 0
	checks.push_query_still_avoids_peer = world.find_path(world.crate.get_center(),actor.position,game.actors[2],true,true).is_empty()
	var rect := Rect2(0,0,40,40)
	checks.rounded_corner_remains_open = not world._segment_hits_rect(Vector2(-16,-16),Vector2(-13,-13),rect)
	checks.corner_collision_detected = world._segment_hits_rect(Vector2(-10,-20),Vector2(-10,20),rect)
	checks.long_segment_cannot_tunnel = world._segment_hits_rect(Vector2(-10000,20),Vector2(10000,20),rect)
	actor.position = Vector2(540,970)
	game.actors[1].position = Vector2(540,970)
	checks.overlapping_home_can_separate = world.motion_clear(actor.position,Vector2(540,1040),actor,true)
	checks.cannot_move_further_into_peer = not world.motion_clear(Vector2(530,970),Vector2(540,970),actor,true)
	game.actors[1].position = game.actors[1].home
	var accepted := true
	for repeat in range(60):
		var target := Vector2(540,1100 if repeat%2 == 0 else 1200)
		accepted = accepted and game.command_move(0,target) and game.orders.active[0].goal == target
	checks.sixty_commands_keep_latest = accepted
	var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/tests/p24-navigation-before.json"))
	var after: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/tests/p24-navigation-after.json"))
	checks.benchmark_reachability_unchanged = before.counts == after.counts
	checks.same_machine_speed_improved = after.median_ms < before.median_ms*0.1 and after.p95_ms < 16.7
	var passed: bool = checks.values().all(func(v): return v == true)
	var report := {"passed":passed,"checks":checks,"local_overlay_cells":world.last_overlay_cells,"scope":"Geometry, cached navigation and immediate latest-command semantics; speed compares this machine's saved before/after results, not a universal device budget."}
	FileAccess.open("res://docs/tests/p24-navigation-check.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	root.remove_child(game)
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
