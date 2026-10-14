extends RefCounted

# Frame order is authoritative: clock/accrual, movement and AI, visibility, UI.
# Delta is never throttled; presentation caches cannot change game time.
static func tick(game, delta: float) -> void:
	var qa_stamp: int=Time.get_ticks_usec()
	game.profile_sections.clear()
	if game.get_tree().paused:
		return
	game.profile_sections["if game.get_tree().paused:"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if game.tutorial and game.tutorial.speaking():
		if game.looting: game.looting.close()
		game.tutorial.tick(delta)
		game.presentation.tick(delta)
		game.fullscreen_ui.refresh()
		return
	game.profile_sections["if game.tutorial and game.tutorial.speaking():"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if game.phase != "playing":
		if game.bath_service: game.bath_service.tick(0)
		if game.map_camera:
			game.map_camera.tick(delta)
		if game.presentation:
			game.presentation.tick(delta)
		return
	game.profile_sections["if game.phase != \"playing\":"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	delta = minf(delta,game.schedule.real_remaining()) if game.schedule else delta
	game.profile_sections["delta = minf(delta,game.schedule.real_remaining()) if game.schedule else delta"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	var workers_before: Array = game.routines.working_ids() if game.routines else []
	game.profile_sections["var workers_before: Array = game.routines.working_ids() if game.routines else []"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	var behaviors_before: Array = game.attributes.behaviors() if game.attributes else []
	game.profile_sections["var behaviors_before: Array = game.attributes.behaviors() if game.attributes else []"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	var previous_clock: float = game.schedule.clock_elapsed if game.schedule else 0.0
	game.profile_sections["var previous_clock: float = game.schedule.clock_elapsed if game.schedule else 0.0"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if game.schedule:
		if game.tutorial and game.tutorial.active: game.tutorial.advance_clock(delta)
		else: game.schedule.advance(delta)
		if game.schedule.time_speed > 0 and not (game.tutorial and game.tutorial.active):
			delta = minf(delta,(game.schedule.clock_elapsed-previous_clock)/game.schedule.time_speed)
	game.profile_sections["if game.schedule:"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	game.elapsed += delta
	# All officers share one key/occupant snapshot before anyone moves.
	# Individual guard ticks must not recompute every dorm doorway.
	game.profile_sections["game.elapsed += delta"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if game.schedule:
		game.world.update_dorm_doors(game.schedule.is_sleep_time(),game.inspection_positions(),game.room_access.dorm_occupants() if game.room_access else [])
	# Admission, evacuations and routine routes share the same frame budget.
	game.profile_sections["if game.schedule:"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	game.world.begin_ai_paths()
	game.profile_sections["game.world.begin_ai_paths()"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if game.room_access:
		game.room_access.tick()
	game.profile_sections["if game.room_access:"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if game.workshop:
		game.workshop.update_gate()
	game.profile_sections["if game.workshop:"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	var work_credit: Dictionary = game.attributes.accrue(previous_clock,game.schedule.clock_elapsed,behaviors_before) if game.attributes else {}
	game.profile_sections["var work_credit: Dictionary = game.attributes.accrue(previous_clock,game.schedule.clock_elapsed,behaviors_befo"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	for actor in game.actors:
		actor.moved_this_frame = false
	game.profile_sections["for actor in game.actors:"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
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
	game.profile_sections["if game.routines:"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if game.npc_life: game.npc_life.tick(delta)
	game.profile_sections["if game.npc_life: game.npc_life.tick(delta)"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if game.staff_traffic:
		game.staff_traffic.update_gate()
	game.profile_sections["if game.staff_traffic:"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if game.gate_watch:
		game.gate_watch.tick(delta)
	game.profile_sections["if game.gate_watch:"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if game.mobile_controls:
		game.mobile_controls.tick(delta)
	game.profile_sections["if game.mobile_controls:"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	game.orders.tick(delta)
	game.profile_sections["game.orders.tick(delta)"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	game.trade.tick(delta)
	game.profile_sections["game.trade.tick(delta)"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if game.resident_staff: game.resident_staff.tick(delta)
	game.profile_sections["if game.resident_staff: game.resident_staff.tick(delta)"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	game.skills.tick(delta)
	game.profile_sections["game.skills.tick(delta)"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if game.gate_watch:
		game.gate_watch.refresh_blocking()
	game.profile_sections["if game.gate_watch:"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	game.dog.tick(delta)
	game.profile_sections["game.dog.tick(delta)"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	game.guard.tick(delta)
	game.profile_sections["game.guard.tick(delta)"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if game.workshop:
		game.workshop.tick(delta)
	game.profile_sections["if game.workshop:"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if game.prison_alert:
		game.prison_alert.tick(delta)
	game.profile_sections["if game.prison_alert:"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	game.world.end_ai_paths()
	game.profile_sections["game.world.end_ai_paths()"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if game.room_visibility: game.room_visibility.tick(delta)
	game.profile_sections["if game.room_visibility: game.room_visibility.tick(delta)"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if game.dialogue: game.dialogue.tick()
	game.profile_sections["if game.dialogue: game.dialogue.tick()"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if game.looting: game.looting.tick(delta)
	game.profile_sections["if game.looting: game.looting.tick(delta)"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if game.bath_service: game.bath_service.tick(delta)
	game.profile_sections["if game.bath_service: game.bath_service.tick(delta)"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if game.social: game.social.tick(delta)
	game.profile_sections["if game.social: game.social.tick(delta)"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if game.tutorial: game.tutorial.tick(delta)
	game.profile_sections["if game.tutorial: game.tutorial.tick(delta)"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if game.schedule and game.phase == "playing" and game.schedule.remaining() <= 0:
		game.finish_timeout()
	game.profile_sections["if game.schedule and game.phase == \"playing\" and game.schedule.remaining() <= 0:"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	game.guard_position = game.guard.position
	game.profile_sections["game.guard_position = game.guard.position"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if game.map_camera:
		game.map_camera.tick(delta)
	game.profile_sections["if game.map_camera:"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if game.phase == "playing" and game.elapsed >= game.status_until:
		game.status_text = "逃脱 %d / 1 · 锁门%s · 抓回 %d 次 · 看守%s" % [game.escape_count(),"已开" if game.world.door_open else "%d%%"%roundi(game.world.lock_progress*100),game.captures,"追击中" if game.guard.state == "chasing" else ("交谈中" if game.guard.state == "talking" else "巡逻中")]
	game.profile_sections["if game.phase == \"playing\" and game.elapsed >= game.status_until:"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	game._update_ui(false)
	game.profile_sections["game._update_ui(false)"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if game.presentation:
		game.presentation.tick(delta)
	game.profile_sections["if game.presentation:"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
	qa_stamp=Time.get_ticks_usec()
	if not game.perspective_floor:game.queue_redraw()

	game.profile_sections["if not game.perspective_floor:game.queue_redraw()"]=(Time.get_ticks_usec()-qa_stamp)/1000.0
