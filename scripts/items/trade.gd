extends RefCounted

const Merchant = preload("res://scripts/actors/merchant.gd")

var game
var merchants: Dictionary = {}
var actors: Dictionary = {}

func _init(owner_game) -> void:
	game = owner_game

func reset(config: Dictionary) -> void:
	for actor in actors.values():
		actor.free()
	actors.clear()
	merchants.clear()
	for spec in config.get("merchants", []):
		var id := str(spec.id)
		merchants[id] = {"id": id, "name": spec.get("name", "商人"), "position": spec.position.duplicate(), "stock": []}
		var actor = Merchant.new()
		game.add_child(actor)
		actor.configure(game,spec)
		actors[id] = actor
		for offer in spec.get("stock", []):
			for n in range(int(offer.count)):
				var item_id: String = game.inventory.add_ground(str(offer.definition_id), Vector2.ZERO)
				game.inventory.instances[item_id].location = "shop"
				game.inventory.instances[item_id]["merchant_id"] = id
				merchants[id].stock.append(item_id)

func tick(delta: float) -> void:
	for id in actors:
		actors[id].tick(delta)
		merchants[id].position = [actors[id].position.x,actors[id].position.y]
	# Close an already-open shop before UI processing or a late purchase click.
	if game.shop_panel and game.shop_panel.panel.visible and not is_open(game.shop_panel.merchant_id):
		game.shop_panel.close()
		game.show_status("商人已收摊。营业时间：12:00–14:00、18:00–20:00。")

func is_open(id: String) -> bool:
	if not actors.has(id):
		return false
	actors[id].update_schedule()
	return actors[id].is_open()

func reason(actor_id: int, merchant_id: String) -> String:
	if not game.inventory.available(actor_id) or not merchants.has(merchant_id):
		return "当前伙伴不能交易。"
	if not is_open(merchant_id):
		return "商人%s；12:00–14:00、18:00–20:00到摊位营业。" % actors[merchant_id].activity_text()
	var actor = game.actors[actor_id]
	var pos: Array = merchants[merchant_id].position
	var point := Vector2(pos[0], pos[1])
	if game.world.is_under_roof(point): return "进入房间后才能与里面的商人交易。"
	if actor.position.distance_to(point) > 100 or not game.world.line_clear(actor.position, point):
		return "靠近商人100单位且无遮挡才能交易。"
	return ""

func try_buy(actor_id: int, merchant_id: String, item_id: String) -> Dictionary:
	if not game.actor_is_controllable(actor_id): return {"ok":false,"reason":"这名囚徒不能手动购买。"}
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
		return {"ok": false, "reason": "钱不够：安排工作获得工资。"}
	# All checks above, one synchronous commit below.
	inv.wallet -= price
	merchants[merchant_id].stock.erase(item_id)
	inv.bags[actor_id].append(item_id)
	inv.instances[item_id].location = "bag"
	inv.instances[item_id].actor_id = actor_id
	return {"ok": true, "reason": "购买成功，交给当前伙伴。"}

func try_sell(actor_id: int, merchant_id: String, item_id: String) -> Dictionary:
	# Retain a safe rejection for old callers; no inventory/currency mutation.
	return {"ok": false, "reason": "商人不收购物品，仅可购买。"}

func snapshot() -> Dictionary:
	var result: Dictionary = merchants.duplicate(true)
	for id in actors:
		result[id].merge(actors[id].snapshot(),true)
	return result
