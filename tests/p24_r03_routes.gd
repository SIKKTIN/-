extends SceneTree

var game
var checks := {}
var routes: Array = []
var trail: Array = []
var transport: Dictionary = {}
var cargo_distance: float = 0
const DT := 1.0/60.0

func _initialize() -> void:
	call_deferred("run")

func tick(n: int = 1) -> void:
	for i in range(n):
		var before: Vector2 = game.actors[0].position
		game._process(DT)
		cargo_distance += before.distance_to(game.actors[0].position)

func move(id: int, point: Vector2, limit: float = 20) -> bool:
	if not game.command_move(id,point):
		trail.append({"fail":"order_rejected","actor":id,"goal":[point.x,point.y],"state":game.snapshot()})
		return false
	for n in range(int(limit/DT)):
		tick()
		if game.actors[id].escaped:
			return true
		if not game.orders.active.has(id):
			if game.actors[id].position.distance_to(point) < 4:
				return true
			trail.append({"fail":"stopped","actor":id,"goal":[point.x,point.y],"state":game.snapshot()})
			return false
	trail.append({"fail":"timeout","actor":id,"state":game.snapshot()})
	return false

func sequence(id: int, points: Array) -> bool:
	for point in points:
		if not move(id,point):
			return false
	return true

func setup(skills: Array, period: String) -> void:
	game.load_room("r03",skills,19)
	game.presentation.lighting.set_period(period)
	trail = []
	transport = {}
	cargo_distance = 0

func opener(id: int) -> bool:
	if not wait_patrol(false):
		return false
	return sequence(id,[Vector2(460,780),Vector2(700,780),Vector2(1040,580),Vector2(1400,580),Vector2(1533,730)])

func wait_patrol(lower_route: bool) -> bool:
	# Observe the live patrol from the safe room; never change its state/time.
	for n in range(80*60):
		var point: Vector2 = game.guard.position
		var window: bool = point.y < 500 and point.x > 900 if lower_route else point.y > 850 and point.x > 1100
		if game.guard.state == "patrol" and window:
			return true
		tick()
	trail.append({"fail":"patrol_window_timeout","state":game.snapshot()})
	return false

func leave(id: int) -> bool:
	return sequence(id,[Vector2(1660,730),Vector2(1830,700)])

func record(kind: String, period: String, ok: bool) -> void:
	routes.append({"kind":kind,"period":period,"passed":ok,"elapsed":game.elapsed,"captures":game.captures,"transport":transport.duplicate(),"snapshot":game.snapshot(),"failures":trail.duplicate(true)})
	checks[kind+"_"+period] = ok and game.phase == "complete"

func direct(period: String) -> void:
	setup(["lockpick","chat","backpack"],period)
	var ok := opener(0)
	if ok:
		game.select_actor(0)
		game.use_selected_skill()
		for n in range(300):
			tick()
			if game.world.door_open:
				break
		ok = game.world.door_open and leave(0)
	for id in [1,2]:
		if ok:
			ok = opener(id) and leave(id)
	record("skill_lock",period,ok)

func scrap_at(point: Vector2) -> String:
	for item in game.inventory.instances.values():
		if item.location == "ground" and item.definition_id == "scrap" and Vector2(item.position[0],item.position[1]).distance_to(point) < 1:
			return str(item.id)
	return ""

func shopping(period: String, expanded: bool = true) -> void:
	setup(["backpack" if expanded else "chat","chat","chat"],period)
	var groups: Array = [[Vector2(740,1000),Vector2(1130,980),Vector2(1410,1140)]] if expanded else [[Vector2(740,1000)],[Vector2(1130,980)],[Vector2(1410,1140)]]
	var ok := true
	var trips := 0
	for group in groups:
		if not expanded:
			ok = ok and wait_patrol(true)
		ok = ok and sequence(0,[Vector2(460,780),Vector2(640,900)])
		for point in group:
			if ok:
				ok = move(0,point) and game.inventory.try_pickup(0,scrap_at(point)).ok
		if ok:
			ok = sequence(0,[Vector2(1000,1000),Vector2(700,940),Vector2(640,780),Vector2(460,780),Vector2(360,400)])
		if ok:
			trips += 1
			for id in game.inventory.items(0):
				ok = ok and game.trade.try_sell(0,"warehouse_dealer",id).ok
	transport = {"capacity":game.inventory.capacity(0),"returns":trips,"travel_distance":cargo_distance,"elapsed_to_funds":game.elapsed,"money_before_purchase":game.inventory.wallet}
	var key := ""
	for id in game.trade.merchants.warehouse_dealer.stock:
		if game.inventory.instances[id].definition_id == "door_key":
			key = id
	if ok:
		ok = game.trade.try_buy(0,"warehouse_dealer",key).ok and opener(0) and game.inventory.try_use(0,key).ok and leave(0)
	for id in [1,2]:
		if ok:
			ok = opener(id) and leave(id)
	record("cargo_shop_key" if expanded else "single_slot_shop_key",period,ok)

func strong(period: String) -> void:
	setup(["strong","chat","chat"],period)
	var ok := wait_patrol(true) and sequence(0,[Vector2(460,780),Vector2(640,900),Vector2(1000,1000),Vector2(1400,1122),Vector2(1488,1122),Vector2(1690,1122)])
	if ok:
		ok = move(0,Vector2(1830,700))
	for id in [1,2]:
		if ok:
			ok = wait_patrol(true) and sequence(id,[Vector2(460,780),Vector2(640,900),Vector2(1000,1000),Vector2(1400,1122),Vector2(1660,1000),Vector2(1830,700)])
	record("strong_crate",period,ok)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	for period in ["day","night"]:
		direct(period)
		shopping(period)
		strong(period)
	shopping("night",false)
	var normal: Dictionary = routes.back().transport
	var expanded: Dictionary = routes.filter(func(r): return r.kind == "cargo_shop_key" and r.period == "night")[0].transport
	checks.transport_one_vs_three_returns = expanded.returns == 1 and normal.returns == 3 and normal.travel_distance > expanded.travel_distance and normal.money_before_purchase == 9 and expanded.money_before_purchase == 9
	setup(["chat","chat","chat"],"night")
	checks.crate_gap_not_walkable = not game.world.motion_clear(Vector2(1480,1058),Vector2(1650,1058),game.actors[0],false)
	checks.crate_lower_gap_not_walkable = not game.world.motion_clear(Vector2(1480,1183),Vector2(1650,1183),game.actors[0],false)
	checks.initial_stock_and_loot = game.trade.merchants.warehouse_dealer.stock.size() == 3 and game.inventory.instances.values().filter(func(i): return i.location == "ground").size() == 6
	checks.six_scrap_budget = 6*int(game.inventory.definitions.scrap.buy_price) >= int(game.inventory.definitions.door_key.sell_price)
	var before: int = game.guard.route_index
	var transitions := 0
	var inside := true
	for n in range(7200):
		tick()
		inside = inside and game.guard.movement_allowed(game.guard.position)
		if game.guard.route_index != before:
			transitions += 1
			before = game.guard.route_index
	checks.patrol_120s = inside and transitions >= 6
	var ok: bool = checks.values().all(func(x): return x == true)
	var file := FileAccess.open("res://docs/tests/p24-r03-routes.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":ok,"checks":checks,"routes":routes,"patrol_transitions_120s":transitions,"note":"Continuous 60Hz actual game logic and guard AI; no teleport/pause/AI disabling during routes. Not human play evidence."},"\t"))
	print(JSON.stringify({"passed":ok,"checks":checks,"routes":routes.map(func(r): return {"kind":r.kind,"period":r.period,"passed":r.passed,"elapsed":r.elapsed,"captures":r.captures}),"patrol_transitions":transitions}))
	quit(0 if ok else 1)
