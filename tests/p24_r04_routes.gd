extends SceneTree

const DT := 1.0/60.0
var game
var checks := {}
var routes: Array = []
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func tick() -> void:
	game._process(DT)

func move(id: int, point: Vector2, limit: float = 30) -> bool:
	if not game.command_move(id,point):
		failures.append({"reason":"order_rejected","actor":id,"point":str(point),"status":game.status_text})
		return false
	for step in range(int(limit/DT)):
		tick()
		if game.actors[id].escaped:
			return true
		if not game.orders.active.has(id):
			if game.actors[id].position.distance_to(point) < 4:
				return true
			failures.append({"reason":"captured_or_stopped","actor":id,"point":str(point),"captures":game.captures,"elapsed":game.elapsed})
			return false
	failures.append({"reason":"timeout","actor":id,"point":str(point)})
	return false

func sequence(id: int, points: Array) -> bool:
	for point in points:
		if not move(id,point):
			return false
	return true

func wait_window() -> bool:
	for step in range(120*60):
		if game.guard.state == "patrol" and game.guard.position.x > 1400 and game.guard.position.y > 1100:
			return true
		tick()
	failures.append({"reason":"patrol_window_timeout"})
	return false

func to_door(id: int) -> bool:
	return wait_window() and sequence(id,[Vector2(540,970),Vector2(680,950),Vector2(700,680),Vector2(1450,680),Vector2(1817,770)])

func leave(id: int) -> bool:
	return sequence(id,[Vector2(1950,770),Vector2(2235,790)])

func setup(skills: Array, period: String) -> void:
	game.load_room("r04",skills,23)
	game.presentation.lighting.set_period(period)
	failures.clear()

func record(kind: String, period: String, ok: bool) -> void:
	checks[kind+"_"+period] = ok and game.phase == "complete" and game.captures == 0
	routes.append({"kind":kind,"period":period,"passed":checks[kind+"_"+period],"elapsed":game.elapsed,"captures":game.captures,"wallet":game.inventory.wallet,"failures":failures.duplicate(true)})

func direct(period: String) -> void:
	setup(["lockpick","chat","backpack"],period)
	var ok := to_door(0)
	if ok:
		game.select_actor(0)
		game.use_selected_skill()
		for step in range(300):
			tick()
			if game.world.door_open:
				break
		ok = game.world.door_open and leave(0)
	for id in [1,2]:
		if ok:
			ok = to_door(id) and leave(id)
	record("skill_lock",period,ok)

func shopping(period: String) -> void:
	setup(["backpack","chat","chat"],period)
	var ok := wait_window() and sequence(0,[Vector2(540,970),Vector2(680,950),Vector2(700,580)])
	for point in [Vector2(1020,310),Vector2(1410,310),Vector2(1410,570)]:
		if ok:
			ok = move(0,point)
			var found := ""
			for entry in game.inventory.instances.values():
				if entry.location == "ground" and Vector2(entry.position[0],entry.position[1]).distance_to(point) < 1:
					found = entry.id
			ok = ok and found != "" and game.inventory.try_pickup(0,found).ok
	if ok:
		ok = sequence(0,[Vector2(700,580),Vector2(680,950),Vector2(540,970),Vector2(540,650)])
	if ok:
		for item in game.inventory.items(0):
			ok = ok and game.trade.try_sell(0,"prison_dealer",item).ok
	var key := ""
	for item in game.trade.merchants.prison_dealer.stock:
		if game.inventory.instances[item].definition_id == "door_key":
			key = item
	if ok:
		ok = game.trade.try_buy(0,"prison_dealer",key).ok and to_door(0) and game.inventory.try_use(0,key).ok and leave(0)
	for id in [1,2]:
		if ok:
			ok = to_door(id) and leave(id)
	record("cargo_shop_key",period,ok)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	for period in ["day","night"]:
		direct(period)
		shopping(period)
	var passed: bool = checks.values().all(func(v): return v == true)
	var file := FileAccess.open("res://docs/tests/p24-r04-routes.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"routes":routes,"scope":"Continuous 60Hz actual gameplay and guard AI from real cell starts, no teleport/pause/AI disabling during routes; art/mobile/device evidence separate."},"\t"))
	print(JSON.stringify({"passed":passed,"checks":checks,"routes":routes}))
	quit(0 if passed else 1)
