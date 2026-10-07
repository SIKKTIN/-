extends RefCounted

var game
var library: Dictionary = {}
var actions: Dictionary = {}

func _init(escape_game) -> void:
	game = escape_game
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/library.json"))
	for definition in source.skills:
		library[definition.id] = definition

func chat_guard(actor):
	if actions.has(actor.actor_id) and actions[actor.actor_id].kind == "chat":
		var id: String = actions[actor.actor_id].get("guard_id", "patrol")
		return game.guard if id == "patrol" else game.gate_watch.by_id(id) if game.gate_watch else null
	var candidates: Array = [game.guard]
	if game.gate_watch:
		candidates.append_array(game.gate_watch.guards.filter(func(g): return g.on_duty()))
	candidates.sort_custom(func(a,b): return actor.position.distance_squared_to(a.position) < actor.position.distance_squared_to(b.position))
	for guard in candidates:
		if guard.chat_partner_id < 0 and actor.position.distance_to(guard.position) <= float(library.chat.range) and game.world.line_clear(actor.position,guard.position):
			return guard
	return null

func target_reason(actor) -> String:
	if actor.confined: return "禁闭中，等待关押结束后可继续行动。"
	if actor.escaped or game.phase != "playing":
		return "这个伙伴已经逃脱。"
	if game.attributes and game.attributes.values[actor.actor_id].stamina <= 0.000001:
		return "体力耗尽；回寝室休息后再操作。"
	var definition: Dictionary = library[actor.skill_id]
	if actor.skill_id == "backpack":
		return "被动能力：背包3格。"
	if actor.skill_id == "strong":
		return "用摇杆抵住箱子移动，接触后自动施力推箱。"
	if actor.skill_id == "chat":
		if game.schedule and game.schedule.is_curfew():
			return "宵禁警戒中，看守不接受交谈。"
		var guard = chat_guard(actor)
		if guard == null:
			return "靠近空闲看守后再交谈。"
		if guard.state == "chasing":
			return "看守正在追击，不能交谈。"
		if guard.chat_partner_id >= 0 and guard.chat_partner_id != actor.actor_id:
			return "看守正和另一个伙伴交谈。"
		if actor.position.distance_to(guard.position) > float(definition.range):
			return "靠近看守后再交谈。"
		if not game.world.line_clear(actor.position,guard.position):
			return "你和看守之间有遮挡。"
		return ""
	return door_reason(actor, float(definition.range))

func door_id(actor) -> String:
	if actions.has(actor.actor_id): return str(actions[actor.actor_id].get("door_id",""))
	if game.room_access and not actor.confined:
		var nearest := ""
		var best := 100.0
		for cell in game.room_access.cells():
			var gate: Dictionary = game.world.access_by_id(str(cell.door_id))
			if gate.is_empty() or not gate.closed: continue
			var occupied: bool = game.room_access.held.values().any(func(r): return str(game.room_access.cells()[int(r.cell)].door_id) == str(gate.id))
			var distance: float = actor.position.distance_to(gate.rect.get_center()+Vector2(0,45))
			if occupied and distance < best:
				best = distance
				nearest = str(gate.id)
		return nearest
	return ""

func door_rect(actor) -> Rect2:
	var gate: Dictionary = game.world.access_by_id(door_id(actor))
	return game.world.door if gate.is_empty() else gate.rect

func door_point(actor) -> Vector2:
	var gate: Dictionary = game.world.access_by_id(door_id(actor))
	return game.world.door.position+Vector2(-27,game.world.door.size.y*0.5) if gate.is_empty() else gate.rect.get_center()+Vector2(0,45)

func open_target(id: String) -> void:
	if id.is_empty(): game.world.open_door()
	else:
		game.world.set_access_closed(id,false)
		game.room_access.tick()

func door_reason(actor, distance: float = 55) -> String:
	if actor.confined: return "禁闭中，等待关押结束后可继续行动。"
	if actor.escaped or game.phase != "playing":
		return "这个伙伴已经逃脱。"
	if game.attributes and game.attributes.values[actor.actor_id].stamina <= 0.000001:
		return "体力耗尽；回寝室休息后再操作。"
	var id := door_id(actor)
	if (id.is_empty() and game.world.door_open) or (not id.is_empty() and not game.world.access_by_id(id).get("closed",true)):
		return "锁门已经打开。"
	var point: Vector2 = door_point(actor)
	if actor.position.distance_to(point) > distance:
		return "靠近锁门左侧，会出现撬锁图标。"
	if not game.world.line_clear(actor.position,point):
		return "你和门边操作点之间有遮挡。"
	if id.is_empty() and game.gate_watch and game.gate_watch.blocking():
		return "白天铁门有人值守；避开值守时段再开门。"
	return ""

func toggle(actor_id: int) -> bool:
	if not game.actor_is_controllable(actor_id): return false
	if actions.has(actor_id):
		cancel(actor_id,"已停止操作，门的进度会保留。")
		return true
	var actor = game.actors[actor_id]
	var reason := target_reason(actor)
	if reason != "":
		game.show_status(reason)
		return false
	if game.routines:
		game.routines.take_control(actor_id)
	var guard = chat_guard(actor) if actor.skill_id == "chat" else null
	actions[actor_id] = {"kind":actor.skill_id,"anchor":actor.position,"door_id":door_id(actor),"guard_id":guard.guard_id if guard != null and guard.has_method("is_gate_guard") else "patrol"}
	actor.action_state = "chatting" if actor.skill_id == "chat" else "lockpicking"
	actor.queue_redraw()
	if actor.skill_id == "chat":
		guard.start_chat(actor_id)
		if game.gate_watch:
			game.gate_watch.tick(0)
		game.show_status("伙伴%d交谈中；当前非戒备，看守不追捕。" % (actor_id+1))
	else:
		game.show_status("主角撬锁中；离开会中断，进度保留。")
	return true

func cancel(actor_id: int, reason: String = "") -> void:
	if not actions.has(actor_id):
		return
	var action: Dictionary = actions[actor_id]
	var guard = chat_guard(game.actors[actor_id]) if action.kind == "chat" else null
	actions.erase(actor_id)
	var actor = game.actors[actor_id]
	actor.action_state = "idle"
	actor.queue_redraw()
	if guard != null and guard.chat_partner_id == actor_id:
		guard.stop_chat()
		if game.gate_watch:
			game.gate_watch.tick(0)
	if reason != "":
		game.show_status(reason)

func cancel_chat(reason: String) -> void:
	for actor_id in actions.keys():
		if actions[actor_id].kind == "chat":
			cancel(actor_id,reason)

func clear_all() -> void:
	for actor_id in actions.keys():
		cancel(actor_id)

func tick(delta: float) -> void:
	var contributions := {}
	for actor_id in actions.keys():
		var actor = game.actors[actor_id]
		var action: Dictionary = actions[actor_id]
		if actor.escaped or actor.confined:
			cancel(actor_id)
			continue
		if actor.position.distance_to(action.anchor) > 12:
			cancel(actor_id,"伙伴%d离开了操作位置，技能中断。" % (actor_id+1))
			continue
		var reason := door_reason(actor) if action.kind == "lock_tool" else target_reason(actor)
		if reason != "":
			cancel(actor_id,reason)
			continue
		if action.kind == "chat":
			var guard = chat_guard(actor)
			guard.facing = guard.position.direction_to(actor.position)
		else:
			var id: String = str(action.get("door_id",""))
			var efficiency: float = game.attributes.work_efficiency(actor_id) if game.attributes else 1.0
			contributions[id] = float(contributions.get(id,0))+delta*efficiency/(float(game.inventory.definitions.lock_tool.duration) if action.kind == "lock_tool" else float(library.lockpick.duration))
	for id in contributions:
		var gate: Dictionary = game.world.access_by_id(str(id))
		var progress: float = minf(1.0,(game.world.lock_progress if str(id).is_empty() else float(gate.get("progress",0)))+float(contributions[id]))
		if str(id).is_empty(): game.world.lock_progress = progress
		else: gate.progress = progress
		if progress >= 1.0:
			open_target(str(id))
			for actor_id in actions.keys():
				if actions[actor_id].kind in ["lockpick","lock_tool"] and str(actions[actor_id].get("door_id","")) == str(id): cancel(actor_id)
			game.show_status("禁闭门已撬开，伙伴获救！" if not str(id).is_empty() else "锁撬开了！伙伴和看守都能走这条通路。")

func snapshot() -> Array:
	var result: Array = []
	for actor_id in actions:
		var action: Dictionary = actions[actor_id]
		result.append({"actor_id":actor_id,"kind":action.kind,"anchor":[action.anchor.x,action.anchor.y],"guard_id":action.get("guard_id","patrol")})
	return result
