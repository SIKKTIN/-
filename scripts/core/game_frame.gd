extends RefCounted

# Frame order is authoritative: clock/accrual, movement and AI, visibility, UI.
# Delta is never throttled; presentation caches cannot change game time.
static func tick(game, delta: float) -> void:
	if game.get_tree().paused:
		return
	if game.tutorial and game.tutorial.speaking():
		if game.looting: game.looting.close()
		game.tutorial.tick(delta)
		game.presentation.tick(delta)
		game.fullscreen_ui.refresh()
		return
	if game.phase != "playing":
		if game.bath_service: game.bath_service.tick(0)
		if game.map_camera:
			game.map_camera.tick(delta)
		if game.presentation:
			game.presentation.tick(delta)
		return
	delta = minf(delta,game.schedule.real_remaining()) if game.schedule else delta
	var workers_before: Array = game.routines.working_ids() if game.routines else []
	var behaviors_before: Array = game.attributes.behaviors() if game.attributes else []
	var previous_clock: float = game.schedule.clock_elapsed if game.schedule else 0.0
	if game.schedule:
		if game.tutorial and game.tutorial.active: game.tutorial.advance_clock(delta)
		else: game.schedule.advance(delta)
		if game.schedule.time_speed > 0 and not (game.tutorial and game.tutorial.active):
			delta = minf(delta,(game.schedule.clock_elapsed-previous_clock)/game.schedule.time_speed)
	game.elapsed += delta
	# All officers share one key/occupant snapshot before anyone moves.
	# Individual guard ticks must not recompute every dorm doorway.
	if game.schedule:
		game.world.update_dorm_doors(game.schedule.is_sleep_time(),game.inspection_positions(),game.room_access.dorm_occupants() if game.room_access else [])
	# Admission, evacuations and routine routes share the same frame budget.
	game.world.begin_ai_paths()
	if game.room_access:
		game.room_access.tick()
	if game.workshop:
		game.workshop.update_gate()
	var work_credit: Dictionary = game.attributes.accrue(previous_clock,game.schedule.clock_elapsed,behaviors_before) if game.attributes else {}
	for actor in game.actors:
		actor.moved_this_frame = false
	if game.routines:
		# Credit the old work state before tick replaces it at 12:00/18:00.
		game.routines.accrue_work(previous_clock, game.schedule.clock_elapsed, workers_before, work_credit)
		game.routines.tick()
		# Opening the morning planner inside this tick must also stop the
		# remainder of this frame, before movement, game.skills and enemy AI.
		if game.get_tree().paused:
			game.world.end_ai_paths()
			game._update_ui()
			return
	if game.npc_life: game.npc_life.tick(delta)
	if game.staff_traffic:
		game.staff_traffic.update_gate()
	if game.gate_watch:
		game.gate_watch.tick(delta)
	if game.mobile_controls:
		game.mobile_controls.tick(delta)
	game.orders.tick(delta)
	game.trade.tick(delta)
	if game.resident_staff: game.resident_staff.tick(delta)
	game.skills.tick(delta)
	if game.gate_watch:
		game.gate_watch.refresh_blocking()
	game.dog.tick(delta)
	game.guard.tick(delta)
	if game.workshop:
		game.workshop.tick(delta)
	if game.prison_alert:
		game.prison_alert.tick(delta)
	game.world.end_ai_paths()
	if game.room_visibility: game.room_visibility.tick(delta)
	if game.dialogue: game.dialogue.tick()
	if game.looting: game.looting.tick(delta)
	if game.bath_service: game.bath_service.tick(delta)
	if game.social: game.social.tick(delta)
	if game.tutorial: game.tutorial.tick(delta)
	if game.schedule and game.phase == "playing" and game.schedule.remaining() <= 0:
		game.finish_timeout()
	game.guard_position = game.guard.position
	if game.map_camera:
		game.map_camera.tick(delta)
	if game.phase == "playing" and game.elapsed >= game.status_until:
		game.status_text = "逃脱 %d / 1 · 锁门%s · 抓回 %d 次 · 看守%s" % [game.escape_count(),"已开" if game.world.door_open else "%d%%"%roundi(game.world.lock_progress*100),game.captures,"追击中" if game.guard.state == "chasing" else ("交谈中" if game.guard.state == "talking" else "巡逻中")]
	game._update_ui(false)
	if game.presentation:
		game.presentation.tick(delta)
	if not game.perspective_floor:game.queue_redraw()

