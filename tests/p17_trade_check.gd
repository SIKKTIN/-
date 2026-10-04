extends SceneTree

var checks := {}
var game
func _initialize() -> void:
	call_deferred("run")

func fixture() -> void:
	game.load_room("r01", ["backpack", "chat", "strong"], 17)
	game.room_config.merchants = [{"id":"dealer", "position":[180,235], "stock":[{"definition_id":"door_key", "count":1}, {"definition_id":"lock_tool", "count":2}]}]
	game.reset_round(["backpack", "chat", "strong"], 17)
	game.actors[1].position = Vector2(220,235)

func stock(kind: String) -> String:
	for id in game.trade.merchants.dealer.stock:
		if game.inventory.instances[id].definition_id == kind:
			return id
	return ""

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	fixture()
	var inv = game.inventory
	var trade = game.trade
	var key := stock("door_key")
	checks.no_money_no_change = not trade.try_buy(0,"dealer",key).ok and inv.wallet == 0 and inv.instances[key].location == "shop"
	for n in range(3):
		var id: String = inv.add_ground("scrap",game.actors[0].position)
		inv.try_pickup(0,id)
		checks["sell_%d"%n] = trade.try_sell(0,"dealer",id).ok
		checks["duplicate_sell_%d"%n] = not trade.try_sell(0,"dealer",id).ok
	checks.three_scrap_funds_key = inv.wallet == 9 and trade.try_buy(0,"dealer",key).ok and inv.wallet == 0 and inv.owns(0,key)
	checks.duplicate_buy_rejected = not trade.try_buy(0,"dealer",key).ok and inv.items(0) == [key]
	checks.cannot_sell_other_bag = not trade.try_sell(1,"dealer",key).ok
	inv.wallet = 20
	var scrap: String = inv.add_ground("scrap",game.actors[1].position)
	inv.try_pickup(1,scrap)
	var tool := stock("lock_tool")
	checks.full_bag_no_charge = not trade.try_buy(1,"dealer",tool).ok and inv.wallet == 20 and inv.instances[tool].location == "shop"
	game.actors[0].position = Vector2(350,235)
	checks.remote_trade_no_charge = not trade.try_buy(0,"dealer",tool).ok and inv.wallet == 20
	checks.remote_use_keeps_key = not inv.try_use(0,key).ok and inv.owns(0,key) and not game.world.door_open
	game.actors[0].position = Vector2(459,395)
	checks.key_immediate = inv.try_use(0,key).ok and game.world.door_open and not inv.items(0).has(key)
	checks.key_duplicate_no_effect = not inv.try_use(0,key).ok
	fixture()
	key = stock("door_key")
	inv.wallet = 30
	trade.try_buy(0,"dealer",key)
	trade.try_sell(0,"dealer",key)
	checks.no_arbitrage = inv.wallet == 25
	checks.repurchase_same_instance = trade.try_buy(0,"dealer",key).ok and inv.wallet == 16 and inv.owns(0,key)
	tool = stock("lock_tool")
	trade.try_buy(0,"dealer",tool)
	game.actors[0].position = Vector2(459,395)
	checks.tool_start_consumes = inv.try_use(0,tool).ok and inv.instances[tool].location == "consumed" and game.skills.actions[0].kind == "lock_tool"
	for n in range(180):
		game.skills.tick(1.0/60)
	checks.tool_six_seconds = absf(game.world.lock_progress-0.5) < 0.001 and not game.world.door_open
	game.actors[0].position += Vector2(-30,0)
	game.skills.tick(0)
	checks.interrupt_preserves_progress_no_refund = not game.skills.actions.has(0) and absf(game.world.lock_progress-0.5) < 0.001 and not inv.items(0).has(tool)
	game.world.open_door()
	checks.open_door_no_consumption = not inv.try_use(0,key).ok and inv.owns(0,key)
	fixture()
	game.select_actor(0)
	game.shop_panel.open("dealer")
	checks.shop_opens = game.shop_panel.panel.visible
	game.select_actor(1)
	checks.shop_closes_on_switch = not game.shop_panel.panel.visible
	game.shop_panel.open("dealer")
	game.capture_actor(1)
	checks.shop_closes_on_capture = not game.shop_panel.panel.visible
	game.select_actor(0)
	game.shop_panel.open("dealer")
	game.actors[0].position = Vector2(350,235)
	game.shop_panel.refresh()
	checks.shop_closes_on_distance = not game.shop_panel.panel.visible
	game.reset_round(["backpack","chat","strong"],17)
	checks.reset_stock_wallet = inv.wallet == 0 and trade.merchants.dealer.stock.size() == 3 and inv.instances.values().all(func(i): return i.location == "shop")
	var ok: bool = checks.values().all(func(x): return x == true)
	var file := FileAccess.open("res://docs/tests/p17-trade.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":ok,"checks":checks,"note":"Fixture-based atomic transactions and item behavior; R03 runtime routes are P19."},"\t"))
	print(JSON.stringify({"passed":ok,"checks":checks}))
	quit(0 if ok else 1)
