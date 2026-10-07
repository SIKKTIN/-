extends RefCounted

const Overseer = preload("res://scripts/actors/workshop_overseer.gd")
var game
var config: Dictionary = {}
var area := Rect2()
var overseer
var shift := -1
var grace: Dictionary = {}
var warnings: Dictionary = {}
var wanted: Dictionary = {}
var previously_held: Dictionary = {}
var admitted: Dictionary = {}

func _init(owner_game) -> void:
	game = owner_game

func reset() -> void:
	if is_instance_valid(overseer):
		for visual in overseer.get_children(): game.presentation.visuals.erase(visual)
		overseer.free()
	overseer = null
	config = game.room_config.get("workshop",{})
	shift = -1
	grace.clear()
	warnings.clear()
	wanted.clear()
	previously_held.clear()
	admitted.clear()
	if config.is_empty(): return
	if game.world.access_by_id(str(config.get("access_id",""))).is_empty():
		config = {}
		return
	var r: Array = config.room_rect
	area = Rect2(r[0],r[1],r[2],r[3])
	overseer = Overseer.new()
	game.add_child(overseer)
	overseer.configure(game.world,game)
	overseer.rules = self
	overseer.position = point(config.overseer_start)
	for coords in config.patrol: overseer.route.append(point(coords))
	game.gate_watch.attach_visual(overseer)
	overseer.escaped = not on_duty()
	update_gate()

func point(coords: Array) -> Vector2:
	return Vector2(coords[0],coords[1])

func current_shift() -> int:
	if config.is_empty() or game.schedule == null: return -1
	var minute: float = game.schedule.clock_minutes()
	for start in [480,840]:
		if minute >= start and minute < start+240: return start
	return -1

func on_duty() -> bool:
	return current_shift() >= 0

func outside_violation(id: int) -> bool:
	if not on_duty() or id < 0 or id >= game.actors.size(): return false
	var actor = game.actors[id]
	if actor.escaped or actor.confined or area.has_point(actor.position): return false
	# Admission grace only covers the initial journey to work. Walking out
	# after entering does not regain that grace, even before the deadline.
	return admitted.has(id) or game.schedule.absolute_minutes() >= float(grace.get(id,INF))

func chase_count(id: int) -> int:
	var count := 0
	var guards: Array = [game.guard]
	if game.gate_watch: guards.append_array(game.gate_watch.guards)
	if game.prison_alert: guards.append_array(game.prison_alert.reinforcements)
	if is_instance_valid(overseer): guards.append(overseer)
	for guard in guards:
		if guard.state == "chasing" and guard.target_id == id: count += 1
	return count

func report_escape_seen(id: int) -> void:
	if not outside_violation(id) or game.get_tree().paused: return
	if not wanted.has(id):
		wanted[id] = true
		game.show_status("囚徒%d劳动时间擅自外出，看守发现后立即追捕！" % (id+1),5)
	update_gate()

func commuting(id: int) -> bool:
	if game.routines.manual.has(id) or not game.routines.records.has(id): return false
	return game.routines.records[id].kind == "work" and game.schedule.absolute_minutes() < float(grace.get(id,0))

func update_gate() -> void:
	if config.is_empty() or game.phase != "playing" or game.get_tree().paused: return
	var next := current_shift()
	var now: float = game.schedule.absolute_minutes()
	var closing_morning: bool = next == 480 and next != shift
	if next != shift:
		shift = next
		warnings.clear()
		wanted.clear()
		grace.clear()
		admitted.clear()
		overseer.release_target()
		if shift >= 0:
			var start: float = floorf(now/1440.0)*1440.0+shift
			for actor in game.actors: grace[actor.actor_id] = start+(0.0 if shift == 480 else float(config.get("arrival_minutes",45)))
			game.show_status("08:00车间锁门，外围警戒；请在工位劳动。" if shift == 480 else "车间上工：先入场，入场结束锁门。离开工位会被监工查岗。",5)
		else:
			game.show_status("劳动结束，车间开门，可前往吃饭或自由活动。",4)
	for actor in game.actors:
		var id: int = actor.actor_id
		if previously_held.get(id,false) and not actor.confined:
			grace[id] = now+float(config.get("arrival_minutes",45))
		previously_held[id] = actor.confined
		if not actor.confined and area.grow(-17).has_point(actor.position): admitted[id] = true
	var gate: Dictionary = game.world.access_by_id(str(config.access_id))
	var open: bool = shift < 0
	if shift >= 0:
		# Commutes have a bounded grace period; it cannot be extended by
		# stopping/restarting a manual order or choosing an idle daily plan.
		for actor in game.actors:
			if actor.escaped or actor.confined: continue
			if now < float(grace.get(actor.actor_id,0)) and not area.grow(-17).has_point(actor.position): open = true
			# Only defer closing an already open gate around a crossing body.
			# Approaching a locked gate must never grant a prisoner access.
			if not gate.closed and game.world._circle_hits_rect(actor.position,20,gate.rect): open = true
		# The overseer opens the gate with his key to search for absentees.
		if not wanted.is_empty() and overseer.position.distance_to(gate.rect.get_center()) < 140: open = true
		elif not wanted.is_empty() and gate.closed and overseer.path.is_empty():
			var approach: Vector2 = gate.rect.get_center()+Vector2(0,-85 if area.has_point(overseer.position) else 85)
			overseer.path = game.world.find_path(overseer.position,approach,overseer,true)
		for merchant in game.trade.actors.values():
			# Staff commute through the same physical gate, never teleport.
			if not merchant.at_destination() and area.has_point(merchant.position) != area.has_point(merchant.goal):
				if merchant.position.distance_to(gate.rect.get_center()) < 140:
					open = true
				elif gate.closed and merchant.path.is_empty():
					var approach: Vector2 = gate.rect.get_center()+Vector2(0,-85 if area.has_point(merchant.position) else 85)
					merchant.path = game.world.find_path(merchant.position,approach,merchant,true)
	if closing_morning: open = false
	game.world.set_access_closed(str(config.access_id),not open)
	if closing_morning:
		# Closing on time must not trap a body inside the collision rectangle.
		# Settle only crossing occupants on their current side of the doorway.
		var occupants: Array = game.actors.duplicate()
		occupants.append_array([game.guard,overseer])
		if game.gate_watch: occupants.append_array(game.gate_watch.guards)
		if game.trade: occupants.append_array(game.trade.actors.values())
		for actor in occupants:
			if game.world._circle_hits_rect(actor.position,17,gate.rect):
				var side: float = -1.0 if actor.position.y < gate.rect.get_center().y else 1.0
				var landing := Vector2(actor.position.x,gate.rect.get_center().y+side*(gate.rect.size.y/2+18))
				actor.position = game.room_access._landing(actor,landing)

func tick(delta: float) -> void:
	if config.is_empty() or game.phase != "playing" or game.get_tree().paused: return
	update_gate()
	if not on_duty():
		overseer.escaped = not overseer.global_alert()
		if not overseer.escaped: overseer.tick(delta)
		return
	overseer.escaped = false
	for actor in game.actors:
		var id: int = actor.actor_id
		if actor.escaped or actor.confined or game.elapsed < actor.immune_until or game.routines.is_working(id):
			warnings.erase(id)
			wanted.erase(id)
			continue
		if outside_violation(id) and overseer.state != "talking" and overseer.sees(actor.position): report_escape_seen(id)
		if commuting(id) and not outside_violation(id): continue
		# The opening roll call detects absent workers; within the room,
		# slacking is only counted while actually seen by the overseer.
		var absent := outside_violation(id)
		if not absent and (overseer.state == "talking" or not overseer.sees(actor.position)): continue
		if not warnings.has(id):
			warnings[id] = 0.0
			game.show_status("监工警告囚徒%d：%s！靠近自己的工位点击“工作”。" % [id+1,"点名未到岗" if absent else "回工位干活"],5)
		warnings[id] += maxf(delta,0)
		if warnings[id] >= float(config.get("warning_seconds",8)) and not wanted.has(id):
			wanted[id] = true
			game.show_status("监工正在追捕偷懒的囚徒%d，抓到将关禁闭2小时！" % (id+1),5)
	update_gate()
	overseer.tick(delta)

func warning_label(id: int) -> String:
	if wanted.has(id): return "监工追捕！"
	if warnings.has(id): return "监工警告 · 回工位"
	return ""

func on_release(id: int) -> void:
	grace[id] = game.schedule.absolute_minutes()+float(config.get("arrival_minutes",45))
	admitted.erase(id)
	warnings.erase(id)
	wanted.erase(id)

func start_work(id: int) -> bool:
	if not game.actor_is_controllable(id) or not on_duty() or game.actors[id].confined: return false
	var goal: Vector2 = game.routines._target(id,"work")
	if game.actors[id].position.distance_to(goal) > 85 or not game.world.line_clear(game.actors[id].position,goal): return false
	game.routines.plans[id][game.routines.current_slot()] = "work"
	game.routines.resume(id)
	game.show_status("已回工位，继续工作。",3)
	return true
