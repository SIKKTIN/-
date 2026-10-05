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
	root.get_texture().get_image().save_png("res://docs/tests/p41-features-"+label_text+".png")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.load_room("r04",["chat","chat","lockpick"],41)
	game.routine_panel.close()
	game.fullscreen_ui.minimap_collapsed = true
	game.fullscreen_ui.layout()
	game.schedule.set_time_speed(0)
	checks.cards_two_attributes = game.cards.all(func(c): return c.size.y == 104 and c.size.x <= 124) and game.attributes.values.all(func(v): return v.stamina == 100 and v.fullness == 80)
	checks.sentries_visible = game.gate_watch.guards.size() == 2 and game.gate_watch.guards.all(func(g): return g.visible and g.get_children().any(func(v): return v is Node2D))
	game.actors[0].position = Vector2(1660,680)
	game.actors[1].position = Vector2(1660,860)
	game.actors[2].position = Vector2(1817,770)
	game.select_actor(2)
	game.map_camera.center_on(Vector2(1750,760))
	await shot("gate-guarded")
	checks.guarded_lock_no_prompt = not game.presentation.interaction.button.visible and "值守" in game.skills.target_reason(game.actors[2])
	await press(game.cards[0])
	game.map_camera.center_on(Vector2(1750,760))
	game.presentation.tick(0)
	await press(game.presentation.interaction.button)
	checks.touch_first_chat = game.gate_watch.guards[0].chat_partner_id == 0 and game.world.gate_guarded
	await press(game.cards[1])
	game.map_camera.center_on(Vector2(1750,760))
	game.presentation.tick(0)
	await press(game.presentation.interaction.button)
	checks.touch_second_chat = game.gate_watch.guards[1].chat_partner_id == 1 and not game.world.gate_guarded
	await press(game.cards[2])
	game.map_camera.center_on(Vector2(1750,760))
	game.presentation.tick(0)
	checks.unwatched_lock_prompt = game.presentation.interaction.button.visible
	await press(game.presentation.interaction.button)
	checks.touch_lock_starts = game.skills.actions.has(2) and game.actors[2].action_state == "lockpicking"
	game._process(1)
	checks.real_lock_progress = game.world.lock_progress > 0 and game.captures == 0
	await shot("two-chats-unlock")
	game._process(3.2)
	checks.real_gate_open = game.world.door_open and not game.world.gate_guarded
	checks.through_gate_command = game.command_move(2,Vector2(1940,770))
	for index in range(180):
		game._process(1.0/60)
	checks.real_through_gate = game.actors[2].position.x > game.world.door.end.x and game.captures == 0
	await shot("gate-passed")
	game.load_room("r04",["chat","chat","lockpick"],41)
	game.routine_panel.close()
	game.schedule.set_time_speed(1)
	game.fullscreen_ui.minimap_collapsed = true
	game.fullscreen_ui.layout()
	var npc = game.trade.actors.values()[0]
	var seen := {}
	for index in range(60):
		game._process(1.0/60)
		seen[game.items_view.merchant_frame_index(npc)] = true
		if index in [2,12,22,32]:
			game.map_camera.center_on(npc.position)
			await shot("merchant-walk-%d" % index)
	checks.eight_true_walk_frames = game.items_view.merchant_walk_frames.size() == 8 and range(8).all(func(index): return seen.has(index))
	var elapsed: float = npc.walk_elapsed
	game.routine_panel.open()
	game._process(3)
	await frame()
	checks.pause_freezes_walk = npc.walk_elapsed == elapsed
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	game.trade.tick(0)
	checks.stopped_returns_idle = game.items_view.merchant_frame_index(npc) == -1
	game.schedule.clock_elapsed = (720.0-480)/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.schedule.set_time_speed(1)
	for index in range(1800):
		game.trade.tick(1.0/60)
		if game.trade.is_open(npc.get_parent().trade.actors.keys()[0]):
			break
	game.schedule.set_time_speed(0)
	game.trade.tick(0)
	game.actors[0].position = npc.position+Vector2(0,60)
	game.select_actor(0)
	game.map_camera.locate_selected()
	game.inventory.wallet = 20
	game.shop_panel.open(game.trade.actors.keys()[0])
	await frame()
	checks.only_buy_buttons = game.shop_panel.panel.visible and game.shop_panel.panel.find_children("*","Button",true,false).all(func(b): return "卖" not in b.text)
	await shot("buy-only-shop")
	await press(game.shop_panel.buy)
	checks.touch_buy_works = game.inventory.wallet == 11 and game.inventory.items(0).size() == 1
	game.shop_panel.close()
	game.attributes.values[0].stamina = 18
	game.attributes.values[0].fullness = 12
	game.attributes.values[1].stamina = 55
	game.attributes.values[1].fullness = 62
	await shot("attribute-bars")
	var passed: bool = checks.values().all(func(v): return v)
	FileAccess.open("res://docs/tests/p41-native-features.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"scope":"Native D3D12 real touch selection/two separate chats/lock and actual passage. Actual merchant motion renders all8 frames. Explicit start positions/key shop wallet and low attributes for visual fixtures."},"\t")+"\n")
	print("P41_FEATURES passed=",passed," failures=",checks.keys().filter(func(k): return not checks[k]))
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
