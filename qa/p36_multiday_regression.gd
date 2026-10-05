extends SceneTree

var game
var checks := {}
var native := false

func _initialize() -> void:
	call_deferred("run")

func set_minute(absolute: float) -> void:
	game.schedule.clock_elapsed = (absolute-480)/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.presentation.tick(0)

func run() -> void:
	native = DisplayServer.get_name() != "headless"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r04",["chat","lockpick","backpack"],35)
	game.schedule.set_escape_days(3)
	game.schedule.set_time_speed(0)
	checks.three_days = game.schedule.limit_seconds == 900 and game.schedule.clock_minutes() == 480
	for actor in game.actors:
		actor.immune_until = 0
	set_minute(1200)
	checks.dorm_free = game.schedule.config.stages[game.schedule.stage_index].id == "dorm_free" and not game.schedule.is_sleep_time() and game.world.dorm_doors.all(func(g): return not g.closed)
	game.actors[0].position = Vector2(540,320)
	checks.shared_dorm_zone = game.schedule.in_dorm_zone(0) and not game.schedule.in_dormitory(0)
	checks.evening_safe = not game.guard.sees(game.actors[0].position)
	checks.evening_move = game.command_move(0,Vector2(540,360))
	game.orders.clear()
	for actor in game.actors:
		actor.position = actor.home
	set_minute(1439.9)
	game.schedule.set_time_speed(1)
	game._process(0.03)
	checks.midnight_wrap = game.schedule.day_number() == 2 and game.schedule.clock_minutes() < 1 and game.schedule.is_sleep_time()
	game.schedule.set_time_speed(0)
	checks.doors_locked = game.world.dorm_doors.all(func(g): return g.closed)
	checks.door_collision = not game.world.can_place_circle(Vector2(320,356),17,game.actors[0],false)
	checks.closed_path = game.world.find_path(game.actors[0].position,Vector2(320,405),game.actors[0]).is_empty()
	checks.sleeping = game.actors.all(func(a): return game.schedule.is_sleeping(a.actor_id)) and game.schedule.can_skip_night()
	# Real navigation, gate collision and guard ticks; never teleport the guard.
	var visited := [false,false,false]
	var opened := [false,false,false]
	var before: int = game.captures
	for frame_index in range(10800):
		game._process(1.0/60)
		for index in range(3):
			visited[index] = visited[index] or game.schedule.dormitory(index).grow(-17).has_point(game.guard.position)
			opened[index] = opened[index] or not game.world.dorm_doors[index].closed
		if visited.all(func(x): return x):
			break
	checks.guard_visits_three_rooms = visited.all(func(x): return x)
	checks.guard_uses_key = opened.all(func(x): return x)
	checks.sleep_not_captured = game.captures == before
	checks.guard_light_boundary = game.guard.allowed_zone() == game.world.bounds
	# Wake by giving a legitimate movement order within the current cell.
	checks.night_controllable = game.command_move(0,game.actors[0].home+Vector2(45,0))
	checks.wake_blocks_skip = not game.schedule.is_sleeping(0) and not game.schedule.can_skip_night()
	var old_clock: float = game.schedule.clock_elapsed
	game.schedule.skip_night()
	checks.skip_rejected = game.schedule.clock_elapsed == old_clock
	game.orders.clear()
	game.actors[0].position = game.actors[0].home
	# Awake near an inspecting guard is detected; sleeping nearby is ignored.
	game.guard.position = Vector2(385,280)
	game.guard.release_target()
	game.guard.tick(0)
	checks.guard_ignores_sleep = game.guard.state != "chasing"
	game.actors[0].position = Vector2(350,280)
	before = game.captures
	game.guard.tick(0.016)
	checks.awake_captured = game.captures > before
	game.orders.clear()
	for actor in game.actors:
		actor.position = actor.home
	game.world.open_door()
	game.inventory.wallet = 77
	var old_elapsed: float = game.elapsed
	var homes: Array = game.actors.map(func(a): return a.position)
	if native:
		game.select_actor(0)
		game.map_camera.locate_selected()
		game.presentation.tick(0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/tests/p36-multiday-midnight.png")
	if native:
		root.grab_focus()
		await process_frame
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.pressed = true
		touch.position = root.get_final_transform()*game.fullscreen_ui.sleep_button.get_global_rect().get_center()
		Input.parse_input_event(touch)
		await process_frame
		await RenderingServer.frame_post_draw
		touch = touch.duplicate()
		touch.pressed = false
		Input.parse_input_event(touch)
		await process_frame
	else:
		game.schedule.skip_night()
	checks.next_morning = game.schedule.day_number() == 2 and game.schedule.clock_minutes() == 480 and not game.schedule.is_sleep_time()
	checks.morning_opens = game.world.dorm_doors.all(func(g): return not g.closed)
	checks.state_retained = game.world.door_open and game.inventory.wallet == 77 and game.elapsed == old_elapsed and game.actors.map(func(a): return a.position) == homes
	checks.guard_returns = game.guard.returning_from_inspection
	checks.morning_safe_dorm = not game.guard.sees(game.actors[0].position)
	for index in range(3600):
		game._process(1.0/60)
		if not game.guard.returning_from_inspection:
			break
	checks.guard_back_in_zone = not game.guard.returning_from_inspection and game.world.guard_zone.grow(-17).has_point(game.guard.position)
	set_minute(1440+1200)
	checks.second_evening = game.schedule.day_number() == 2 and game.schedule.is_curfew()
	set_minute(2*1440)
	checks.second_midnight = game.schedule.day_number() == 3 and game.schedule.is_sleep_time()
	game.schedule.skip_night()
	checks.third_morning = game.schedule.day_number() == 3 and game.schedule.clock_minutes() == 480 and game.phase == "playing"
	game.schedule.clock_elapsed = game.schedule.limit_seconds
	game._process(0)
	checks.deadline = game.phase == "failed" and game.schedule.result_panel.visible and game.schedule.day_number() == 4
	for identifier in ["r01","r02","r03"]:
		game.load_room(identifier,["chat","lockpick","strong"],35)
		set_minute(1440)
		checks[identifier+"_compatible"] = game.schedule.is_sleep_time() and game.phase == "playing"
		game.schedule.skip_night()
		checks[identifier+"_skip"] = game.schedule.clock_minutes() == 480
	game.developer_settings.preference_path = "user://p35-settings-test.cfg"
	game.developer_settings.days_input.value = 4
	checks.developer_days = game.schedule.escape_days == 4 and game.schedule.limit_seconds == game.schedule.day_seconds*4
	game.developer_settings.days_input.value = 3
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://p35-settings-test.cfg"))
	var passed: bool = checks.values().all(func(x): return x)
	var report := {"passed":passed,"checks":checks,"visited":visited,"gates_opened":opened,"native":native,"scope":"Real navigation and guard/gate ticks; isolated positions used for wake/capture and inventory persistence fixtures. No human playability claim."}
	FileAccess.open("res://docs/tests/p36-multiday-"+("native" if native else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("P35 passed=",passed," failed=",checks.keys().filter(func(k): return not checks[k])," visited=",visited)
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
