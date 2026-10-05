extends SceneTree

var game
var checks := {}
var prefix := "p31-native"
var focused_frames := 0
var frames := 0

func _initialize() -> void:
	call_deferred("run")

func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	frames += 1
	focused_frames += int(root.has_focus())

func tap(point: Vector2) -> void:
	root.grab_focus()
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = root.get_final_transform()*point
	touch.pressed = true
	Input.parse_input_event(touch)
	await frame()
	touch = touch.duplicate()
	touch.pressed = false
	Input.parse_input_event(touch)
	await frame()

func shot(suffix: String) -> void:
	await frame()
	root.get_texture().get_image().save_png("res://docs/tests/"+prefix+"-"+suffix+".png")

func at_minute(value: float) -> void:
	game.schedule.clock_elapsed = (value-480)/840*game.schedule.limit_seconds
	game.schedule.tick(false)
	game.presentation.tick(0)
	game._update_ui()

func run() -> void:
	prefix += "-"+OS.get_cmdline_user_args()[0]
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.reset_round(["chat","lockpick","strong"],31)
	root.grab_focus()
	await frame()
	game.developer_settings.preference_path = "user://p31-native-test.cfg"
	game.schedule.set_time_speed(1)
	var settings = game.developer_settings
	await tap(settings.button.get_global_rect().get_center())
	checks.touch_opens_developer = settings.panel.visible and game.world_input_blocked()
	var before: Vector2 = game.actors[0].position
	await tap(Vector2(160,380))
	checks.developer_blocks_map = not game.orders.active.has(0) and game.actors[0].position == before
	await tap(settings.panel.get_node("SpeedPreset3").get_global_rect().get_center())
	checks.touch_changes_speed = game.schedule.time_speed == 4 and settings.speed_input.value == 4
	var minute: float = game.schedule.clock_minutes()
	game._process(0.25)
	checks.settings_time_runs = game.schedule.clock_minutes() > minute and is_equal_approx(game.elapsed,0.25)
	await shot("developer")
	await tap(settings.panel.get_node("SpeedPreset0").get_global_rect().get_center())
	var clock: float = game.schedule.clock_elapsed
	game._process(0.1)
	checks.pause_clock = game.schedule.clock_elapsed == clock and game.elapsed > 0.25
	checks.paused_header_fits = game.schedule.clock_label.get_global_rect().end.x < game.room_selector.position.x
	await tap(settings.panel.position+Vector2(255,298))
	checks.touch_closes_developer = not settings.panel.visible and not settings.blocker.visible
	await tap(game.schedule.stage_button.get_global_rect().get_center())
	checks.touch_opens_updated_schedule = game.schedule.panel.visible
	await shot("schedule")
	await tap(game.schedule.panel.position+Vector2(265,326))
	checks.touch_closes_schedule = not game.schedule.panel.visible
	for minute_value in [480,720,840,1080,1200]:
		at_minute(minute_value)
		checks["header_fits_"+str(minute_value)] = game.schedule.clock_label.get_global_rect().end.x < game.room_selector.position.x and game.schedule.clock_label.get_global_rect().end.y < 70
	checks.dormitory_cards = game.cards[0].text.contains("寝室内") and game.cards[1].text.contains("寝室内") and game.cards[2].text.contains("寝室内")
	checks.curfew_warning_light = game.presentation.lighting.guard_light.texture == game.presentation.lighting.curfew_beam_texture
	game.map_camera.center_on(game.guard.position)
	game.presentation.tick(0)
	game.mini_map._process(0)
	await shot("curfew")
	# Runtime simulation after curfew: actual 360 degree visibility and pursuit.
	game.load_room("r01",["chat","lockpick","strong"],31)
	game.set_process(false)
	game.schedule.set_time_speed(0)
	at_minute(1200)
	game.guard.position = Vector2(870,510)
	game.guard.facing = Vector2.RIGHT
	game.actors[0].position = Vector2(820,510)
	game.guard.tick(0)
	checks.guard_chases_curfew_violator = game.guard.state == "chasing" and game.guard.target_id == 0
	game.actors[0].position = game.actors[0].home
	game.guard.tick(0)
	checks.return_home_releases_pursuit = game.guard.target_id == -1
	game.schedule.set_time_speed(4)
	game.schedule.clock_elapsed = 180-0.1
	game._process(0.2)
	checks.deadline_after_speed_change = game.phase == "failed" and game.schedule.result_panel.visible and not settings.panel.visible
	await shot("deadline")
	await tap(game.schedule.result_panel.position+Vector2(250,205))
	checks.restart_resets_clock_keeps_speed = game.phase == "playing" and game.schedule.clock_minutes() == 480 and game.schedule.time_speed == 4
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://p31-native-test.cfg"))
	var passed: bool = checks.values().all(func(value): return value)
	FileAccess.open("res://docs/tests/"+prefix+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"focused_frames":focused_frames,"frames":frames,"window":[root.size.x,root.size.y],"scope":"Native D3D12 screenshots and simulated multi-frame screen touch; no Android/iOS device claim."},"\t")+"\n")
	print("P31_NATIVE passed=",passed," failed=",checks.keys().filter(func(k): return not checks[k])," focused=",focused_frames,"/",frames)
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
