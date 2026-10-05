extends SceneTree

var game
var checks := {}
var prefix := "p41-native-"

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
	# Native focus handoff can lag the first rendered frame after a new window.
	for index in range(6):
		if root.has_focus():
			break
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

func choose_work(b: Button) -> bool:
	await press(b)
	if not game.routine_panel.picker.visible:
		return false
	await press(game.routine_panel.picker_options[1])
	return b.kind == "work" and not game.routine_panel.picker.visible

func escape_key() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	await frame(false)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frame(false)

func set_clock(minute: float) -> void:
	game.schedule.clock_elapsed = (minute-480)/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.routines.tick()
	game._update_ui()

func shot(name_text: String) -> void:
	# Let deferred Control redraw/layout reach the D3D12 framebuffer too.
	await frame()
	await frame()
	root.get_texture().get_image().save_png("res://docs/tests/"+prefix+"-"+name_text+".png")

func run() -> void:
	prefix += OS.get_cmdline_user_args()[0]
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.load_room("r04",["chat","lockpick","backpack"],38)
	checks.initial_auto_open = game.routine_panel.panel.visible and paused and game.schedule.clock_minutes() == 480
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	for index in range(3):
		await frame()
	var ui = game.fullscreen_ui
	checks.cards_compact = game.cards.all(func(c): return c.size.x <= 124 and c.size.y == 104)
	game.show_status("三天内让三人逃脱；日常表可安排伙伴工作和活动。",100)
	await frame()
	checks.toast_bottom_center = absf(ui.toast.get_global_rect().get_center().x-game.get_viewport_rect().size.x/2) <= 1 and ui.toast.position.y+ui.toast.size.y == ui.safe_area().end.y
	checks.no_overlap_cards = game.cards.all(func(c): return not c.get_global_rect().intersects(ui.toast.get_global_rect()))
	checks.no_overlap_inventory = not ui.inventory_paper.get_global_rect().intersects(ui.toast.get_global_rect())
	await shot("overview")
	await press(game.cards[2])
	checks.three_slot_select = game.selected_actor_id == 2 and game.inventory_panel.slots.filter(func(b): return b.visible).size() == 3
	var ground_id: String = game.inventory.add_ground("door_key",game.actors[2].position)
	game.inventory.try_pickup(2,ground_id)
	game._update_ui()
	await press(game.inventory_panel.slots[0])
	checks.expanded_inventory_clear = game.inventory_panel.use_button.visible and not ui.toast.get_global_rect().intersects(ui.inventory_paper.get_global_rect())
	await press(ui.routine_button)
	checks.table_opens = game.routine_panel.panel.visible and game.world_input_blocked() and paused
	var old_clock: float = game.schedule.clock_elapsed
	game.schedule.set_time_speed(1)
	game._process(0.2)
	game.schedule.set_time_speed(0)
	checks.table_time_paused = game.schedule.clock_elapsed == old_clock
	checks.paused_copy = "已暂停" in game.routine_panel.live_label.text
	checks.pause_entry_below = ui.menu_button.z_index < game.routine_panel.blocker.z_index and not ui.menu_button.visible
	await tap(ui.menu_button.get_global_rect().get_center())
	checks.covered_pause_no_click = game.routine_panel.panel.visible and not ui.menu.visible and paused
	checks.modal_hides_world = game.presentation.interaction.targets.is_empty() and not ui.inventory_paper.visible and not game.mini_map.visible
	checks.panel_safe = ui.safe_area().grow(1).encloses(game.routine_panel.panel.get_global_rect())
	checks.touch_targets = game.routine_panel.selectors.all(func(row): return row.all(func(b): return b.size.y >= 48))
	var rp = game.routine_panel
	checks.horizontal_actor_rows = range(5).all(func(i): return is_equal_approx(rp.selectors[i][0].position.y,rp.selectors[0][0].position.y)) and rp.selectors[0][0].position.y < rp.selectors[0][1].position.y
	checks.actual_portraits = rp.portraits[2].resource_path == "res://art/ui/fullscreen/portrait_3.tres" and rp.portraits.all(func(p): return p is AtlasTexture)
	checks.buttons_56 = [rp.apply_button,rp.restore_button,rp.close_button].all(func(b): return b.size.y >= 56)
	checks.header_no_overlap = not rp.clock_label.get_global_rect().intersects(rp.live_label.get_global_rect()) and not rp.title.get_global_rect().intersects(rp.day_label.get_global_rect())
	checks.no_dropdowns = rp.panel.find_children("*","OptionButton",true,false).is_empty()
	await press(rp.selectors[0][0])
	checks.picker_safe = rp.panel.get_global_rect().encloses(rp.picker.get_global_rect()) and rp.picker.position.y+rp.picker.size.y < rp.apply_button.position.y
	checks.menu_touch_targets = rp.picker_options.all(func(b): return b.size.y >= 48)
	await shot("activity-picker")
	checks.pick_selects_identity = game.selected_actor_id == 0 and not game.routines.manual.has(0)
	await press(rp.picker_options[2])
	checks.draft_not_executed = rp.draft[0][0] == "rest" and game.routines.plans[0][0] == "idle" and game.orders.active.is_empty()
	await press(rp.close_button)
	await press(ui.routine_button)
	checks.close_discards_draft = rp.draft[0][0] == "idle"
	await press(rp.selectors[0][0])
	await tap(rp.panel.position+Vector2(20,rp.panel.size.y-100))
	checks.outside_dismiss_no_world_order = not rp.picker.visible and rp.panel.visible and game.orders.active.is_empty()
	await press(rp.selectors[0][0])
	await escape_key()
	checks.escape_closes_only_picker = not rp.picker.visible and rp.panel.visible
	await press(rp.selectors[1][0])
	checks.meal_no_work = rp.picker_options[1].disabled
	await press(rp.picker_options[1])
	checks.disabled_choice_no_change = rp.draft[0][1] == "idle" and rp.picker.visible
	rp.close_picker()
	set_clock(548)
	checks.work_option_touch_0 = await choose_work(game.routine_panel.selectors[0][0])
	checks.work_option_touch_1 = await choose_work(game.routine_panel.selectors[0][1])
	checks.work_option_touch_2 = await choose_work(game.routine_panel.selectors[0][2])
	# Future slots use actual touch selections, then submit all three rows.
	for id in range(3):
		for index in range(1,5):
			await press(rp.selectors[index][id])
			var option: int = 2 if index == 1 else 1 if index == 2 and id != 1 else 0 if index == 2 else 3
			await press(rp.picker_options[option])
	await press(rp.identities[2])
	checks.restore_identity_matches = game.selected_actor_id == 2
	await shot("routine-table")
	await press(game.routine_panel.apply_button)
	checks.apply_unpauses = not paused
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
	# The live clock invalidates an expired draft and dismisses its open picker.
	await press(ui.routine_button)
	await press(rp.selectors[0][0])
	await press(rp.picker_options[2])
	await press(rp.selectors[0][0])
	set_clock(720)
	checks.expired_menu_dismissed = not rp.picker.visible and rp.selectors[0].all(func(b): return b.disabled)
	checks.expired_draft_restored = rp.draft[0][0] == game.routines.plans[0][0] and rp.selectors[1].all(func(b): return not b.disabled)
	game.actors[1].escaped = true
	game._update_ui()
	checks.escaped_row_disabled = rp.selectors.all(func(row): return row[1].disabled) and rp.identities[1].disabled
	game.actors[1].escaped = false
	rp.close()
	# Day rollover while a live table is open discards yesterday's edits.
	await press(ui.routine_button)
	game.orders.clear()
	for actor in game.actors:
		actor.position = actor.home
	game.schedule.clock_elapsed = (1440-480)/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.routines.tick()
	game._update_ui()
	checks.midnight_note = "午夜只读" in rp.note.text
	checks.sleep_table_readonly = game.routine_panel.apply_button.disabled and game.routine_panel.selectors.all(func(row): return row.all(func(b): return b.disabled))
	game.schedule.skip_night()
	game._update_ui()
	await frame()
	checks.new_day_header = game.routine_panel.day_label.text == "第2天"
	checks.new_day_blank = game.routine_panel.selectors.all(func(row): return row.all(func(b): return b.kind == "idle"))
	# Work remains unavailable on maps without actual jobs.
	rp.close()
	game.load_room("r01",["chat","lockpick","backpack"],38)
	checks.map_change_auto_open = rp.panel.visible and paused
	rp.close()
	game.schedule.set_time_speed(0)
	await press(ui.routine_button)
	await press(rp.selectors[0][0])
	checks.old_map_no_fake_work = rp.picker_options[1].disabled and "没有工作岗位" in rp.note.text
	rp.close()
	game.routine_panel.close()
	await press(ui.clock)
	checks.clock_still_schedule = game.schedule.panel.visible
	game.schedule.close()
	await press(ui.menu_button)
	checks.pause_still_works = paused and ui.menu.visible
	ui.close_menu()
	checks.resume_works = not paused
	# A real moving world must freeze, while the planner itself remains clickable.
	game.load_room("r04",["chat","lockpick","backpack"],38)
	checks.reload_auto_open = rp.panel.visible and paused
	rp.close()
	set_clock(1080)
	game.schedule.set_time_speed(1)
	game.set_process(true)
	await frame()
	await frame()
	rp.open()
	var frozen_clock: float = game.schedule.clock_elapsed
	var frozen_elapsed: float = game.elapsed
	var frozen_actors: Array = game.actors.map(func(a): return a.position)
	var frozen_guard: Vector2 = game.guard.position
	var frozen_dog: Vector2 = game.dog.position
	for index in range(20):
		await frame()
	checks.real_paused_clock = game.schedule.clock_elapsed == frozen_clock and game.elapsed == frozen_elapsed
	checks.real_paused_world = game.actors.map(func(a): return a.position) == frozen_actors and game.guard.position == frozen_guard and game.dog.position == frozen_dog
	await press(rp.selectors[3][0])
	await press(rp.picker_options[2])
	checks.paused_menu_editable = rp.draft[0][3] == "rest" and paused
	await press(rp.close_button)
	await frame()
	checks.close_resumes_real_clock = not paused and game.schedule.clock_elapsed > frozen_clock
	game.set_process(false)
	game.schedule.set_time_speed(0)
	# Directly invoked update/advance helpers respect a paused world too.
	rp.open()
	frozen_clock = game.schedule.clock_elapsed
	game.schedule.set_time_speed(16)
	game.schedule.advance(0.5)
	game._process(0.5)
	checks.direct_updates_cannot_unpause = game.schedule.clock_elapsed == frozen_clock and paused
	rp.close()
	# At high speed the next morning lands exactly on 08:00. The same frame
	# may not move actors/guards/dogs after opening the new day's planner.
	game.orders.clear()
	for actor in game.actors:
		actor.position = actor.home
	set_clock(1440+479.95)
	frozen_actors = game.actors.map(func(a): return a.position)
	frozen_guard = game.guard.position
	frozen_dog = game.dog.position
	game._process(0.5)
	checks.natural_morning_auto = rp.panel.visible and paused and game.routines.day == 2 and is_equal_approx(game.schedule.clock_minutes(),480)
	checks.morning_stops_same_frame = game.actors.map(func(a): return a.position) == frozen_actors and game.guard.position == frozen_guard and game.dog.position == frozen_dog
	checks.morning_clears_draft = rp.draft.all(func(row): return row.all(func(k): return k == "idle")) and rp.day_label.text == "第2天"
	await shot("morning-auto")
	await press(rp.close_button)
	for index in range(5):
		game._process(0)
	checks.morning_offered_once = not rp.panel.visible and not paused and not game.routines.morning_pending
	# A night skip opens day3's paused table; midnight itself must not open it.
	game.orders.clear()
	for actor in game.actors:
		actor.position = actor.home
	set_clock(2880+120)
	checks.midnight_no_auto = not rp.panel.visible and game.schedule.is_sleep_time()
	game._update_ui()
	await press(ui.sleep_button)
	checks.skip_morning_auto = rp.panel.visible and paused and game.routines.day == 3 and rp.day_label.text == "第3天" and game.schedule.clock_minutes() == 480
	await press(rp.apply_button)
	checks.skip_apply_resumes = not paused and not rp.panel.visible
	# Reset from the pause menu hands its pause over to the morning planner.
	await press(ui.menu_button)
	game.reset_round(["chat","lockpick","backpack"],38)
	checks.restart_hands_pause_to_planner = rp.panel.visible and paused and not ui.menu.visible and game.schedule.clock_minutes() == 480
	await press(rp.close_button)
	checks.restart_close_resumes = not paused
	# Do not erase another pause owner's state.
	paused = true
	rp.open()
	rp.close()
	checks.prior_pause_preserved = paused
	paused = false
	# Switching to the regular pause menu and back does not leak a pause flag.
	rp.open()
	ui.toggle_menu()
	checks.pause_menu_handoff = ui.menu.visible and not rp.panel.visible and paused
	ui.close_menu()
	checks.menu_close_resumes = not paused
	# The final deadline takes precedence over the next morning prompt.
	for actor in game.actors:
		actor.position = actor.home
	game.orders.clear()
	set_clock(4320+120)
	game.schedule.skip_night()
	checks.deadline_no_planner = game.phase == "failed" and game.schedule.result_panel.visible and not rp.panel.visible and not paused
	# A short, narrow logical safe area uses the compact layout, without scaling
	# individual targets below 48. Restore actual viewport sizing afterward.
	rp.layout(Rect2(16,16,920,504))
	checks.compact_safe = Rect2(16,16,920,504).encloses(rp.panel.get_global_rect())
	checks.compact_targets = rp.selectors.all(func(row): return row.all(func(b): return b.size.x >= 48 and b.size.y >= 48))
	checks.compact_header = not rp.clock_label.get_global_rect().intersects(rp.live_label.get_global_rect()) and not rp.deadline_label.get_global_rect().intersects(rp.live_label.get_global_rect())
	rp.layout(ui.safe_area())
	var passed: bool = checks.values().all(func(x): return x)
	var report := {"passed":passed,"checks":checks,"window":[root.size.x,root.size.y],"canvas":[game.get_viewport_rect().size.x,game.get_viewport_rect().size.y],"scope":"Windows native D3D12; screen-touch controls and actual native picker screen touches, full viewport screenshots. No phone device or human claim."}
	FileAccess.open("res://docs/tests/"+prefix+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("P41_NATIVE passed=",passed," failed=",checks.keys().filter(func(k): return not checks[k]))
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
