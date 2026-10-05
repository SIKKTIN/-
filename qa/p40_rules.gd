extends SceneTree

var game
var checks := {}

func _initialize() -> void:
	call_deferred("run")

func minute(value: float) -> void:
	game.schedule.clock_elapsed = (value-480)/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.routines.tick()
	game.trade.tick(0)

func opponent() -> void:
	game.orders.clear()
	game.routines.take_control(0)
	game.guard.position = game.world.guard_start
	game.guard.facing = Vector2.RIGHT
	game.actors[0].position = game.guard.position+Vector2(25,0)
	game.actors[0].immune_until = 0
	game.actors[0].action_state = "idle"

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r04",["chat","lockpick","backpack"],40)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	for value in [480,616,720,839,840,1080,1199]:
		minute(value)
		opponent()
		var captures: int = game.captures
		checks["day_%d_visible" % value] = game.guard.sees(game.actors[0].position)
		game.guard.tick(0)
		checks["day_%d_no_catch" % value] = game.captures == captures and game.guard.state == "patrol" and game.guard.target_id == -1
		checks["day_%d_no_investigation" % value] = not game.guard.investigate(game.actors[0].position)
		game.guard.state = "chasing"
		game.guard.target_id = 0
		game.guard._capture_if_touching()
		checks["day_%d_stale_capture_blocked" % value] = game.captures == captures
		game.guard.tick(0)
		checks["day_%d_stale_chase_cleared" % value] = game.guard.state == "patrol" and game.guard.target_id == -1
	minute(1080)
	opponent()
	game.dog.position = game.actors[0].position+Vector2(50,0)
	var barks: int = game.dog.bark_count
	game.dog.tick(0.2)
	checks.free_time_dog_patrol_only = game.dog.state == "patrol" and game.dog.target_id == -1 and game.dog.bark_count == barks and game.guard.state == "patrol"
	game.presentation.lighting.set_period("night")
	game.guard.tick(0)
	checks.lighting_not_arrest_authority = game.guard.state == "patrol"
	minute(1200)
	opponent()
	var captures: int = game.captures
	game.guard.tick(0)
	checks.curfew_touch_captures = game.captures == captures+1
	game.actors[0].position = game.actors[0].home
	game.guard.tick(0)
	checks.dorm_zone_safe_before_midnight = game.guard.target_id != 0
	minute(1440)
	checks.midnight_inspection_preserved = game.guard.inspection_route.size() == 3 and game.guard.search_zone() == game.world.bounds
	game.orders.clear()
	game.guard.position = game.actors[0].home+Vector2(60,0)
	game.actors[0].position = game.actors[0].home
	game.actors[0].immune_until = 0
	captures = game.captures
	game.guard.tick(0)
	checks.sleeping_not_captured = game.captures == captures
	opponent()
	game.guard.tick(0)
	checks.midnight_awake_captured = game.captures == captures+1
	minute(1919)
	opponent()
	game.guard.state = "chasing"
	game.guard.target_id = 0
	minute(1920)
	game.routine_panel.close()
	game.guard.tick(0)
	checks.morning_releases_target = game.guard.state == "patrol" and game.guard.target_id == -1
	# Genuine full morning/afternoon navigation; no merchant teleport fixture.
	for identifier in ["r03","r04"]:
		game.load_room(identifier,["chat","lockpick","backpack"],40)
		game.routine_panel.close()
		game.schedule.set_time_speed(1)
		var id: String = game.trade.actors.keys()[0]
		var npc = game.trade.actors[id]
		var start: Vector2 = npc.position
		checks[identifier+"_morning_closed"] = not game.trade.is_open(id)
		var safe := true
		var moving := false
		var visited_work := false
		for index in range(4000):
			var before: Vector2 = npc.position
			game._process(1.0/30)
			safe = safe and game.world.can_place_circle(npc.position,17,npc,false) and game.world.motion_clear(before,npc.position,npc)
			moving = moving or npc.position.distance_to(start) > 100
			visited_work = visited_work or (npc.entry.kind == "work" and npc.at_destination())
			if game.schedule.clock_minutes() >= 720:
				break
		checks[identifier+"_real_work_and_commute"] = moving and visited_work
		checks[identifier+"_no_wall_crossing"] = safe
		checks[identifier+"_noon_open_at_stall"] = game.trade.is_open(id) and npc.at_destination() and npc.entry.kind == "shop"
		game.actors[0].position = npc.position+Vector2(0,60)
		game.inventory.wallet = 20 # Isolated commerce fixture; salary tested separately.
		var item: String = game.trade.merchants[id].stock[0]
		var result: Dictionary = game.trade.try_buy(0,id,item)
		checks[identifier+"_open_buy"] = result.ok and game.inventory.wallet == 11
		result = game.trade.try_sell(0,id,item)
		checks[identifier+"_open_sell"] = result.ok and game.inventory.wallet == 15
		game.select_actor(0)
		game.shop_panel.open(id)
		checks[identifier+"_panel_open"] = game.shop_panel.panel.visible
		minute(840)
		checks[identifier+"_close_on_shift"] = not game.trade.is_open(id) and not game.shop_panel.panel.visible
		var wallet: int = game.inventory.wallet
		checks[identifier+"_late_buy_rejected"] = not game.trade.try_buy(0,id,item).ok and game.inventory.wallet == wallet
		var stopped: Dictionary = npc.snapshot()
		game.routine_panel.open()
		game.trade.tick(3)
		checks[identifier+"_pause_freezes_npc"] = npc.snapshot() == stopped
		game.routine_panel.close()
		visited_work = false
		for index in range(4000):
			game._process(1.0/30)
			visited_work = visited_work or (npc.entry.kind == "work" and npc.at_destination())
			if game.schedule.clock_minutes() >= 1080:
				break
		checks[identifier+"_evening_open"] = visited_work and game.trade.is_open(id)
		minute(1200)
		checks[identifier+"_night_closed"] = not game.trade.is_open(id)
		minute(1440)
		checks[identifier+"_midnight_rest"] = npc.entry.kind == "rest" and not game.trade.is_open(id)
		minute(1920)
		game.routine_panel.close()
		checks[identifier+"_stock_cash_persist"] = game.inventory.wallet == 15 and game.trade.merchants[id].stock.has(item)
		game.reset_round()
		checks[identifier+"_reset"] = game.inventory.wallet == 0 and game.trade.actors.size() == 1 and game.trade.merchants[id].stock.size() == 3
		game.routine_panel.close()
	for identifier in ["r01","r02"]:
		game.load_room(identifier,["chat","lockpick","strong"],40)
		game.routine_panel.close()
		game._process(0.1)
		checks[identifier+"_no_merchant_compatible"] = game.trade.actors.is_empty() and game.phase == "playing"
	var passed: bool = checks.values().all(func(value): return value)
	FileAccess.open("res://docs/tests/p40-rules.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"scope":"Actual full morning/afternoon merchant navigation. Isolated close-guard and commerce position/wallet fixtures. No wall teleport used for NPC."},"\t")+"\n")
	print("P40_RULES passed=",passed," failures=",checks.keys().filter(func(k): return not checks[k]))
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
