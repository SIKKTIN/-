extends RefCounted

# Optional map rules: timed rooms and physical confinement cells.
var game
var held: Dictionary = {}
var closing: Dictionary = {}
var timed_periods: Dictionary = {}

func _init(owner_game) -> void:
	game = owner_game
	game.world.admission_filter = movement_allowed

func reset() -> void:
	held.clear()
	closing.clear()
	timed_periods.clear()
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
			if game.world.can_place_circle(point,game.world.RADIUS,actor,true): return point
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
	game.world.escape_clock_minutes = game.schedule.clock_minutes()
	for gate in game.world.access_doors:
		if str(gate.get("kind","")) != "timed": continue
		var hours: Array = gate.get("hours",[720,840])
		var closed: bool = game.schedule.clock_minutes() < float(hours[0]) or game.schedule.clock_minutes() >= float(hours[1])
		if gate.get("card_controlled",false):
			# Occupancy is not a credential. Reset the manual choice only at
			# a schedule boundary, then retain an explicit swipe/close choice.
			var minute: float=game.schedule.clock_minutes()
			var period: Array=[game.schedule.day_number(),0 if minute<float(hours[0]) else 2 if minute>=float(hours[1]) else 1]
			var id: String=str(gate.id)
			if timed_periods.get(id,[])!=period:
				timed_periods[id]=period
				gate.erase("manual_closed")
				if closed and game.keycards.inside(game.actors[game.PLAYER_ACTOR_ID],gate):
					game.show_status(str(gate.get("name","房间"))+"已结束开放，门禁锁闭；需对应房卡刷卡开门。",4)
			closing.erase(id)
			game.world.set_access_closed(id,bool(gate.get("manual_closed",closed)))
			continue
		var room := _rect(gate.get("room_rect",[0,0,0,0]))
		var occupants: Array = game.actors.duplicate()
		occupants.append_array([game.guard,game.dog])
		if game.gate_watch: occupants.append_array(game.gate_watch.guards)
		if game.prison_alert: occupants.append_array(game.prison_alert.reinforcements)
		if game.trade: occupants.append_array(game.trade.actors.values())
		var waiting := false
		for actor in occupants:
			if actor.escaped or (actor in game.actors and actor.confined): continue
			if not room.has_point(actor.position) and not game.world.body_overlaps_door(actor,gate.rect): continue
			waiting = true
			if not closed or closing.has(str(gate.id)): continue
			var exit: Vector2 = _point(gate.get("evacuation",[1010,1100]))
			if actor in game.actors:
				if game.actor_is_controllable(actor.actor_id): continue
				if game.mobile_controls and actor.actor_id == game.selected_actor_id: game.mobile_controls.cancel_input()
				game.skills.cancel(actor.actor_id)
				game.orders.issue(actor.actor_id,exit,"room_exit")
			else:
				if actor.has_method("release_target"): actor.release_target()
				actor.path = game.world.find_path(actor.position,exit,actor,true)
		if closed and waiting:
			if not closing.has(str(gate.id)):
				game.show_status(str(gate.get("name","管制区"))+"已结束开放，请步行离场；门禁只出不进。",4)
			closing[str(gate.id)] = true
		else:
			closing.erase(str(gate.id))
		# Keep the physical passage open for occupants; admission is one-way
		# during closing. Close normally once everyone has walked outside.
		game.world.set_access_closed(str(gate.id),closed and not waiting)

	if game.keycards: game.keycards.tick()

	for actor_id in held.keys():
		var cell: Dictionary = cells()[int(held[actor_id].cell)]
		var gate: Dictionary = game.world.access_by_id(str(cell.door_id))
		if not gate.get("closed",true): release(actor_id,true)
		elif game.schedule.absolute_minutes() >= float(held[actor_id].until): release(actor_id)

func exit_goal(actor) -> Variant:
	for gate in game.world.access_doors:
		if not closing.has(str(gate.id)): continue
		var room := _rect(gate.get("room_rect",[0,0,0,0]))
		if room.has_point(actor.position) or game.world._circle_hits_rect(actor.position,game.world.RADIUS,game.world.door_collision_rect(gate.rect)):
			return _point(gate.get("evacuation",[1010,1100]))
	return null

func open_latch(actor_id: int, id: String) -> bool:
	if not game.actor_is_controllable(actor_id) or game.world_input_blocked(): return false
	var gate: Dictionary = game.world.access_by_id(id)
	if gate.get("kind","") != "latch" or not gate.get("closed",true) or not gate.has("interaction_point"): return false
	var actor = game.actors[actor_id]
	var point: Vector2 = game.world.door_interaction_point(gate)
	if actor.confined or actor.escaped or actor.position.distance_to(point) > 60 or not game.world.line_clear(actor.position,point): return false
	game.world.set_access_closed(id,false)
	for linked in gate.get("opens",[]): game.world.set_access_closed(str(linked),false)
	if game.routines: game.routines.take_control(actor_id)
	game.show_status("后勤侧门已从内侧打开，后勤出口与洗衣房捷径可通行。",5)
	return true

func dorm_gate(id: String) -> Dictionary:
	for gate in game.world.dorm_gates():
		if str(gate.get("id","")) == id and gate.get("manual_door",false): return gate
	return {}

func dorm_occupants() -> Array:
	var result: Array = game.actors.duplicate()
	result.append_array([game.guard,game.dog])
	if game.gate_watch: result.append_array(game.gate_watch.guards)
	if game.prison_alert: result.append_array(game.prison_alert.reinforcements)
	if game.trade: result.append_array(game.trade.actors.values())
	if game.resident_staff: result.append_array(game.resident_staff.actors.values())
	return result.filter(func(a):return is_instance_valid(a) and a.get("escaped")!=true)

func dorm_nearby(actor, gate: Dictionary) -> bool:
	if actor.escaped or actor.confined: return false
	var rect: Rect2 = game.world.dorm_closure_rect(gate)
	var nearest: Vector2 = actor.position.clamp(rect.position,rect.end)
	if actor.position.distance_to(nearest)>70: return false
	# Test sight to the handle's approach side, not through a closed steel leaf.
	var direction: Vector2 = (actor.position-nearest).normalized()
	return game.world.line_clear(actor.position,nearest+direction*12)

func dorm_label(id: String, known_gate: Dictionary = {}) -> String:
	var gate := dorm_gate(id) if known_gate.is_empty() else known_gate
	if gate.is_empty(): return "宿舍门"
	if gate.closed and (game.world.dorms_locked or game.schedule.is_sleep_time()): return "夜间锁定"
	return "开门" if gate.closed else "关门"

func toggle_dorm(actor_id: int, id: String) -> Dictionary:
	if game.keycards and game.keycards.gate(id).get("card_controlled",false): return game.keycards.toggle(actor_id,id)
	var gate := dorm_gate(id)
	if gate.is_empty() or not game.actor_is_controllable(actor_id) or game.world_input_blocked(): return {"ok":false,"reason":"当前不能操作宿舍门。"}
	var actor = game.actors[actor_id]
	if not dorm_nearby(actor,gate): return {"ok":false,"reason":"请靠近门把手。"}
	if gate.closed and (game.world.dorms_locked or game.schedule.is_sleep_time()): return {"ok":false,"reason":"宿舍门夜间已锁定，需要看守钥匙；白天可开门。"}
	var closing: bool = not gate.closed
	if closing and dorm_occupants().any(func(a):return preload("res://scripts/core/actor_footprint.gd").body_at(a.position).intersects(game.world.dorm_closure_rect(gate))):
		return {"ok":false,"reason":"门口有人，请等通道清空后再关门。"}
	gate.manual_closed = closing
	gate.closed = closing
	game.world._changed(true)
	game.room_visibility.doorways.tick(true)
	return {"ok":true,"reason":"宿舍门已关闭。" if closing else "宿舍门已打开。"}

func movement_allowed(actor, point: Vector2, radius: float) -> bool:
	if game.schedule == null or actor.confined: return true
	if game.keycards and not game.keycards.movement_allowed(actor,point): return false
	for gate in game.world.access_doors:
		if str(gate.get("kind","")) != "timed": continue
		var hours: Array = gate.get("hours",[720,840])
		var minute: float = game.schedule.clock_minutes()
		if minute >= float(hours[0]) and minute < float(hours[1]): continue
		if gate.get("card_controlled",false) and game.keycards and game.keycards.authorized(actor,str(gate.get("card_room",""))): continue
		var room := _rect(gate.get("room_rect",[0,0,0,0]))
		if room.has_point(actor.position) or game.world._circle_hits_rect(actor.position,radius,game.world.door_collision_rect(gate.rect)): continue
		if room.has_point(point) or game.world._circle_hits_rect(point,radius,game.world.door_collision_rect(gate.rect)): return false
	return true

func label_for(actor_id: int) -> String:
	if not held.has(actor_id): return ""
	var minutes: int = ceili(maxf(0,float(held[actor_id].until)-game.schedule.absolute_minutes()))
	return "禁闭 %02d:%02d" % [minutes/60,minutes%60]

func snapshot() -> Dictionary:
	return {"held":held.duplicate(true),"doors":game.world.access_doors.map(func(g): return {"id":g.id,"closed":g.closed,"progress":g.progress})}
