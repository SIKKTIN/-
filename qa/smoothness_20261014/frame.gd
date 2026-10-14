extends RefCounted

# Frame order is authoritative: clock/accrual, movement and AI, visibility, UI.
# QA-only instrumentation generated from the current production frame.
# Delta is never throttled; presentation caches cannot change game time.
static func tick(game, delta: float) -> void:
	if game.get_tree().paused:
		return
	if game.tutorial and game.tutorial.speaking():
		if game.looting: game.looting.close()
		game.tutorial.tick(delta)
		var audit_mark_presentation_tick: int = Time.get_ticks_usec()
		game.presentation.tick(delta)
		game.profile_sections["presentation.tick"] = (Time.get_ticks_usec()-audit_mark_presentation_tick)/1000.0
		game.fullscreen_ui.refresh()
		return
	if game.phase != "playing":
		if game.bath_service: game.bath_service.tick(0)
		if game.map_camera:
			game.map_camera.tick(delta)
		if game.presentation:
			var audit_mark_presentation_tick: int = Time.get_ticks_usec()
			game.presentation.tick(delta)
			game.profile_sections["presentation.tick"] = (Time.get_ticks_usec()-audit_mark_presentation_tick)/1000.0
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
		var audit_mark_world_update_dorm_doors: int = Time.get_ticks_usec()
		game.world.update_dorm_doors(game.schedule.is_sleep_time(),game.inspection_positions(),game.room_access.dorm_occupants() if game.room_access else [])
		game.profile_sections["world.update_dorm_doors"] = (Time.get_ticks_usec()-audit_mark_world_update_dorm_doors)/1000.0
	if game.room_access:
		var audit_mark_room_access_tick: int = Time.get_ticks_usec()
		game.room_access.tick()
		game.profile_sections["room_access.tick"] = (Time.get_ticks_usec()-audit_mark_room_access_tick)/1000.0
	if game.workshop:
		var audit_mark_workshop_update_gate: int = Time.get_ticks_usec()
		game.workshop.update_gate()
		game.profile_sections["workshop.update_gate"] = (Time.get_ticks_usec()-audit_mark_workshop_update_gate)/1000.0
	var work_credit: Dictionary = game.attributes.accrue(previous_clock,game.schedule.clock_elapsed,behaviors_before) if game.attributes else {}
	for actor in game.actors:
		actor.moved_this_frame = false
	game.world.begin_ai_paths()
	if game.routines:
		# Credit the old work state before tick replaces it at 12:00/18:00.
		game.routines.accrue_work(previous_clock, game.schedule.clock_elapsed, workers_before, work_credit)
		var audit_mark_routines_tick: int = Time.get_ticks_usec()
		game.routines.tick()
		game.profile_sections["routines.tick"] = (Time.get_ticks_usec()-audit_mark_routines_tick)/1000.0
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
		var audit_mark_gate_watch_tick: int = Time.get_ticks_usec()
		game.gate_watch.tick(delta)
		game.profile_sections["gate_watch.tick"] = (Time.get_ticks_usec()-audit_mark_gate_watch_tick)/1000.0
	if game.mobile_controls:
		game.mobile_controls.tick(delta)
	var audit_mark_orders_tick: int = Time.get_ticks_usec()
	game.orders.tick(delta)
	game.profile_sections["orders.tick"] = (Time.get_ticks_usec()-audit_mark_orders_tick)/1000.0
	game.trade.tick(delta)
	if game.resident_staff: game.resident_staff.tick(delta)
	game.skills.tick(delta)
	if game.gate_watch:
		game.gate_watch.refresh_blocking()
	var audit_mark_dog_tick: int = Time.get_ticks_usec()
	game.dog.tick(delta)
	game.profile_sections["dog.tick"] = (Time.get_ticks_usec()-audit_mark_dog_tick)/1000.0
	var audit_mark_guard_tick: int = Time.get_ticks_usec()
	game.guard.tick(delta)
	game.profile_sections["guard.tick"] = (Time.get_ticks_usec()-audit_mark_guard_tick)/1000.0
	if game.workshop:
		var audit_mark_workshop_tick: int = Time.get_ticks_usec()
		game.workshop.tick(delta)
		game.profile_sections["workshop.tick"] = (Time.get_ticks_usec()-audit_mark_workshop_tick)/1000.0
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
		var audit_mark_presentation_tick: int = Time.get_ticks_usec()
		game.presentation.tick(delta)
		game.profile_sections["presentation.tick"] = (Time.get_ticks_usec()-audit_mark_presentation_tick)/1000.0
	if not game.perspective_floor:game.queue_redraw()

