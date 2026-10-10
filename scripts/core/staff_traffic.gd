extends RefCounted

# Staff have persistent identities. Only initial scene setup places them;
# every subsequent arrival, departure and recall moves through real gates.
var game
var records: Dictionary = {}
var temporary_gate := false

func _init(owner_game) -> void:
	game = owner_game

func reset() -> void:
	records.clear()
	temporary_gate = false

func register(actor, role: String, home: Vector2, offsite := false) -> void:
	records[actor.get_instance_id()] = {"actor":actor,"role":role,"home":home,"status":"offsite" if offsite else "duty","legs":[],"retry":0.0}
	if offsite:
		actor.position = exterior()
		actor.escaped = true
		actor.hide()

func exterior() -> Vector2:
	return Vector2(game.world.bounds.end.x+80,game.world.door.get_center().y)

func exterior_allowed(point: Vector2, radius: float) -> bool:
	var bounds: Rect2 = game.world.bounds
	var door: Rect2 = game.world.door
	return point.x >= bounds.end.x-radius and point.x <= bounds.end.x+100 and point.y >= door.position.y+radius and point.y <= door.end.y-radius

func transiting(actor) -> bool:
	var record: Dictionary = records.get(actor.get_instance_id(),{})
	return not record.is_empty() and record.status in ["entering","leaving"]

func wanted(record: Dictionary) -> bool:
	if game.prison_alert and game.prison_alert.active: return true
	var minute: float = game.schedule.clock_minutes()
	match record.role:
		"reinforcement": return false
		"overseer": return (minute >= game.schedule.stage_minute("morning_work")-60 and minute < game.schedule.stage_minute("meal_rest")) or (minute >= game.schedule.stage_minute("afternoon_work")-60 and minute < game.schedule.stage_minute("free_time"))
		_: return minute >= game.schedule.wake_minutes()-20 and minute < 1200

func label(actor) -> String:
	var record: Dictionary = records.get(actor.get_instance_id(),{})
	if record.is_empty(): return ""
	if record.status == "entering": return "增援入场" if record.role == "reinforcement" else "前往岗位"
	if record.status == "leaving": return "撤离 · 前往正门" if record.role == "reinforcement" else "离岗 · 前往正门"
	return ""

func _begin(record: Dictionary, incoming: bool) -> void:
	var actor = record.actor
	if actor.chat_partner_id >= 0 and actor.state == "talking":
		game.cancel_guard_chat("看守交接班，结束交谈并步行离开。")
		actor.stop_chat()
	actor.release_target()
	actor.path.clear()
	actor.returning_from_inspection = false
	record.status = "entering" if incoming else "leaving"
	record.retry = 0.0
	var door: Rect2 = game.world.door
	var inner := door.get_center()-Vector2(90,0)
	var outer := door.get_center()+Vector2(90,0)
	var legs: Array = []
	# A recall can reverse an officer midway without repositioning them.
	if incoming:
		if actor.position.x > door.end.x:
			legs.append(outer)
			legs.append(inner)
		if record.role == "overseer" and game.workshop and not game.workshop.area.has_point(actor.position):
			var gate: Dictionary = game.world.access_by_id(str(game.workshop.config.access_id))
			legs.append(gate.rect.get_center()+Vector2(0,85))
			legs.append(gate.rect.get_center()-Vector2(0,85))
		legs.append(record.home)
	else:
		if game.workshop and not game.workshop.config.is_empty() and game.workshop.area.has_point(actor.position):
			var gate: Dictionary = game.world.access_by_id(str(game.workshop.config.access_id))
			legs.append(gate.rect.get_center()-Vector2(0,85))
			legs.append(gate.rect.get_center()+Vector2(0,85))
		if actor.position.x <= door.end.x:
			legs.append(inner)
			legs.append(outer)
		legs.append(exterior())
	record.legs = legs

func workshop_passage() -> bool:
	if game.workshop == null or game.workshop.config.is_empty(): return false
	var gate: Dictionary = game.world.access_by_id(str(game.workshop.config.access_id))
	for record in records.values():
		if record.status not in ["entering","leaving"] or record.legs.is_empty(): continue
		if record.actor.position.distance_to(gate.rect.get_center()) < 150 and record.legs[0].distance_to(gate.rect.get_center()) < 100: return true
	return false

func factory_passage() -> bool:
	for record in records.values():
		if record.status not in ["entering","leaving"] or record.legs.is_empty(): continue
		if record.actor.position.distance_to(game.world.door.get_center()) < 155 and absf(record.legs[0].x-game.world.door.get_center().x) <= 100: return true
	return false

func update_gate() -> void:
	if game.phase != "playing" or game.get_tree().paused: return
	var passing := factory_passage()
	var permanent: bool = game.world.lock_progress >= 1
	if passing and not game.world.door_open:
		temporary_gate = true
		game.world.door_open = true
		game.world._changed(true)
	elif temporary_gate and not passing:
		# Defer closure around any body. Never undo a player's unlocked door.
		var bodies: Array = game.actors.duplicate()
		for record in records.values():
			if not record.actor.escaped: bodies.append(record.actor)
		if bodies.any(func(actor): return game.world._circle_hits_rect(actor.position,20,game.world.door)): return
		temporary_gate = false
		if not permanent:
			game.world.door_open = false
			game.world._changed(true)
	if game.gate_watch: game.world.set_gate_guarded(game.gate_watch.blocking())

func tick_guard(actor, delta: float) -> bool:
	var record: Dictionary = records.get(actor.get_instance_id(),{})
	if record.is_empty(): return false
	if game.phase != "playing" or game.get_tree().paused: return true
	var needed := wanted(record)
	if needed and record.status in ["offsite","leaving"]: _begin(record,true)
	elif not needed and record.status in ["duty","entering"]: _begin(record,false)
	if record.status == "offsite": return true
	if record.status == "duty": return false
	actor.moved_this_frame = false
	if actor.state == "talking": return true
	# Staff inside the factory still enforce labor rules while commuting.
	if needed and actor.position.x < game.world.door.position.x and game.workshop:
		for prisoner in game.actors:
			if actor.pursuit_allowed(prisoner) and actor.sees(prisoner.position):
				game.workshop.report_escape_seen(prisoner.actor_id)
				record.status = "duty"
				actor.escaped = false
				actor.show()
				return false
	update_gate()
	if game.workshop: game.workshop.update_gate()
	record.retry -= delta
	if not record.legs.is_empty():
		var goal: Vector2 = record.legs[0]
		if record.retry <= 0 and (actor.path.is_empty() or actor.path_revision != game.world.obstacle_revision):
			actor.path = game.world.find_path(actor.position,goal,actor,true)
			if not actor.path_deferred:
				actor.path_revision = game.world.obstacle_revision
				record.retry = 0.35
		var budget := 215.0*maxf(delta,0)
		# Ignore subpixel budget residue. Treating float rounding as a stall
		# would throw away a valid path and wait for the retry on every frame.
		while not actor.path.is_empty() and budget > 0.02:
			var offset: Vector2 = actor.path[0]-actor.position
			if offset.length() < 0.5:
				actor.path.remove_at(0)
				continue
			actor.facing = offset.normalized()
			var moved: Vector2 = game.world.move_actor(actor,actor.facing*minf(budget,offset.length()))
			actor.moved_this_frame = actor.moved_this_frame or moved.length_squared() > 0.001
			budget -= moved.length()
			if moved.length() < 0.001:
				actor.path.clear()
				break
		if actor.position.distance_to(goal) < 2:
			record.legs.pop_front()
			actor.path.clear()
			record.retry = 0.0
	# Crossing the world boundary controls presence, independently of duty.
	actor.escaped = actor.position.x > game.world.bounds.end.x+20
	actor.visible = not actor.escaped
	if record.legs.is_empty():
		record.status = "duty" if needed else "offsite"
		actor.release_target()
		if not needed:
			actor.escaped = true
			actor.hide()
	update_gate()
	return true
