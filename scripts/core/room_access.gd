extends RefCounted

# Optional map rules: timed rooms and physical confinement cells.
var game
var held: Dictionary = {}

func _init(owner_game) -> void:
	game = owner_game

func reset() -> void:
	held.clear()
	for actor in game.actors:
		actor.confined = false
		actor.confinement_rect = Rect2()

func cells() -> Array:
	return game.room_config.get("confinement",{}).get("cells",[])

func is_held(actor_id: int) -> bool:
	return held.has(actor_id)

func _point(values: Array) -> Vector2:
	return Vector2(values[0],values[1])

func _rect(values: Array) -> Rect2:
	return Rect2(values[0],values[1],values[2],values[3])

func _landing(actor, origin: Vector2) -> Vector2:
	for radius in [0,40,80,120,160]:
		for offset in [Vector2.ZERO,Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN,Vector2(-1,-1),Vector2(1,-1)]:
			var point: Vector2 = origin+offset*radius
			if game.world.can_place_circle(point,17,actor,true): return point
	return actor.position

func capture(actor_id: int) -> bool:
	if cells().size() <= actor_id: return false
	var cell: Dictionary = cells()[actor_id]
	var actor = game.actors[actor_id]
	game.world.set_access_closed(str(cell.door_id),true,true)
	actor.position = _point(cell.spawn)
	actor.confined = true
	actor.confinement_rect = _rect(cell.rect)
	held[actor_id] = {"cell":actor_id,"until":game.schedule.absolute_minutes()+float(game.room_config.confinement.get("duration_minutes",120))}
	var minutes := ceili(float(game.room_config.confinement.get("duration_minutes",120)))
	var duration: String = "%d小时" % (minutes/60) if minutes%60 == 0 else "%d分钟" % minutes
	game.show_status("囚徒%d被关进禁闭室，关押%s。" % [actor_id+1,duration],6)
	return true

func release(actor_id: int, rescued := false) -> void:
	if not held.has(actor_id): return
	var cell: Dictionary = cells()[int(held[actor_id].cell)]
	var actor = game.actors[actor_id]
	actor.confined = false
	actor.confinement_rect = Rect2()
	game.world.set_access_closed(str(cell.door_id),false)
	game.orders.stop(actor_id)
	game.skills.cancel(actor_id)
	actor.position = _landing(actor,_point(cell.release))
	actor.immune_until = game.elapsed+3.0
	held.erase(actor_id)
	if not game.actor_is_controllable(actor_id): game.routines.resume(actor_id)
	game.show_status("伙伴%d%s，已离开禁闭室。" % [actor_id+1,"获救" if rescued else "禁闭结束"],5)

func tick() -> void:
	if game.schedule == null: return
	for gate in game.world.access_doors:
		if str(gate.get("kind","")) != "timed": continue
		var hours: Array = gate.get("hours",[720,840])
		var closed: bool = game.schedule.clock_minutes() < float(hours[0]) or game.schedule.clock_minutes() >= float(hours[1])
		if closed and not bool(gate.closed):
			var room := _rect(gate.get("room_rect",[0,0,0,0]))
			for actor in game.actors:
				if actor.escaped or actor.confined: continue
				if room.has_point(actor.position) or game.world._circle_hits_rect(actor.position,17,gate.rect):
					if game.mobile_controls and actor.actor_id == game.selected_actor_id: game.mobile_controls.cancel_input()
					game.routines.take_control(actor.actor_id)
					game.orders.stop(actor.actor_id)
					game.skills.cancel(actor.actor_id)
					actor.position = _landing(actor,_point(gate.get("evacuation",[1010,1100])))
					game.show_status("14:00食堂收工，伙伴已离开，门禁关闭。",4)
			var npcs: Array = [game.guard,game.dog]
			if game.gate_watch: npcs.append_array(game.gate_watch.guards)
			if game.prison_alert: npcs.append_array(game.prison_alert.reinforcements)
			if game.trade: npcs.append_array(game.trade.actors.values())
			for npc in npcs:
				if room.has_point(npc.position) or game.world._circle_hits_rect(npc.position,17,gate.rect):
					npc.position = _landing(npc,_point(gate.get("evacuation",[1010,1100]))+Vector2(160,0))
					npc.path.clear()
					if npc.has_method("release_target"): npc.release_target()
		game.world.set_access_closed(str(gate.id),closed)
	for actor_id in held.keys():
		var cell: Dictionary = cells()[int(held[actor_id].cell)]
		var gate: Dictionary = game.world.access_by_id(str(cell.door_id))
		if not gate.get("closed",true): release(actor_id,true)
		elif game.schedule.absolute_minutes() >= float(held[actor_id].until): release(actor_id)

func label_for(actor_id: int) -> String:
	if not held.has(actor_id): return ""
	var minutes: int = ceili(maxf(0,float(held[actor_id].until)-game.schedule.absolute_minutes()))
	return "禁闭 %02d:%02d" % [minutes/60,minutes%60]

func snapshot() -> Dictionary:
	return {"held":held.duplicate(true),"doors":game.world.access_doors.map(func(g): return {"id":g.id,"closed":g.closed,"progress":g.progress})}
