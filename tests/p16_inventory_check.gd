extends SceneTree

var checks := {}
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r01", ["backpack", "chat", "strong"], 16)
	var inv = game.inventory
	checks.capacities = inv.capacity(0) == 3 and inv.capacity(1) == 1 and inv.capacity(2) == 1
	game.actors[1].position = game.actors[0].position + Vector2(35, 0)
	var ids: Array = []
	for i in range(4):
		ids.append(inv.add_ground("scrap", game.actors[0].position))
	for i in range(3):
		checks["pickup_%d" % i] = inv.try_pickup(0, ids[i]).ok
	checks.full_bag_no_overwrite = not inv.try_pickup(0, ids[3]).ok and inv.items(0).size() == 3 and inv.instances[ids[3]].location == "ground"
	checks.transfer = inv.try_transfer(0, 1, ids[0]).ok and inv.items(1) == [ids[0]]
	checks.transfer_full_denied = not inv.try_transfer(0, 1, ids[1]).ok and inv.owns(0, ids[1])
	checks.duplicate_pickup_denied = not inv.try_pickup(1, ids[0]).ok
	game.select_actor(1)
	checks.switch_keeps_bags = inv.items(0).size() == 2 and inv.items(1).size() == 1
	inv.wallet = 9
	game.capture_actor(1)
	checks.capture_keeps_items_money = inv.owns(1, ids[0]) and inv.wallet == 9
	checks.drop = inv.try_drop(1, ids[0]).ok and inv.instances[ids[0]].location == "ground"
	checks.pickup_after_drop = inv.try_pickup(1, ids[0]).ok
	game.actors[0].escaped = true
	game.on_actor_escaped(0)
	checks.escaped_items_recorded = inv.instances[ids[1]].location == "escaped" and inv.items(0).size() == 2
	checks.escaped_cannot_drop_transfer = not inv.try_drop(0, ids[1]).ok and not inv.try_transfer(0, 2, ids[1]).ok
	game.reset_round(["chat", "lockpick", "strong"], 16)
	checks.reset_clears = inv.instances.is_empty() and inv.wallet == 0 and inv.items(0).is_empty() and inv.capacity(0) == 1
	var old_pool := true
	for room in ["r01", "r02"]:
		for seed in range(20):
			game.load_room(room, [], seed)
			old_pool = old_pool and game.actors.all(func(a): return a.skill_id in ["chat", "lockpick", "strong"])
	checks.old_rooms_skill_pool = old_pool
	game.room_config.skill_pool = ["chat", "lockpick", "strong", "backpack"]
	game.reset_round([], 33)
	var first: Array = game.actors.map(func(a): return a.skill_id)
	game.reset_round([], 33)
	checks.seed_reproducible = first == game.actors.map(func(a): return a.skill_id)
	checks.snapshot = game.snapshot().inventory.has("instances")
	var ok: bool = checks.values().all(func(x): return x == true)
	var file := FileAccess.open("res://docs/tests/p16-inventory.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": ok, "checks": checks, "note": "Logic/interface verification; merchant and R03 not implemented in P16."}, "\t"))
	print(JSON.stringify({"passed": ok, "checks": checks}))
	quit(0 if ok else 1)
