extends SceneTree

var game
var checks := {}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r04",["chat","chat","lockpick"],41)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	checks.two_sentries = game.gate_watch.guards.size() == 2 and game.world.gate_guarded
	var point: Vector2 = game.world.door.position+Vector2(-27,game.world.door.size.y/2)
	game.actors[2].position = point
	checks.lock_blocked = "值守" in game.skills.target_reason(game.actors[2]) and not game.skills.toggle(2)
	var key: String = game.inventory.add_ground("door_key",point)
	game.inventory.try_pickup(2,key)
	checks.key_blocked_not_consumed = not game.inventory.try_use(2,key).ok and game.inventory.owns(2,key) and not game.world.door_open
	game.actors[0].position = game.gate_watch.guards[0].position+Vector2(-80,0)
	game.actors[1].position = game.gate_watch.guards[1].position+Vector2(-80,0)
	checks.first_chat = game.skills.toggle(0) and game.gate_watch.guards[0].chat_partner_id == 0
	checks.one_guard_still_blocks = game.world.gate_guarded
	checks.second_chat = game.skills.toggle(1) and game.gate_watch.guards[1].chat_partner_id == 1
	checks.two_chats_release_gate = not game.world.gate_guarded
	checks.key_now_opens = game.inventory.try_use(2,key).ok and game.world.door_open and not game.inventory.owns(2,key)
	checks.open_gate_path = game.world.motion_clear(point,point+Vector2(75,0),game.actors[2])
	game.skills.cancel(0)
	checks.release_chat_reblocks = game.world.gate_guarded and not game.world.motion_clear(point,point+Vector2(75,0),game.actors[2])
	game.skills.toggle(0)
	var captures: int = game.captures
	for index in range(30):
		game.gate_watch.tick(1.0/60)
	checks.sentries_never_catch_in_day = game.captures == captures and game.gate_watch.guards.all(func(g): return g.target_id == -1)
	game.skills.clear_all()
	game.schedule.clock_elapsed = (1200.0-480)/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.gate_watch.tick(0)
	checks.night_posts_off_duty = not game.world.gate_guarded and game.gate_watch.guards.all(func(g): return not g.visible and not g.on_duty())
	game.reset_round(["chat","chat","lockpick"],41)
	game.routine_panel.close()
	checks.reset_posts = game.gate_watch.guards.size() == 2 and game.world.gate_guarded and game.gate_watch.guards.all(func(g): return g.chat_partner_id == -1)
	game.schedule.clock_elapsed = (720.0-480)/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.trade.tick(0)
	var id: String = game.trade.merchants.keys()[0]
	game.actors[0].position = Vector2(540,620)
	game.inventory.wallet = 20
	var item: String = game.trade.merchants[id].stock[0]
	checks.buy_ok = game.trade.try_buy(0,id,item).ok and game.inventory.wallet == 11 and game.inventory.owns(0,item)
	var before: Dictionary = game.inventory.snapshot()
	var stock: Array = game.trade.merchants[id].stock.duplicate()
	checks.sell_rejected = not game.trade.try_sell(0,id,item).ok
	checks.sell_preserves_assets = game.inventory.snapshot() == before and game.trade.merchants[id].stock == stock
	game.select_actor(0)
	game.shop_panel.open(id)
	checks.no_sell_button = game.shop_panel.panel.find_children("*","Button",true,false).all(func(b): return "卖" not in b.text)
	checks.no_sell_price = range(game.shop_panel.offers.item_count).all(func(index): return "卖" not in game.shop_panel.offers.get_item_text(index) and "价格" in game.shop_panel.offers.get_item_text(index))
	game.load_room("r03",["chat","chat","lockpick"],41)
	game.routine_panel.close()
	checks.r03_two_posts = game.gate_watch.guards.size() == 2 and game.world.gate_guarded
	game.load_room("r01",["chat","chat","lockpick"],41)
	game.routine_panel.close()
	checks.r01_no_new_posts = game.gate_watch.guards.is_empty() and not game.world.gate_guarded
	var passed: bool = checks.values().all(func(v): return v)
	FileAccess.open("res://docs/tests/p41-rules.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"scope":"Isolated actor positions for real two-guard chat and door/key/barrier rules; explicit commerce wallet fixture; no human claim."},"\t")+"\n")
	print("P41_RULES passed=",passed," failures=",checks.keys().filter(func(k): return not checks[k]))
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
