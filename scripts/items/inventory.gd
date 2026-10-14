extends RefCounted

# One authoritative instance registry: ground, a person's bag, or carried out.
var game
var instances: Dictionary = {}
var bags: Dictionary = {}
var wallet: int = 0
var serial: int = 0
var definitions: Dictionary = {}
var layout_cache: Dictionary = {}
var layout_keys: Dictionary = {}
var layout_revision:=0
var metadata_revision:=0
var extra_rows: Dictionary = {}
var reading_dialog: AcceptDialog
const Packing=preload("res://scripts/items/grid_packing.gd")

func _init(owner_game) -> void:
	game = owner_game
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/library.json"))
	for spec in source.items:
		definitions[spec.id] = spec

func reset(config: Dictionary = {}) -> void:
	instances.clear()
	metadata_revision+=1
	extra_rows.clear()
	if is_instance_valid(reading_dialog): reading_dialog.hide()
	layout_cache.clear()
	layout_keys.clear()
	layout_revision+=1
	bags = {0: [], 1: [], 2: []}
	wallet = 0
	serial = 0
	for entry in config.get("items", []):
		add_ground(str(entry.definition_id), Vector2(entry.position[0], entry.position[1]))

func capacity(actor_id: int) -> int:
	var dimensions:=grid_size(actor_id)
	return dimensions.x*dimensions.y

func grid_size(actor_id: int) -> Vector2i:
	var base := 6 if game.actors[actor_id].skill_id=="backpack" else 4
	return Vector2i(5,mini(6,base+int(extra_rows.get(actor_id,0))))

func item_size(kind: String) -> Vector2i:
	var shape: Array=definitions.get(kind,{}).get("grid_size",[1,1])
	return Vector2i(maxi(1,int(shape[0])),maxi(1,int(shape[1])))

func grid_layout(actor_id: int) -> Dictionary:
	var bag: Array=items(actor_id)
	var key: Array=[grid_size(actor_id),bag]
	if layout_keys.get(actor_id,[])==key:return layout_cache[actor_id]
	# Keep existing positions. Only newly acquired items use first-free placement.
	var arrangement: Dictionary=layout_cache.get(actor_id,{})
	for id in arrangement.keys():
		if not bag.has(id):arrangement.erase(id)
	for id in bag:
		if arrangement.has(id):continue
		var shape:=item_size(str(instances[id].definition_id))
		var point:=Packing.first_space(arrangement,grid_size(actor_id),shape)
		if point.x>=0:arrangement[id]=Rect2i(point,shape)
	layout_keys[actor_id]=key
	layout_cache[actor_id]=arrangement
	layout_revision+=1
	return arrangement

func placement_reason(actor_id: int, id: String, point: Vector2i, moving:=false) -> String:
	if not available(actor_id) or not instances.has(id):return "物品已经不可操作。"
	if moving and not owns(actor_id,id):return "物品已不在背包。"
	var rect:=Rect2i(point,item_size(str(instances[id].definition_id)))
	if not Rect2i(Vector2i.ZERO,grid_size(actor_id)).encloses(rect):return "物品超出了背包边界。"
	if not Packing.fits(grid_layout(actor_id),grid_size(actor_id),rect,id if moving else ""):return "这些格子已被其他物品占用。"
	return ""

func place_item(actor_id: int, id: String, point: Vector2i):
	grid_layout(actor_id)[id]=Rect2i(point,item_size(str(instances[id].definition_id)))
	layout_revision+=1

func move_item(actor_id: int, id: String, point: Vector2i) -> Dictionary:
	var error:=placement_reason(actor_id,id,point,true)
	if not error.is_empty():return _result(false,error)
	place_item(actor_id,id,point)
	return _result(true,"已调整物品位置。")

func forget_position(actor_id: int, id: String):
	if layout_cache.has(actor_id):layout_cache[actor_id].erase(id)
	layout_keys.erase(actor_id)
	layout_revision+=1

func find_space(actor_id: int, kind: String) -> Vector2i:
	return preload("res://scripts/items/grid_packing.gd").first_space(grid_layout(actor_id),grid_size(actor_id),item_size(kind))

func used_cells(actor_id: int) -> int:
	var count:=0
	for id in items(actor_id):
		var shape:=item_size(str(instances[id].definition_id))
		count+=shape.x*shape.y
	return count

func items(actor_id: int) -> Array:
	return bags.get(actor_id, []).duplicate()

func available(actor_id: int) -> bool:
	return actor_id >= 0 and actor_id < game.actors.size() and game.phase == "playing" and not game.actors[actor_id].escaped

func add_ground(definition_id: String, point: Vector2) -> String:
	serial += 1
	var id := "%s-%d-%d" % [game.room_id, game.deal_number, serial]
	instances[id] = {"id": id, "definition_id": definition_id, "location": "ground", "actor_id": -1, "position": [point.x, point.y]}
	instances[id].merge(definitions.get(definition_id,{}).get("initial_state",{}).duplicate(true),false)
	return id

func _result(ok: bool, reason: String = "") -> Dictionary:
	return {"ok": ok, "reason": reason}

func try_pickup(actor_id: int, id: String) -> Dictionary:
	if instances.has(id) and instances[id].location == "ground":
		var coords: Array = instances[id].position
		if game.world.is_under_roof(Vector2(coords[0],coords[1])): return _result(false,"进入房间后才能拾取室内物品。")
	if not game.actor_is_controllable(actor_id): return _result(false,"这名囚徒按日程自动生活，不能手动操作。")
	if not available(actor_id) or not instances.has(id) or instances[id].location != "ground":
		return _result(false, "物品已不在地面。")
	var actor = game.actors[actor_id]
	var pos: Array = instances[id].position
	var point := Vector2(pos[0], pos[1])
	if actor.position.distance_to(point) > 60 or not game.world.line_clear(actor.position, point):
		return _result(false, "靠近物品且无遮挡才能拾取。")
	if find_space(actor_id,str(instances[id].definition_id)).x<0:
		return _result(false, "背包没有足够的连续空格，先放下一些物品。")
	if game.routines:
		game.routines.take_control(actor_id)
	bags[actor_id].append(id)
	instances[id].location = "bag"
	instances[id].actor_id = actor_id
	return _result(true)

func owns(actor_id: int, id: String) -> bool:
	return game.actor_is_controllable(actor_id) and available(actor_id) and bags.get(actor_id, []).has(id) and instances.has(id) and instances[id].location == "bag" and instances[id].actor_id == actor_id

func try_drop(actor_id: int, id: String) -> Dictionary:
	if not owns(actor_id, id):
		return _result(false, "当前伙伴不能操作这件物品。")
	if game.routines:
		game.routines.take_control(actor_id)
	var point: Vector2 = game.actors[actor_id].position
	bags[actor_id].erase(id)
	forget_position(actor_id,id)
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
	if find_space(receiver_id,str(instances[id].definition_id)).x<0:
		return _result(false, "对方背包已满。")
	if game.routines:
		game.routines.take_control(actor_id)
	bags[actor_id].erase(id)
	forget_position(actor_id,id)
	bags[receiver_id].append(id)
	instances[id].actor_id = receiver_id
	if game.social: game.social.record_gift(receiver_id,str(definitions[instances[id].definition_id].name))
	return _result(true)

func carry_out(actor_id: int) -> void:
	for id in bags.get(actor_id, []):
		instances[id].location = "escaped"

func consume(actor_id: int, id: String) -> bool:
	if not owns(actor_id, id):
		return false
	bags[actor_id].erase(id)
	forget_position(actor_id,id)
	instances[id].location = "consumed"
	instances[id].actor_id = -1
	return true

func use_reason(actor_id: int, id: String) -> String:
	if not owns(actor_id,id): return "请先选择背包里的物品。"
	if game.world_input_blocked(true): return "关闭当前界面后再使用道具。"
	if game.skills.actions.has(actor_id): return "先停止当前操作，再使用道具。"
	var kind: String = str(instances[id].definition_id)
	var definition: Dictionary = definitions.get(kind,{})
	if definition.get("keycard",false): return "随身携带即可，靠近门时自动匹配；无需手动使用。"
	if kind in ["factory_map","water_card"]: return ""
	if definition.has("restore") and game.attributes:
		var effect: Dictionary = definition.restore
		return "当前状态已满，暂时不需要使用。" if float(game.attributes.values[actor_id][str(effect.stat)]) >= 100 else ""
	if definition.has("read_text"): return ""
	if kind == "canvas_pouch": return "背包已达到30格，扩容袋不会消耗。" if capacity(actor_id) >= 30 else ""
	if kind == "cigarettes": return "靠近一位空闲的工友后才能送礼。" if gift_receiver().is_empty() else ""
	if kind in ["bread","bandage"] and game.attributes:
		var stat: String = "fullness" if kind == "bread" else "stamina"
		return "当前状态已满，暂时不需要使用。" if float(game.attributes.values[actor_id][stat]) >= 100 else ""
	if kind in ["door_key","lock_tool"]: return game.skills.door_reason(game.actors[actor_id],55)
	return "这件材料可收集、携带或带出，不能直接使用。"

func item_name(id: String) -> String:
	if game.keycards and game.keycards.is_card(id): return game.keycards.item_name(id)
	return str(definitions.get(str(instances.get(id,{}).get("definition_id","")),{}).get("name","物品"))

func item_description(id: String) -> String:
	if game.keycards and game.keycards.is_card(id): return game.keycards.description(id)
	var instance: Dictionary=instances.get(id,{})
	var kind: String=str(instance.get("definition_id",""))
	var text: String=str(definitions.get(kind,{}).get("description",""))
	if kind=="water_card":text="水卡余额：%d点。\n" % int(instance.get("water_balance",0))+text
	return text

func action_label(id: String) -> String:
	var kind: String = str(instances.get(id,{}).get("definition_id",""))
	return str(definitions.get(kind,{}).get("use_action","使用"))

func try_use(actor_id: int, id: String) -> Dictionary:
	var reason := use_reason(actor_id,id)
	if not reason.is_empty(): return _result(false,reason)
	var kind := str(instances[id].definition_id)
	var definition: Dictionary = definitions.get(kind,{})
	if definition.has("restore"):
		var effect: Dictionary = definition.restore
		if not consume(actor_id,id): return _result(false,"物品已不在背包。")
		var stat := str(effect.stat)
		game.attributes.values[actor_id][stat] = minf(100,float(game.attributes.values[actor_id][stat])+float(effect.amount))
		return _result(true,"使用%s，恢复%d点%s。" % [definition.name,int(effect.amount),"饱腹" if stat == "fullness" else "体力"])
	if definition.has("read_text") or kind == "water_card":
		if not is_instance_valid(reading_dialog):
			reading_dialog = AcceptDialog.new()
			reading_dialog.name = "ItemReading"
			reading_dialog.theme = load("res://art/ui/fullscreen/theme.tres")
			reading_dialog.ok_button_text = "收起"
			game.add_child(reading_dialog)
		reading_dialog.title = str(definition.name)
		reading_dialog.dialog_text = item_description(id) if kind == "water_card" else str(definition.read_text)
		reading_dialog.popup_centered(Vector2i(540,320))
		return _result(true,"已展开%s，阅读不会消耗物品。" % definition.name)
	if kind == "canvas_pouch":
		if not consume(actor_id,id): return _result(false,"物品已不在背包。")
		extra_rows[actor_id] = 2
		layout_keys.erase(actor_id)
		layout_revision += 1
		return _result(true,"已安装扩容袋，本轮背包增加到30格。")
	if kind == "cigarettes":
		var receiver := gift_receiver()
		if receiver.is_empty() or not consume(actor_id,id): return _result(false,"工友已离开，请靠近后再送礼。")
		game.social.record_gift(int(receiver.trim_prefix("prisoner:")),str(definition.name))
		return _result(true,"已送给%s，好感和信任提升。" % game.social.person(receiver).name)
	if kind == "factory_map":
		return _result(game.map_viewer != null and game.map_viewer.open(),"已展开园区地图。")
	if kind in ["bread","bandage"] and game.attributes:
		var values: Dictionary=game.attributes.values[actor_id]
		var stat: String="fullness" if kind=="bread" else "stamina"
		if not consume(actor_id,id):return _result(false,"物品已不在背包。")
		values[stat]=minf(100,float(values[stat])+(25 if kind=="bread" else 20))
		return _result(true,"吃下馒头，恢复25点饱腹。" if kind=="bread" else "处理擦伤，恢复20点体力。")
	if game.routines:
		game.routines.take_control(actor_id)
	game.orders.stop(actor_id)
	if kind == "door_key":
		consume(actor_id, id)
		game.skills.open_target(game.skills.door_id(game.actors[actor_id]))
		return _result(true, "钥匙已消耗，门立即打开。")
	consume(actor_id, id)
	game.skills.actions[actor_id] = {"kind": "lock_tool", "anchor": game.actors[actor_id].position,"door_id":game.skills.door_id(game.actors[actor_id])}
	game.actors[actor_id].action_state = "lockpicking"
	return _result(true, "工具已消耗，开始6秒撬锁；离开会中断。")

func snapshot() -> Dictionary:
	return {"wallet": wallet, "instances": instances.duplicate(true), "bags": bags.duplicate(true), "placements": layout_cache.duplicate(true), "capacities": game.actors.map(func(a): return capacity(a.actor_id)), "extra_rows":extra_rows.duplicate()}

func gift_receiver() -> String:
	if not game.social: return ""
	var nearest := ""
	var distance := 90.0
	for id in game.social.people:
		var person: Dictionary = game.social.person(id)
		if person.role != "prisoner" or not game.social.accessible(id,90) or not game.social.free_to_help(id): continue
		var reach: float = game.actors[0].position.distance_to(person.node.position)
		if reach < distance: nearest = id; distance = reach
	return nearest
