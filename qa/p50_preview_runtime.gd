extends SceneTree

var game
var checks := {}
var native := false
var width := 1200
var fixture := "user://p50-preview-runtime.json"

func _initialize() -> void:
	call_deferred("run")

func frame() -> void:
	await process_frame
	if native: await RenderingServer.frame_post_draw

func run() -> void:
	native = DisplayServer.get_name() != "headless"
	var args := OS.get_cmdline_user_args()
	width = int(args[0]) if not args.is_empty() else 1200
	root.content_scale_size = Vector2i(width,540 if width == 960 else 720)
	root.size = root.content_scale_size
	var doc = load("res://scripts/editor/map_document.gd").new()
	doc.open_file("res://data/rooms/r04.json")
	doc.data.id = "p50_preview_runtime"
	doc.data.title = "实际编辑草稿"
	doc.data.starts[0] = [360,280]
	doc.data.dormitories[0] = [120,150,360,200]
	doc.data.walls.append([1600,1600,20,80])
	FileAccess.open(fixture,FileAccess.WRITE).store_string(doc.text())
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	checks.cli_preview_mode = game.editor_preview_mode
	checks.custom_room_id = game.room_id == "p50_preview_runtime"
	checks.unsaved_title_loaded = game.room_config.title == "实际编辑草稿"
	checks.changed_start_loaded = game.actors[0].home == Vector2(360,280)
	checks.changed_wall_loaded = game.world.walls.any(func(wall): return wall == Rect2(1600,1600,20,80))
	checks.local_dormitory_overrides_global = game.schedule.dormitory(0) == Rect2(120,150,360,200)
	checks.initial_planner_still_pauses = paused and game.routine_panel.panel.visible
	checks.room_switch_disabled_in_preview = game.room_selector.disabled
	var return_ui = game.get_node("HUD/EditorPreviewReturn")
	checks.return_hidden_under_planner = not return_ui.button.visible
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	game.set_process(false)
	await frame()
	checks.return_visible_after_planning = return_ui.button.visible
	checks.normal_gameplay_can_move = not game.world_input_blocked() and game.world.can_place_circle(game.actors[0].position+Vector2(30,0),17,game.actors[0])
	var key := InputEventKey.new()
	key.keycode = KEY_D
	key.physical_keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	await frame()
	var before: Vector2 = game.actors[0].position
	game._process(0.1)
	checks.real_keyboard_moves_preview_actor = game.actors[0].position.x > before.x
	key.pressed = false
	Input.parse_input_event(key)
	await frame()
	if native:
		await frame()
		root.get_texture().get_image().save_png("res://docs/tests/p50-preview-%d.png" % width)
	var passed: bool = checks.values().all(func(value): return value)
	FileAccess.open("res://docs/tests/p50-preview-%s-%d.json" % ["native" if native else "headless",width],FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"scope":"Actual main.tscn startup with --editor-room isolated JSON; modified geometry/home/dorm association, planner/controls and F10 return input.","native":native},"\t")+"\n")
	print("P50_PREVIEW passed=",passed," count=",checks.size()," failed=",checks.keys().filter(func(k): return not checks[k]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture))
	if not passed:
		quit(1)
		return
	var exit_key := InputEventKey.new()
	exit_key.keycode = KEY_F10
	exit_key.pressed = true
	Input.parse_input_event(exit_key)
	await create_timer(0.5).timeout
	push_error("Preview F10 did not exit the game.")
	quit(1)
