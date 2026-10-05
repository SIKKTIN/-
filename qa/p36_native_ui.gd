extends SceneTree

var game
var checks := {}
var prefix := "p36-native-"

func _initialize() -> void:
	root.gui_embed_subwindows = true
	call_deferred("run")

func frame(focus: bool = true) -> void:
	if focus:
		root.grab_focus()
	await process_frame
	await RenderingServer.frame_post_draw

func tap(point: Vector2) -> void:
	await frame()
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = root.get_final_transform()*point
	touch.pressed = true
	Input.parse_input_event(touch)
	await frame(false)
	touch = touch.duplicate()
	touch.pressed = false
	Input.parse_input_event(touch)
	await frame(false)

func press(b: Control) -> void:
	await tap(b.get_global_rect().get_center())

func choose_work(b: OptionButton) -> bool:
	await press(b)
	var popup: PopupMenu = b.get_popup()
	if not popup.visible:
		return false
	popup.grab_focus()
	# The actual open popup handles native keyboard events, not an emitted signal.
	for key in [KEY_DOWN,KEY_DOWN,KEY_ENTER]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = true
		Input.parse_input_event(event)
		await frame(false)
		event = event.duplicate()
		event.pressed = false
		Input.parse_input_event(event)
		await frame(false)
	return b.get_item_metadata(b.selected) == "work"

func shot(name_text: String) -> void:
	await frame()
	root.get_texture().get_image().save_png("res://docs/tests/"+prefix+"-"+name_text+".png")

func run() -> void:
	prefix += OS.get_cmdline_user_args()[0]
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.load_room("r04",["chat","lockpick","backpack"],36)
	game.schedule.set_time_speed(0)
	var ui = game.fullscreen_ui
	checks.cards_compact = game.cards.all(func(c): return c.size.x <= 124 and c.size.y == 84)
	game.show_status("三天内让三人逃脱；日常表可安排伙伴工作和活动。",100)
	await frame()
	checks.toast_bottom_center = absf(ui.toast.get_global_rect().get_center().x-game.get_viewport_rect().size.x/2) <= 1 and ui.toast.position.y+ui.toast.size.y == ui.safe_area().end.y
	checks.no_overlap_cards = game.cards.all(func(c): return not c.get_global_rect().intersects(ui.toast.get_global_rect()))
	checks.no_overlap_inventory = not ui.inventory_paper.get_global_rect().intersects(ui.toast.get_global_rect())
	await shot("overview")
	await press(game.cards[2])
	checks.three_slot_select = game.selected_actor_id == 2 and game.inventory_panel.slots.filter(func(b): return b.visible).size() == 3
	var id: String = game.inventory.add_ground("door_key",game.actors[2].position)
	game.inventory.try_pickup(2,id)
	game._update_ui()
	await press(game.inventory_panel.slots[0])
	checks.expanded_inventory_clear = game.inventory_panel.use_button.visible and not ui.toast.get_global_rect().intersects(ui.inventory_paper.get_global_rect())
	await press(ui.routine_button)
	checks.table_opens = game.routine_panel.panel.visible and game.world_input_blocked() and not paused
	var old_clock: float = game.schedule.clock_elapsed
	game.schedule.set_time_speed(1)
	game._process(0.2)
	game.schedule.set_time_speed(0)
	checks.table_time_runs = game.schedule.clock_elapsed > old_clock
	checks.modal_hides_world = game.presentation.interaction.targets.is_empty() and not ui.inventory_paper.visible and not game.mini_map.visible
	checks.panel_safe = ui.safe_area().grow(1).encloses(game.routine_panel.panel.get_global_rect())
	checks.touch_targets = game.routine_panel.selectors.all(func(row): return row.all(func(b): return b.size.y >= 48))
	checks.work_option_touch_0 = await choose_work(game.routine_panel.selectors[0][0])
	checks.work_option_touch_1 = await choose_work(game.routine_panel.selectors[0][1])
	checks.work_option_touch_2 = await choose_work(game.routine_panel.selectors[0][2])
	await shot("routine-table")
	await press(game.routine_panel.apply_button)
	checks.apply_closes = not game.routine_panel.panel.visible
	checks.independent_work = game.routines.plans.all(func(row): return row[0] == "work") and game.orders.active.size() == 3
	for index in range(900):
		game._process(1.0/60)
	checks.arrived_work = game.actors.all(func(a): return game.routines.records.has(a.actor_id) and a.position.distance_to(game.routines.records[a.actor_id].goal) <= 12)
	checks.no_work_capture = game.captures == 0
	game.select_actor(0)
	game.map_camera.locate_selected()
	game.presentation.tick(0)
	await shot("workers")
	await press(game.mini_map.stop_button)
	checks.touch_manual_stop = game.routines.manual.has(0) and not game.routines.is_lawful(0)
	await press(ui.routine_button)
	await press(game.routine_panel.restore_button)
	checks.restore_work = not game.routines.manual.has(0) and game.routines.is_lawful(0)
	# Day rollover while a live table is open discards yesterday's edits.
	await press(ui.routine_button)
	game.orders.clear()
	for actor in game.actors:
		actor.position = actor.home
	game.schedule.clock_elapsed = (1440-480)/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.routines.tick()
	game._update_ui()
	checks.sleep_table_readonly = game.routine_panel.apply_button.disabled and game.routine_panel.selectors.all(func(row): return row.all(func(b): return b.disabled))
	game.schedule.skip_night()
	game._update_ui()
	await frame()
	checks.new_day_header = game.routine_panel.title.text.begins_with("第2天")
	checks.new_day_blank = game.routine_panel.selectors.all(func(row): return row.all(func(b): return b.get_item_metadata(b.selected) == "idle"))
	game.routine_panel.close()
	await press(ui.clock)
	checks.clock_still_schedule = game.schedule.panel.visible
	game.schedule.close()
	await press(ui.menu_button)
	checks.pause_still_works = paused and ui.menu.visible
	ui.close_menu()
	checks.resume_works = not paused
	var passed: bool = checks.values().all(func(x): return x)
	var report := {"passed":passed,"checks":checks,"window":[root.size.x,root.size.y],"canvas":[game.get_viewport_rect().size.x,game.get_viewport_rect().size.y],"scope":"Windows native D3D12; screen-touch controls and actual popup keyboard events, full viewport screenshots. No phone device or human claim."}
	FileAccess.open("res://docs/tests/"+prefix+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("P36_NATIVE passed=",passed," failed=",checks.keys().filter(func(k): return not checks[k]))
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
