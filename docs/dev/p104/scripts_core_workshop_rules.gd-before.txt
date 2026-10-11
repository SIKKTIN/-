extends RefCounted

const Overseer = preload("res://scripts/actors/workshop_overseer.gd")
const WARNING_RECOVERY_RATE := 0.5
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
	game.staff_traffic.register(overseer,"overseer",overseer.position)
	update_gate()

func point(coords: Array) -> Vector2:
	return Vector2(coords[0],coords[1])

func current_shift() -> int:
	if config.is_empty() or game.schedule == null: return -1
	return int(game.schedule.work_window().x)

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
	if next != shift:
		shift = next
		warnings.clear()
		wanted.clear()
		grace.clear()
		admitted.clear()
		overseer.release_target()
		if shift >= 0:
			var start: float = floorf(now/1440.0)*1440.0+shift
			for actor in game.actors: grace[actor.actor_id] = start
			game.show_status("09:00车间锁门，外围警戒；请在工位劳动。" if shift == 540 else "14:00车间锁门开始劳动；请13:30出发提前到岗。",5)
		else:
			game.show_status("劳动结束，车间开门，可前往吃饭或自由活动。",4)
	for actor in game.actors:
		var id: int = actor.actor_id
		if previously_held.get(id,false) and not actor.confined:
			grace[id] = now+float(config.get("arrival_minutes",45))
		previously_held[id] = actor.confined
		if not actor.confined and area.grow(-game.world.RADIUS).has_point(actor.position): admitted[id] = true
	var gate: Dictionary = game.world.access_by_id(str(config.access_id))
	var open: bool = shift < 0
	if shift >= 0:
		# Commutes have a bounded grace period; it cannot be extended by
		# stopping/restarting a manual order or choosing an idle daily plan.
		for actor in game.actors:
			if actor.escaped or actor.confined: continue
			if now < float(grace.get(actor.actor_id,0)) and not area.grow(-game.world.RADIUS).has_point(actor.position): open = true
			# Only defer closing an already open gate around a crossing body.
			# Approaching a locked gate must never grant a prisoner access.
			if not gate.closed and game.world._circle_hits_rect(actor.position,20,game.world.door_collision_rect(gate.rect)): open = true
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
	if game.staff_traffic and game.staff_traffic.workshop_passage(): open = true
	game.world.set_access_closed(str(config.access_id),not open)

func tick(delta: float) -> void:
	if config.is_empty() or game.phase != "playing" or game.get_tree().paused: return
	update_gate()
	if game.tutorial and game.tutorial.active and not game.tutorial.supervision_enabled():
		warnings.clear()
		wanted.clear()
		overseer.tick(delta)
		return
	if not on_duty():
		overseer.tick(delta)
		return
	var observing: bool = not overseer.escaped and not game.staff_traffic.transiting(overseer) and overseer.state != "talking"
	for actor in game.actors:
		var id: int = actor.actor_id
		if actor.escaped or actor.confined or game.elapsed < actor.immune_until:
			warnings.erase(id)
			wanted.erase(id)
			continue
		if game.routines.is_working(id):
			# Only actual work cools suspicion. Starting a work order, walking
			# toward a station or briefly toggling it must not reset a warning.
			if warnings.has(id) or wanted.has(id):
				var heat: float = minf(warning_seconds(),float(warnings.get(id,warning_seconds())))
				heat = maxf(0,heat-maxf(delta,0)*WARNING_RECOVERY_RATE)
				if heat <= 0.00001:
					warnings.erase(id)
					wanted.erase(id)
				else:
					warnings[id] = heat
			continue
		if observing and outside_violation(id) and overseer.sees(actor.position): report_escape_seen(id)
		var absent := outside_violation(id)
		if commuting(id) and not absent and not warnings.has(id) and not wanted.has(id): continue
		if not warnings.has(id):
			if wanted.has(id):
				warnings[id] = warning_seconds()
			else:
				# Sight starts indoor warnings; after detection, the countdown
				# continues even behind cover or while the officer is commuting.
				if not observing or (not absent and not overseer.sees(actor.position)): continue
				warnings[id] = 0.0
				game.show_status("监工警告囚徒%d：%s！%.0f秒后追捕，持续工作可消退警戒。" % [id+1,"点名未到岗" if absent else "回工位干活",warning_seconds()],5)
		if not wanted.has(id): warnings[id] = minf(warning_seconds(),float(warnings[id])+maxf(delta,0))
		if warnings[id] >= warning_seconds()-0.00001 and not wanted.has(id):
			wanted[id] = true
			game.show_status("监工正在追捕偷懒的囚徒%d，抓到将关禁闭2小时！" % (id+1),5)
	update_gate()
	overseer.tick(delta)

func warning_seconds() -> float:
	return maxf(0.1,float(config.get("warning_seconds",3)))

func warning_level(id: int) -> float:
	return clampf(float(warnings.get(id,warning_seconds() if wanted.has(id) else 0)),0,warning_seconds())

func warning_remaining(id: int) -> float:
	return warning_seconds()-warning_level(id)

func recovery_seconds(id: int) -> float:
	return warning_level(id)/WARNING_RECOVERY_RATE

func warning_recovering(id: int) -> bool:
	return (warnings.has(id) or wanted.has(id)) and game.routines.is_working(id)

func warning_label(id: int) -> String:
	if wanted.has(id): return "监工追捕！"
	if warnings.has(id):
		return "警戒消退 · %.1f秒" % recovery_seconds(id) if warning_recovering(id) else "监工警告 · %.1f秒" % warning_remaining(id)
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
