extends SceneTree

var game
var checks := {}

func _initialize() -> void:
	root.gui_embed_subwindows = true
	call_deferred("run")

func frame(focus: bool = true) -> void:
	if focus:
		root.grab_focus()
	await process_frame
	await RenderingServer.frame_post_draw

func press(control: Control) -> void:
	await frame()
	for index in range(6):
		if root.has_focus():
			break
		await frame()
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = root.get_final_transform()*control.get_global_rect().get_center()
	touch.pressed = true
	Input.parse_input_event(touch)
	await frame(false)
	touch = touch.duplicate()
	touch.pressed = false
	Input.parse_input_event(touch)
	await frame(false)

func shot(label_text: String) -> void:
	await frame()
	await frame()
	root.get_texture().get_image().save_png("res://docs/tests/p41-work-native-"+label_text+".png")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.load_room("r04",["chat","lockpick","backpack"],39)
	game.schedule.set_time_speed(0)
	checks.morning_planner_paused = paused and game.routine_panel.panel.visible
	checks.pay_explained = "60" in game.routine_panel.note.text and "+4" in game.routine_panel.note.text
	for id in range(3):
		await press(game.routine_panel.selectors[0][id])
		checks["picker_%d" % id] = game.routine_panel.picker.visible
		await press(game.routine_panel.picker_options[1])
		checks["work_choice_%d" % id] = game.routine_panel.draft[id][0] == "work"
	await press(game.routine_panel.apply_button)
	checks.touch_apply_unpauses = not paused and game.orders.active.size() == 3
	for index in range(1200):
		game._process(1.0/60)
		if game.routines.working_ids().size() == 3:
			break
	checks.real_arrival = game.routines.working_ids().size() == 3 and game.inventory.wallet == 0
	game.select_actor(0)
	game.map_camera.locate_selected()
	game.fullscreen_ui.minimap_collapsed = true
	game.fullscreen_ui.layout()
	game.schedule.set_time_speed(1)
	game._process(6.25)
	game.presentation.tick(0)
	checks.half_round_visible = game.routines.status_for(0) == "工作中 50%" and game.inventory.wallet == 0
	checks.cards_working = game.fullscreen_ui.faces.size() == 3 and range(3).all(func(id): return game.routines.status_for(id) == "工作中 50%")
	var visual = game.presentation.visuals[0]
	var pose_before: float = visual.work_clock
	var position_before: Vector2 = game.actors[0].position
	game._process(0.16)
	checks.work_pose_animated = visual.working and not is_equal_approx(visual.work_clock,pose_before)
	checks.pose_keeps_foot_and_world = game.actors[0].position == position_before and visual.frame_name == "idle"
	await shot("working")
	var seconds_left: float = (60.0-game.routines.work_minutes[0])/1440.0*game.schedule.day_seconds
	game._process(seconds_left)
	checks.three_actual_wages = game.inventory.wallet == 12 and game.routines.work_rounds == [1,1,1]
	checks.hud_real_wallet = game.fullscreen_ui.wallet.text == "12"
	checks.receipts = range(3).all(func(id): return game.routines.recent_wages.has(id) and game.routines.recent_wages[id].amount == 4 and game.elapsed < game.routines.recent_wages[id].until)
	checks.toast_explains_pay = "工资 +12" in game.status_label.text
	await shot("wages")
	await press(game.fullscreen_ui.routine_button)
	var stopped_pose: float = visual.work_clock
	var stopped_progress: Array = game.routines.work_minutes.duplicate()
	game._process(30)
	for index in range(12):
		await frame()
	checks.planner_freezes_work_and_pose = paused and visual.work_clock == stopped_pose and game.routines.work_minutes == stopped_progress and game.inventory.wallet == 12
	await press(game.routine_panel.close_button)
	checks.touch_resume = not paused
	# Only location is a fixture: the wallet and purchased item use earned wages.
	game.schedule.clock_elapsed = (1080.0-480)/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.routines.tick()
	for index in range(1800):
		game.trade.tick(1.0/60)
		if game.trade.is_open(game.trade.actors.keys()[0]):
			break
	game.schedule.set_time_speed(0)
	game.routines.take_control(0)
	var merchant_id: String = game.trade.merchants.keys()[0]
	var merchant: Dictionary = game.trade.merchants[merchant_id]
	game.actors[0].position = Vector2(merchant.position[0],merchant.position[1])+Vector2(0,60)
	game.select_actor(0)
	game.map_camera.locate_selected()
	game.presentation.tick(0)
	game._update_ui()
	await frame()
	var prompt = game.presentation.interaction
	var key: String = "trade:"+merchant_id
	checks.trade_prompt = prompt.extras.has(key) and prompt.extras[key].visible
	if checks.trade_prompt:
		await press(prompt.extras[key])
	checks.touch_shop_opens = game.shop_panel.panel.visible and not paused
	await press(game.shop_panel.buy)
	checks.earned_money_buys_item = game.inventory.wallet == 3 and game.inventory.bags[0].size() == 1 and game.inventory.instances[game.inventory.bags[0][0]].definition_id == "door_key"
	await shot("earned-money-trade")
	var failures: Array = checks.keys().filter(func(key_text): return not checks[key_text])
	var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"size":root.size,"scope":"Native D3D12 touch scheduling, actual workstation arrival, work animation, wages and real-money merchant purchase"}
	var file := FileAccess.open("res://docs/tests/p41-work-native.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("P41_NATIVE "+JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
