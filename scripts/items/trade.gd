extends RefCounted

var game
var merchants: Dictionary = {}

func _init(owner_game) -> void:
	game = owner_game

func reset(config: Dictionary) -> void:
	merchants.clear()
	for spec in config.get("merchants", []):
		var id := str(spec.id)
		merchants[id] = {"id": id, "name": spec.get("name", "商人"), "position": spec.position.duplicate(), "stock": []}
		for offer in spec.get("stock", []):
			for n in range(int(offer.count)):
				var item_id: String = game.inventory.add_ground(str(offer.definition_id), Vector2.ZERO)
				game.inventory.instances[item_id].location = "shop"
				game.inventory.instances[item_id]["merchant_id"] = id
				merchants[id].stock.append(item_id)

func reason(actor_id: int, merchant_id: String) -> String:
	if game.schedule and game.schedule.is_curfew():
		return "20:00已收摊，请在白天交易。"
	if not game.inventory.available(actor_id) or not merchants.has(merchant_id):
		return "当前伙伴不能交易。"
	var actor = game.actors[actor_id]
	var pos: Array = merchants[merchant_id].position
	var point := Vector2(pos[0], pos[1])
	if actor.position.distance_to(point) > 100 or not game.world.line_clear(actor.position, point):
		return "靠近商人100单位且无遮挡才能交易。"
	return ""

func try_buy(actor_id: int, merchant_id: String, item_id: String) -> Dictionary:
	var error := reason(actor_id, merchant_id)
	if error != "":
		return {"ok": false, "reason": error}
	var inv = game.inventory
	if not merchants[merchant_id].stock.has(item_id) or not inv.instances.has(item_id) or inv.instances[item_id].location != "shop":
		return {"ok": false, "reason": "这件物品已经售出。"}
	var price := int(inv.definitions[inv.instances[item_id].definition_id].sell_price)
	if inv.items(actor_id).size() >= inv.capacity(actor_id):
		return {"ok": false, "reason": "背包已满，购买未扣款。"}
	if inv.wallet < price:
		return {"ok": false, "reason": "钱不够：先卖旧零件换钱。"}
	# All checks above, one synchronous commit below.
	inv.wallet -= price
	merchants[merchant_id].stock.erase(item_id)
	inv.bags[actor_id].append(item_id)
	inv.instances[item_id].location = "bag"
	inv.instances[item_id].actor_id = actor_id
	return {"ok": true, "reason": "购买成功，交给当前伙伴。"}

func try_sell(actor_id: int, merchant_id: String, item_id: String) -> Dictionary:
	var error := reason(actor_id, merchant_id)
	if error != "":
		return {"ok": false, "reason": error}
	var inv = game.inventory
	if not inv.owns(actor_id, item_id):
		return {"ok": false, "reason": "只能出售当前伙伴背包中的物品。"}
	var price := int(inv.definitions[inv.instances[item_id].definition_id].buy_price)
	inv.bags[actor_id].erase(item_id)
	inv.wallet += price
	inv.instances[item_id].location = "shop"
	inv.instances[item_id].actor_id = -1
	inv.instances[item_id]["merchant_id"] = merchant_id
	merchants[merchant_id].stock.append(item_id)
	return {"ok": true, "reason": "出售成功，共享钱包 +%d。" % price}

func snapshot() -> Dictionary:
	return merchants.duplicate(true)
