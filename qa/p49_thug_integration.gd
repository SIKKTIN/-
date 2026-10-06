extends SceneTree

var game
var checks := {}
var width := 1200
var native := false
var texture_path := "res://art/characters/thug_v17/thug_idle_walk8_v17.png"

func _initialize() -> void:
	call_deferred("run")

func frame() -> void:
	await process_frame
	if native:
		await RenderingServer.frame_post_draw

func visual_for(actor):
	return game.presentation.visuals.filter(func(v): return v.actor == actor)[0]

func is_thug(actor) -> bool:
	var visual = visual_for(actor)
	return visual.is_guard and visual.texture != null and visual.definition.texture == texture_path and visual.walk_frames.size() == 8 and visual.walk_fps == 12 and visual.walk_textures.all(func(t): return t != null)

func fresh(room := "r04") -> void:
	game.load_room(room,["chat","lockpick","strong"],49)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	game.presentation.tick(0)
	game._update_ui()

func shot(label: String) -> void:
	if native:
		game._update_ui()
		await frame()
		await frame()
		root.get_texture().get_image().save_png("res://docs/tests/p49-thug-%d-%s.png" % [width,label])

func run() -> void:
	native = DisplayServer.get_name() != "headless"
	var args := OS.get_cmdline_user_args()
	width = int(args[0]) if not args.is_empty() else 1200
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://p49-layout-qa.cfg")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p49-dev-qa.cfg")
	OS.set_environment("ESCAPE_ART_PROFILE","v03")
	root.content_scale_size = Vector2i(width,540 if width == 960 else 720)
	root.size = root.content_scale_size
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	fresh()
	checks.active_config_selects_thug = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/active.json")).guard_appearance == "res://art/characters/thug_v17/manifest.json"
	checks.patrol_uses_thug = is_thug(game.guard)
	checks.two_gate_lookouts = game.gate_watch.guards.size() == 2
	checks.gate_lookouts_use_thug = game.gate_watch.guards.all(func(actor): return is_thug(actor))
	checks.player_art_unchanged = game.actors.all(func(actor): return visual_for(actor).definition.texture.begins_with("res://art/characters/inmate_"))
	var source: Image = load(texture_path).get_image()
	checks.atlas_rgba_loaded = source != null and source.get_width() == 1254 and source.get_height() == 1254
	checks.background_transparent = source.get_pixel(0,0).a == 0 and source.get_pixel(418,418).a == 0
	var v = visual_for(game.guard)
	game.guard.state = "patrolling"
	game.guard.moved_this_frame = false
	v.tick_visual(0)
	checks.stationary_idle_correct = v.frame_name == "idle" and v.walk_frame_index == -1 and v.texture == v.idle_texture
	game.guard.facing = Vector2.RIGHT
	game.guard.moved_this_frame = true
	var seen: Array = []
	var heights: Array[float] = []
	for index in range(8):
		v.walk_clock = 0
		v.tick_visual((index+0.1)/12.0)
		seen.append(v.walk_frame_index)
		heights.append(v.destination.size.y)
	checks.all_eight_frames_render = seen == [0,1,2,3,4,5,6,7]
	checks.walk_height_stable = heights.max()-heights.min() < 2
	checks.walk_has_full_texture = v.texture != null and v.source_region.size.x > 0 and v.source_region.size.y > 0
	game.guard.facing = Vector2.LEFT
	v.tick_visual(0)
	checks.left_facing_flips = v.flip_h
	game.guard.facing = Vector2.RIGHT
	v.tick_visual(0)
	checks.right_facing_unflips = not v.flip_h
	paused = true
	var frozen: float = v.walk_clock
	v.tick_visual(0.5)
	checks.pause_freezes_animation = v.walk_clock == frozen
	paused = false
	game.guard.moved_this_frame = false
	v.tick_visual(0)
	checks.stop_returns_to_idle = v.frame_name == "idle"
	for room in ["r01","r02","r03","r04"]:
		fresh(room)
		checks["thug_in_"+room] = is_thug(game.guard)
	fresh()
	game.presentation.tick(0)
	await shot("hud")
	game.status_until = 0
	await shot("hud-clear")
	game.map_camera.center_on(game.world.door.get_center()-Vector2(250,0))
	await shot("gate")
	var daytime_captures: int = game.captures
	game.actors[0].position = game.guard.position+Vector2(0,50)
	game.guard.tick(0.1)
	checks.normal_day_remains_no_capture = game.captures == daytime_captures and game.guard.state != "chasing"
	fresh()
	game.schedule.clock_elapsed = (1440-480)/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.orders.clear()
	game.actors[0].position = Vector2(900,800)
	game.guard.position = game.schedule.inspection_point(0)
	game.prison_alert.check_rollcall()
	checks.actual_missing_inspection_raises_alarm = game.prison_alert.active and game.prison_alert.missing_ids == [0]
	checks.actual_alarm_spawns_two = game.prison_alert.reinforcements.size() == 2
	checks.reinforcements_use_thug = game.prison_alert.reinforcements.all(func(actor): return is_thug(actor))
	checks.all_five_lookouts_consistent = game.prison_alert.officers().size() == 5 and game.prison_alert.officers().all(func(actor): return is_thug(actor))
	checks.alert_text_is_factory_lookouts = "全厂区警戒" in game.status_text and "混混搜查" in game.status_text
	game.map_camera.center_on(game.prison_alert.reinforcements[0].position)
	game.presentation.tick(0)
	await shot("reinforcements")
	game.reset_round(["chat","lockpick","strong"],49)
	game.routine_panel.close()
	checks.reset_removes_reinforcement_visuals = game.prison_alert.reinforcements.is_empty() and game.presentation.visuals.filter(func(visual): return visual.is_guard).size() == 3
	checks.reset_keeps_new_look = game.gate_watch.guards.all(func(actor): return is_thug(actor)) and is_thug(game.guard)
	var passed: bool = checks.values().all(func(value): return value)
	FileAccess.open("res://docs/tests/p49-thug-%s-%d.json" % ["native" if native else "headless",width],FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"native":native,"width":width,"scope":"Active production config and ActorVisual, actual patrol/gate/reinforcement instances, eight-frame/facing/pause playback, all four maps, actual missing-room inspection and reset. Screenshot camera is centered for inspection; no phone hardware or human animation quality claim."},"\t")+"\n")
	print("P49_THUG passed=",passed," count=",checks.size()," failed=",checks.keys().filter(func(k): return not checks[k]))
	game.presentation.stop_all()
	game.queue_free()
	await frame()
	quit(0 if passed else 1)
