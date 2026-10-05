extends RefCounted

# One authoritative instance registry: ground, a person's bag, or carried out.
var game
var instances: Dictionary = {}
var bags: Dictionary = {}
var wallet: int = 0
var serial: int = 0
var definitions: Dictionary = {}

func _init(owner_game) -> void:
	game = owner_game
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/library.json"))
	for spec in source.items:
		definitions[spec.id] = spec

func reset(config: Dictionary = {}) -> void:
	instances.clear()
	bags = {0: [], 1: [], 2: []}
	wallet = 0
	serial = 0
	for entry in config.get("items", []):
		add_ground(str(entry.definition_id), Vector2(entry.position[0], entry.position[1]))

func capacity(actor_id: int) -> int:
	return 3 if game.actors[actor_id].skill_id == "backpack" else 1

func items(actor_id: int) -> Array:
	return bags.get(actor_id, []).duplicate()

func available(actor_id: int) -> bool:
	return actor_id >= 0 and actor_id < game.actors.size() and game.phase == "playing" and not game.actors[actor_id].escaped

func add_ground(definition_id: String, point: Vector2) -> String:
	serial += 1
	var id := "%s-%d-%d" % [game.room_id, game.deal_number, serial]
	instances[id] = {"id": id, "definition_id": definition_id, "location": "ground", "actor_id": -1, "position": [point.x, point.y]}
	return id

func _result(ok: bool, reason: String = "") -> Dictionary:
	return {"ok": ok, "reason": reason}

func try_pickup(actor_id: int, id: String) -> Dictionary:
	if not available(actor_id) or not instances.has(id) or instances[id].location != "ground":
		return _result(false, "物品已不在地面。")
	var actor = game.actors[actor_id]
	var pos: Array = instances[id].position
	var point := Vector2(pos[0], pos[1])
	if actor.position.distance_to(point) > 60 or not game.world.line_clear(actor.position, point):
		return _result(false, "靠近物品且无遮挡才能拾取。")
	if bags[actor_id].size() >= capacity(actor_id):
		return _result(false, "背包已满：先放下或交给伙伴。")
	if game.routines:
		game.routines.take_control(actor_id)
	bags[actor_id].append(id)
	instances[id].location = "bag"
	instances[id].actor_id = actor_id
	return _result(true)

func owns(actor_id: int, id: String) -> bool:
	return available(actor_id) and bags.get(actor_id, []).has(id) and instances.has(id) and instances[id].location == "bag" and instances[id].actor_id == actor_id

func try_drop(actor_id: int, id: String) -> Dictionary:
	if not owns(actor_id, id):
		return _result(false, "当前伙伴不能操作这件物品。")
	if game.routines:
		game.routines.take_control(actor_id)
	var point: Vector2 = game.actors[actor_id].position
	bags[actor_id].erase(id)
	instances[id].location = "ground"
	instances[id].actor_id = -1
	instances[id].position = [point.x, point.y]
	return _result(true)

func try_transfer(actor_id: int, receiver_id: int, id: String) -> Dictionary:
	if actor_id == receiver_id or not owns(actor_id, id) or not available(receiver_id):
		return _result(false, "请选择另一位尚未离场的伙伴。")
	var from: Vector2 = game.actors[actor_id].position
	var to: Vector2 = game.actors[receiver_id].position
	if from.distance_to(to) > 40 or not game.world.line_clear(from, to):
		return _result(false, "交接需要两人靠近40单位且无遮挡。")
	if bags[receiver_id].size() >= capacity(receiver_id):
		return _result(false, "对方背包已满。")
	if game.routines:
		game.routines.take_control(actor_id)
	bags[actor_id].erase(id)
	bags[receiver_id].append(id)
	instances[id].actor_id = receiver_id
	return _result(true)

func carry_out(actor_id: int) -> void:
	for id in bags.get(actor_id, []):
		instances[id].location = "escaped"

func consume(actor_id: int, id: String) -> bool:
	if not owns(actor_id, id):
		return false
	bags[actor_id].erase(id)
	instances[id].location = "consumed"
	instances[id].actor_id = -1
	return true

func try_use(actor_id: int, id: String) -> Dictionary:
	if not owns(actor_id, id):
		return _result(false, "请先选择当前伙伴的物品。")
	var kind := str(instances[id].definition_id)
	if kind not in ["door_key", "lock_tool"]:
		return _result(false, "旧零件可以携带或带出，商人不收购。")
	var error: String = game.skills.door_reason(game.actors[actor_id], 55)
	if error != "":
		return _result(false, error)
	if game.skills.actions.has(actor_id):
		return _result(false, "先停止当前操作，再使用物品。")
	if game.routines:
		game.routines.take_control(actor_id)
	game.orders.stop(actor_id)
	if kind == "door_key":
		consume(actor_id, id)
		game.world.open_door()
		return _result(true, "钥匙已消耗，门立即打开。")
	consume(actor_id, id)
	game.skills.actions[actor_id] = {"kind": "lock_tool", "anchor": game.actors[actor_id].position}
	game.actors[actor_id].action_state = "lockpicking"
	return _result(true, "工具已消耗，开始6秒撬锁；可切换伙伴。")

func snapshot() -> Dictionary:
	return {"wallet": wallet, "instances": instances.duplicate(true), "bags": bags.duplicate(true), "capacities": game.actors.map(func(a): return capacity(a.actor_id))}
