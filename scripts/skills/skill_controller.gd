extends RefCounted

var game
var library: Dictionary = {}
var actions: Dictionary = {}

func _init(escape_game) -> void:
	game = escape_game
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/library.json"))
	for definition in source.skills:
		library[definition.id] = definition

func target_reason(actor) -> String:
	if actor.escaped or game.phase != "playing":
		return "这个伙伴已经逃脱。"
	var definition: Dictionary = library[actor.skill_id]
	if actor.skill_id == "backpack":
		return "被动能力：背包3格。"
	if actor.skill_id == "strong":
		return "右键箱子另一侧移动；接触后自动施力推箱。"
	if actor.skill_id == "chat":
		if game.guard.state == "chasing":
			return "狱警正在追击，不能交谈。"
		if game.guard.chat_partner_id >= 0 and game.guard.chat_partner_id != actor.actor_id:
			return "狱警正和另一个伙伴交谈。"
		if actor.position.distance_to(game.guard.position) > float(definition.range):
			return "靠近狱警后再交谈。"
		if not game.world.line_clear(actor.position,game.guard.position):
			return "你和狱警之间有遮挡。"
		return ""
	return door_reason(actor, float(definition.range))

func door_reason(actor, distance: float = 55) -> String:
	if actor.escaped or game.phase != "playing":
		return "这个伙伴已经逃脱。"
	if game.world.door_open:
		return "锁门已经打开。"
	var point: Vector2 = game.world.door.position + Vector2(-27,game.world.door.size.y*0.5)
	if actor.position.distance_to(point) > distance:
		return "靠近锁门左侧，会出现撬锁图标。"
	if not game.world.line_clear(actor.position,point):
		return "你和门边操作点之间有遮挡。"
	return ""

func toggle(actor_id: int) -> bool:
	if actions.has(actor_id):
		cancel(actor_id,"已停止操作，门的进度会保留。")
		return true
	var actor = game.actors[actor_id]
	var reason := target_reason(actor)
	if reason != "":
		game.show_status(reason)
		return false
	actions[actor_id] = {"kind":actor.skill_id,"anchor":actor.position}
	actor.action_state = "chatting" if actor.skill_id == "chat" else "lockpicking"
	actor.queue_redraw()
	if actor.skill_id == "chat":
		game.guard.start_chat(actor_id)
		game.show_status("伙伴%d交谈中；狱警仍会发现其他人。" % (actor_id+1))
	else:
		game.show_status("伙伴%d撬锁中；可以换人行动，离开会中断。" % (actor_id+1))
	return true

func cancel(actor_id: int, reason: String = "") -> void:
	if not actions.has(actor_id):
		return
	var action: Dictionary = actions[actor_id]
	actions.erase(actor_id)
	var actor = game.actors[actor_id]
	actor.action_state = "idle"
	actor.queue_redraw()
	if action.kind == "chat" and game.guard.chat_partner_id == actor_id:
		game.guard.stop_chat()
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
	var contribution: float = 0
	for actor_id in actions.keys():
		var actor = game.actors[actor_id]
		var action: Dictionary = actions[actor_id]
		if actor.escaped:
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
			game.guard.facing = game.guard.position.direction_to(actor.position)
		else:
			contribution += delta / (float(game.inventory.definitions.lock_tool.duration) if action.kind == "lock_tool" else float(library.lockpick.duration))
	if contribution > 0:
		game.world.lock_progress = minf(1.0,game.world.lock_progress + contribution)
		game.world.queue_redraw()
		if game.world.lock_progress >= 1.0:
			game.world.open_door()
			for actor_id in actions.keys():
				if actions[actor_id].kind in ["lockpick", "lock_tool"]:
					cancel(actor_id)
			game.show_status("锁撬开了！伙伴和狱警都能走这条通路。")

func snapshot() -> Array:
	var result: Array = []
	for actor_id in actions:
		var action: Dictionary = actions[actor_id]
		result.append({"actor_id":actor_id,"kind":action.kind,"anchor":[action.anchor.x,action.anchor.y]})
	return result
