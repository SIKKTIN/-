extends SceneTree

var game
var ui
var editor
var checks := {}
var width := 1200
var native := false
var path: String

func _initialize() -> void:
	call_deferred("run")

func frame() -> void:
	await process_frame
	if native:
		await RenderingServer.frame_post_draw

func touch(id: int, point: Vector2, down: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = root.get_final_transform()*point
	event.pressed = down
	event.canceled = canceled
	Input.parse_input_event(event)
	await frame()

func drag(id: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = id
	event.position = root.get_final_transform()*point
	Input.parse_input_event(event)
	await frame()

func tap(control: Control) -> void:
	await touch(7,control.get_global_rect().get_center(),true)
	await touch(7,control.get_global_rect().get_center(),false)

func move(id: String, delta: Vector2) -> void:
	var start: Vector2 = editor.handles[id].get_global_rect().get_center()
	var before: Vector2 = editor.controls[id].position
	await touch(2,start,true)
	await drag(2,start+delta)
	await touch(2,start+delta,false)
	checks["drag_"+id] = editor.controls[id].position.distance_to(before+delta) < 1

func shot(label: String) -> void:
	if native:
		await frame()
		await frame()
		root.get_texture().get_image().save_png("res://docs/tests/p48-layout-%d-%s.png" % [width,label])

func run() -> void:
	native = DisplayServer.get_name() != "headless"
	var args := OS.get_cmdline_user_args()
	width = int(args[0]) if not args.is_empty() else 1200
	path = "user://p48-layout-qa-%d.cfg" % width
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH",path)
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p48-developer-qa.cfg")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	root.content_scale_size = Vector2i(width,540 if width == 960 else 720)
	root.size = root.content_scale_size
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	game.set_process(false)
	ui = game.fullscreen_ui
	editor = ui.button_layout
	var safe: Rect2 = ui.safe_area()
	checks.cards_directly_below_clock = game.cards[0].position.y == ui.clock.position.y+ui.clock.size.y+12
	checks.cards_align_left = game.cards.all(func(card): return card.position.x == ui.clock.position.x)
	checks.cards_clear_joystick = game.cards[2].get_global_rect().end.y+8 <= game.mobile_controls.pad.position.y
	checks.innocent_story_intro = "无辜人" in game.status_text and "混混看守" in game.status_text
	checks.factory_room_name = game.room_config.title == "黑工厂生活区"
	var fixed_cards: Array = game.cards.map(func(card): return card.position)
	checks.default_right_margin = safe.end.x-ui.action_button.get_global_rect().end.x >= 40
	checks.default_bottom_margin = safe.end.y-ui.action_button.get_global_rect().end.y >= 32
	await shot("default")
	await tap(ui.menu_button)
	checks.menu_pauses = paused and ui.menu.visible
	await tap(ui.menu.get_node("EditButtonLayout"))
	checks.real_menu_opens_editor = editor.editing and paused and editor.overlay.visible and not ui.menu.visible
	checks.editor_blocks_gameplay = game.world_input_blocked() and not game.mobile_controls.is_moving()
	checks.edit_header_above_pause = editor.overlay.z_index > ui.menu_button.z_index and not ui.menu_button.visible
	checks.five_handles_visible = editor.handles.size() == 5 and editor.handles.values().all(func(h): return h.is_visible_in_tree())
	var actor_before: Vector2 = game.actors[0].position
	var money_before: int = game.inventory.wallet
	await move("pad",Vector2(200,0))
	checks.moving_pad_does_not_move_cards = game.cards.map(func(card): return card.position) == fixed_cards
	await move("action",Vector2(-200,0))
	await move("ability",Vector2(-180,0))
	await move("bag",Vector2(0,-12))
	await move("target",Vector2(-100,-180))
	checks.no_actor_movement_while_editing = game.actors[0].position == actor_before and game.mobile_controls.direction == Vector2.ZERO
	checks.no_interaction_while_dragging = game.inventory.wallet == money_before and game.actors[0].action_state == "idle" and game.orders.active.is_empty()
	checks.no_drag_stuck = editor.drag_pointer == -2 and editor.drag_id == ""
	checks.every_position_legal = editor.controls.keys().all(func(id): return editor.valid_position(id,editor.controls[id].position))
	var pad_before: Vector2 = editor.controls.pad.position
	var point: Vector2 = editor.handles.pad.get_global_rect().get_center()
	await touch(3,point,true)
	await drag(3,Vector2(90,300))
	await touch(3,point,false)
	checks.fixed_hud_overlap_rejected = editor.controls.pad.position == pad_before
	# Clamp a drag well beyond the right/bottom; this free corner remains legal.
	point = editor.handles.action.get_global_rect().get_center()
	await touch(3,point,true)
	await drag(3,point+Vector2(2000,2000))
	await touch(3,point,false)
	checks.outside_drag_stays_in_safe_area = editor.bounds().encloses(editor.controls.action.get_global_rect())
	# Restore legal custom action fixture for comparing saved positions.
	editor.controls.action.position = editor.defaults.action-Vector2(200,0)
	editor.draft.action = (editor.controls.action.position-editor.bounds().position)/(editor.bounds().size-editor.controls.action.size)
	editor.sync_handles()
	await shot("editing")
	var saved: Dictionary = editor.draft.duplicate(true)
	await tap(editor.save_button)
	checks.save_returns_to_pause_menu = not editor.editing and paused and ui.menu.visible
	checks.saved_values_equal_draft = editor.positions == saved
	checks.preference_file_written = FileAccess.file_exists(path)
	ui.close_menu()
	await frame()
	checks.save_never_leaves_move_pressed = game.mobile_controls.direction == Vector2.ZERO and game.mobile_controls.pad_pointer == -2
	await touch(0,game.mobile_controls.pad.get_global_rect().get_center()+Vector2(40,0),true)
	checks.saved_custom_pad_receives_gameplay_touch = game.mobile_controls.is_moving()
	await touch(0,game.mobile_controls.pad.get_global_rect().get_center(),false)
	await tap(ui.bag_button)
	checks.saved_custom_bag_receives_touch = ui.bag_open and ui.inventory_paper.visible
	await tap(ui.bag_button)
	checks.saved_custom_bag_closes_once = not ui.bag_open
	await shot("saved")
	var saved_pad: Vector2 = game.mobile_controls.pad.position
	game.reset_round()
	game.routine_panel.close()
	checks.layout_survives_round_reset = game.mobile_controls.pad.position == saved_pad
	editor.positions.clear()
	editor.load_preferences()
	ui.layout()
	checks.config_reload_preserves_layout = editor.positions == saved and game.mobile_controls.pad.position.distance_to(saved_pad) < 1
	var original_size: Vector2i = root.content_scale_size
	root.content_scale_size = Vector2i(960 if width == 1200 else 1200,540 if width == 1200 else 720)
	root.size = root.content_scale_size
	await frame()
	ui.layout()
	checks.resize_keeps_buttons_in_safe_area = editor.controls.values().all(func(control): return ui.safe_area().encloses(control.get_global_rect()))
	checks.resize_preserves_saved_preferences = editor.positions == saved
	root.content_scale_size = original_size
	root.size = original_size
	await frame()
	ui.layout()
	checks.resize_back_restores_custom_layout = game.mobile_controls.pad.position.distance_to(saved_pad) < 1
	# Instantiate a second actual game after freeing the first: real startup load.
	game.presentation.stop_all()
	game.queue_free()
	await frame()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	game.set_process(false)
	ui = game.fullscreen_ui
	editor = ui.button_layout
	checks.new_game_loads_saved_positions = editor.positions == saved and game.mobile_controls.pad.position.distance_to(saved_pad) < 1
	ui.toggle_menu()
	await tap(ui.menu.get_node("EditButtonLayout"))
	await tap(editor.reset_button)
	checks.reset_is_preview_only = editor.draft.is_empty() and editor.positions == saved and game.mobile_controls.pad.position == editor.defaults.pad
	var mouse_start: Vector2 = editor.handles.pad.get_global_rect().get_center()
	var mouse_down := InputEventMouseButton.new()
	mouse_down.position = root.get_final_transform()*mouse_start
	mouse_down.button_index = MOUSE_BUTTON_LEFT
	mouse_down.pressed = true
	Input.parse_input_event(mouse_down)
	await frame()
	var mouse_move := InputEventMouseMotion.new()
	mouse_move.position = root.get_final_transform()*(mouse_start+Vector2(200,0))
	Input.parse_input_event(mouse_move)
	await frame()
	var mouse_up := InputEventMouseButton.new()
	mouse_up.position = mouse_move.position
	mouse_up.button_index = MOUSE_BUTTON_LEFT
	mouse_up.pressed = false
	Input.parse_input_event(mouse_up)
	await frame()
	checks.real_mouse_drag_moves_pad = game.mobile_controls.pad.position.distance_to(editor.defaults.pad+Vector2(200,0)) < 1 and editor.drag_pointer == -2
	await tap(editor.cancel_button)
	checks.cancel_restores_saved_layout = editor.positions == saved and game.mobile_controls.pad.position.distance_to(saved_pad) < 1
	ui.close_menu()
	ui.toggle_menu()
	await tap(ui.menu.get_node("EditButtonLayout"))
	await tap(editor.reset_button)
	await tap(editor.save_button)
	checks.save_default_clears_custom = editor.positions.is_empty() and game.mobile_controls.pad.position == editor.defaults.pad
	ui.close_menu()
	await frame()
	var center: Vector2 = game.mobile_controls.pad.get_global_rect().get_center()
	await touch(0,center+Vector2(40,0),true)
	checks.gameplay_resumes_after_editor = game.mobile_controls.is_moving()
	await touch(0,center,false)
	ui.toggle_menu()
	await tap(ui.menu.get_node("EditButtonLayout"))
	var handle: Control = editor.handles.pad
	await touch(4,handle.get_global_rect().get_center(),true)
	game.get_window().focus_exited.emit()
	checks.focus_exit_releases_drag = editor.drag_pointer == -2 and editor.drag_id == ""
	await touch(4,handle.get_global_rect().get_center(),false)
	var canceled_center: Vector2 = editor.cancel_button.get_global_rect().get_center()
	await touch(5,canceled_center,true)
	await touch(5,canceled_center,false,true)
	checks.canceled_touch_does_not_close_editor = editor.editing
	await tap(editor.cancel_button)
	ui.close_menu()
	await shot("final")
	var passed: bool = checks.values().all(func(value): return value)
	var report := {"passed":passed,"checks":checks,"native":native,"width":width,"scope":"Real Input.parse_input_event touch route; real pause-menu entry, five drags, safety rejection, save/reload/new scene startup/reset/cancel/default, focus and canceled-touch behavior. Isolated user preference path; no phone hardware claim."}
	FileAccess.open("res://docs/tests/p48-layout-%s-%d.json" % ["native" if native else "headless",width],FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("P48_LAYOUT passed=",passed," count=",checks.size()," failed=",checks.keys().filter(func(k): return not checks[k]))
	game.presentation.stop_all()
	game.queue_free()
	await frame()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit(0 if passed else 1)
