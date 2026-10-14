extends RefCounted

# Slots refer to kinds, so using one of several identical consumables does not
# lose the binding. Ownership and availability always come from Inventory.
const SLOT_COUNT := 4
var game
var bindings: Array[String] = ["", "", "", ""]
var revision := 0
var bag_key: Array = []
var counts: Dictionary = {}
var first_ids: Dictionary = {}

func _init(owner_game):
	game = owner_game

func reset():
	bindings.assign(["", "", "", ""])
	bag_key.clear()
	counts.clear()
	first_ids.clear()
	revision += 1

func sync_bag():
	var ids: Array = game.inventory.items(game.PLAYER_ACTOR_ID)
	if bag_key == ids: return
	bag_key = ids
	counts.clear()
	first_ids.clear()
	for id in ids:
		if not game.inventory.owns(game.PLAYER_ACTOR_ID, str(id)): continue
		var kind: String = game.inventory.instances[id].definition_id
		counts[kind] = int(counts.get(kind, 0)) + 1
		if not first_ids.has(kind): first_ids[kind] = str(id)

func owns_kind(kind: String) -> bool:
	sync_bag()
	return int(counts.get(kind, 0)) > 0

func first_item(kind: String) -> String:
	sync_bag()
	return str(first_ids.get(kind, ""))

func bind_reason(index: int, id: String) -> String:
	if index < 0 or index >= SLOT_COUNT: return "这个快捷槽不存在。"
	if not game.inventory.owns(game.PLAYER_ACTOR_ID, id): return "请先把物品放入背包。"
	var definition: Dictionary = game.inventory.definitions[game.inventory.instances[id].definition_id]
	if not definition.has("use_action"): return "这是材料，没有可绑定的使用操作。"
	return ""

func bind_item(index: int, id: String) -> Dictionary:
	var error := bind_reason(index, id)
	if not error.is_empty(): return {"ok": false, "reason": error}
	var kind: String = game.inventory.instances[id].definition_id
	# Rebinding an existing kind moves its shortcut; it never moves bag items.
	for other in range(SLOT_COUNT):
		if other != index and bindings[other] == kind: bindings[other] = ""
	bindings[index] = kind
	revision += 1
	return {"ok": true, "reason": "已绑定%s，物品仍留在背包。" % game.inventory.definitions[kind].name}

func clear_slot(index: int):
	if index < 0 or index >= SLOT_COUNT: return
	bindings[index] = ""
	revision += 1

func state(index: int) -> Dictionary:
	sync_bag()
	var kind: String = bindings[index]
	var definition: Dictionary = game.inventory.definitions.get(kind, {})
	var id: String = str(first_ids.get(kind, ""))
	var reason := "快捷槽为空，请打开背包绑定道具。" if kind.is_empty() else "背包里已没有%s。" % definition.get("name", "这件物品")
	if not id.is_empty(): reason = game.inventory.use_reason(game.PLAYER_ACTOR_ID, id)
	return {"kind": kind, "id": id, "count": int(counts.get(kind, 0)), "reason": reason,
		"label": str(definition.get("name", "空快捷槽")), "action": str(definition.get("use_action", "")),
		"quantity": bool(definition.get("consumable", false))}

func activate(index: int) -> Dictionary:
	if game.world_input_blocked(): return {"ok": false, "reason": "关闭当前界面后再使用快捷道具。"}
	var current := state(index)
	var result: Dictionary
	if not str(current.reason).is_empty(): result = {"ok": false, "reason": current.reason}
	else: result = game.inventory.try_use(game.PLAYER_ACTOR_ID, str(current.id))
	game.show_status(str(result.reason))
	game._update_ui()
	return result

func snapshot() -> Dictionary:
	return {"bindings": bindings.duplicate(), "revision": revision}
