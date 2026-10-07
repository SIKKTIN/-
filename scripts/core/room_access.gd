extends RefCounted

# Optional map rules: timed rooms and physical confinement cells.
var game
var held: Dictionary = {}
var closing: Dictionary = {}

func _init(owner_game) -> void:
	game = owner_game
	game.world.admission_filter = movement_allowed

func reset() -> void:
	held.clear()
	closing.clear()
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
	if game.workshop: game.workshop.on_release(actor_id)
	if not game.actor_is_controllable(actor_id): game.routines.resume(actor_id)
	game.show_status("伙伴%d%s，已离开禁闭室。" % [actor_id+1,"获救" if rescued else "禁闭结束"],5)

func tick() -> void:
	if game.schedule == null: return
	for gate in game.world.access_doors:
		if str(gate.get("kind","")) != "timed": continue
		var hours: Array = gate.get("hours",[720,840])
		var closed: bool = game.schedule.clock_minutes() < float(hours[0]) or game.schedule.clock_minutes() >= float(hours[1])
		var room := _rect(gate.get("room_rect",[0,0,0,0]))
		var occupants: Array = game.actors.duplicate()
		occupants.append_array([game.guard,game.dog])
		if game.gate_watch: occupants.append_array(game.gate_watch.guards)
		if game.prison_alert: occupants.append_array(game.prison_alert.reinforcements)
		if game.trade: occupants.append_array(game.trade.actors.values())
		var waiting := false
		for actor in occupants:
			if actor.escaped or (actor in game.actors and actor.confined): continue
			if not room.has_point(actor.position) and not game.world._circle_hits_rect(actor.position,17,gate.rect): continue
			waiting = true
			if not closed or closing.has(str(gate.id)): continue
			var exit: Vector2 = _point(gate.get("evacuation",[1010,1100]))
			if actor in game.actors:
				if game.mobile_controls and actor.actor_id == game.selected_actor_id: game.mobile_controls.cancel_input()
				game.skills.cancel(actor.actor_id)
				game.orders.issue(actor.actor_id,exit,"room_exit")
			else:
				if actor.has_method("release_target"): actor.release_target()
				actor.path = game.world.find_path(actor.position,exit,actor,true)
		if closed and waiting:
			if not closing.has(str(gate.id)):
				game.show_status("14:00食堂收工，请步行离场；门禁只出不进。",4)
			closing[str(gate.id)] = true
		else:
			closing.erase(str(gate.id))
		# Keep the physical passage open for occupants; admission is one-way
		# during closing. Close normally once everyone has walked outside.
		game.world.set_access_closed(str(gate.id),closed and not waiting)

	for actor_id in held.keys():
		var cell: Dictionary = cells()[int(held[actor_id].cell)]
		var gate: Dictionary = game.world.access_by_id(str(cell.door_id))
		if not gate.get("closed",true): release(actor_id,true)
		elif game.schedule.absolute_minutes() >= float(held[actor_id].until): release(actor_id)

func exit_goal(actor) -> Variant:
	for gate in game.world.access_doors:
		if not closing.has(str(gate.id)): continue
		var room := _rect(gate.get("room_rect",[0,0,0,0]))
		if room.has_point(actor.position) or game.world._circle_hits_rect(actor.position,17,gate.rect):
			return _point(gate.get("evacuation",[1010,1100]))
	return null

func movement_allowed(actor, point: Vector2, radius: float) -> bool:
	if game.schedule == null or actor.confined: return true
	for gate in game.world.access_doors:
		if str(gate.get("kind","")) != "timed": continue
		var hours: Array = gate.get("hours",[720,840])
		var minute: float = game.schedule.clock_minutes()
		if minute >= float(hours[0]) and minute < float(hours[1]): continue
		var room := _rect(gate.get("room_rect",[0,0,0,0]))
		if room.has_point(actor.position) or game.world._circle_hits_rect(actor.position,radius,gate.rect): continue
		if room.has_point(point) or game.world._circle_hits_rect(point,radius,gate.rect): return false
	return true

func label_for(actor_id: int) -> String:
	if not held.has(actor_id): return ""
	var minutes: int = ceili(maxf(0,float(held[actor_id].until)-game.schedule.absolute_minutes()))
	return "禁闭 %02d:%02d" % [minutes/60,minutes%60]

func snapshot() -> Dictionary:
	return {"held":held.duplicate(true),"doors":game.world.access_doors.map(func(g): return {"id":g.id,"closed":g.closed,"progress":g.progress})}
