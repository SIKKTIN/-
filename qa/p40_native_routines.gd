extends SceneTree

var game
var checks := {}

func _initialize() -> void:
	root.gui_embed_subwindows = true
	call_deferred("run")

func frame() -> void:
	root.grab_focus()
	await process_frame
	await RenderingServer.frame_post_draw

func press(control: Control) -> void:
	await frame()
	var event := InputEventScreenTouch.new()
	event.position = root.get_final_transform()*control.get_global_rect().get_center()
	event.pressed = true
	Input.parse_input_event(event)
	await frame()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frame()

func shot(label_text: String) -> void:
	game.presentation.tick(0)
	game._update_ui()
	await frame()
	await frame()
	root.get_texture().get_image().save_png("res://docs/tests/p40-routines-"+label_text+".png")

func minute(value: float) -> void:
	game.schedule.clock_elapsed = (value-480)/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.routines.tick()
	game.trade.tick(0)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.load_room("r04",["chat","lockpick","backpack"],40)
	game.routine_panel.close()
	game.schedule.set_time_speed(1)
	game.fullscreen_ui.minimap_collapsed = true
	game.fullscreen_ui.layout()
	var id: String = game.trade.actors.keys()[0]
	var npc = game.trade.actors[id]
	var start: Vector2 = npc.position
	for index in range(90):
		game._process(1.0/30)
	checks.merchant_actually_walking = npc.position.distance_to(start) > 50 and npc.moved_this_frame and npc.entry.kind == "work"
	checks.morning_no_trade = not game.trade.is_open(id)
	game.map_camera.center_on(npc.position)
	await shot("merchant-commute")
	for index in range(4000):
		game._process(1.0/30)
		if game.schedule.clock_minutes() >= 720:
			break
	checks.real_noon_arrival = game.trade.is_open(id)
	game.routines.take_control(0)
	game.orders.clear()
	game.actors[0].position = npc.position+Vector2(0,60)
	game.select_actor(0)
	game.map_camera.locate_selected()
	game.schedule.set_time_speed(0)
	game.inventory.wallet = 20 # UI commerce fixture; actual salary buying is in p40-work-native.
	game.presentation.tick(0)
	game._update_ui()
	await frame()
	var key: String = "trade:"+id
	checks.noon_prompt_visible = game.presentation.interaction.extras.has(key) and game.presentation.interaction.extras[key].visible
	await shot("merchant-open")
	if checks.noon_prompt_visible:
		await press(game.presentation.interaction.extras[key])
	checks.touch_opens_business = game.shop_panel.panel.visible
	await press(game.shop_panel.buy)
	checks.touch_buy = game.inventory.wallet == 11 and game.inventory.items(0).size() == 1
	await press(game.inventory_panel.slots[0])
	await press(game.shop_panel.sell)
	checks.touch_sell = game.inventory.wallet == 15 and game.inventory.items(0).is_empty()
	minute(840)
	checks.auto_close_at_14 = not game.shop_panel.panel.visible and not game.trade.is_open(id)
	game.presentation.tick(0)
	checks.closed_prompt_hidden = not game.presentation.interaction.extras[key].visible
	checks.closed_rejects_buy_without_deduction = not game.trade.try_buy(0,id,game.trade.merchants[id].stock[0]).ok and game.inventory.wallet == 15
	await shot("merchant-closed")
	# A manually controlled actor visibly inside the guard cone in daytime.
	minute(616)
	game.orders.clear()
	game.actors[0].position = Vector2(900,1130)
	game.actors[0].immune_until = 0
	game.routines.take_control(0)
	game.guard.position = Vector2(820,1130)
	game.guard.facing = Vector2.RIGHT
	var captures: int = game.captures
	game.guard.tick(0)
	game.map_camera.locate_selected()
	checks.visible_day_cone_no_chase = game.guard.sees(game.actors[0].position) and game.guard.state == "patrol" and game.captures == captures
	game.guard.position = game.actors[0].position-Vector2(25,0)
	game.guard.tick(0)
	checks.day_touch_no_capture = game.captures == captures and game.guard.state == "patrol"
	game.guard.position = Vector2(820,1130)
	await shot("day-no-capture")
	minute(1200)
	game.orders.clear()
	game.routines.take_control(0)
	game.actors[0].position = Vector2(900,1130)
	game.guard.position = Vector2(820,1130)
	game.guard.facing = Vector2.RIGHT
	game.guard.tick(0)
	checks.night_cone_chases = game.guard.state == "chasing" and game.guard.target_id == 0
	await shot("night-alert")
	var passed: bool = checks.values().all(func(v): return v)
	FileAccess.open("res://docs/tests/p40-native-routines.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"scope":"Native D3D12: actual merchant morning commute and noon arrival; real touch buy/sell. Isolated actor/guard positions demonstrate arrest rules; UI purchase uses explicit wallet fixture."},"\t")+"\n")
	print("P40_ROUTINES_NATIVE passed=",passed," failures=",checks.keys().filter(func(k): return not checks[k]))
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
