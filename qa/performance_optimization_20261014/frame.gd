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
	game.profile_sections.clear()
	var audit_mark: int = Time.get_ticks_usec()
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
	game.profile_sections["clock"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	if game.room_access:
		game.room_access.tick()
	game.profile_sections["room_access"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	if game.workshop:
		game.workshop.update_gate()
	game.profile_sections["workshop_gate"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	var work_credit: Dictionary = game.attributes.accrue(previous_clock,game.schedule.clock_elapsed,behaviors_before) if game.attributes else {}
	for actor in game.actors:
		actor.moved_this_frame = false
	game.profile_sections["accrual_routines"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	game.world.begin_ai_paths()
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
	game.profile_sections["ai_begin"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	if game.npc_life: game.npc_life.tick(delta)
	game.profile_sections["npc_life"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	if game.staff_traffic:
		game.staff_traffic.update_gate()
	game.profile_sections["staff_traffic"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	if game.gate_watch:
		game.gate_watch.tick(delta)
	game.profile_sections["gate_watch"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	if game.mobile_controls:
		game.mobile_controls.tick(delta)
	game.profile_sections["mobile_input"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	game.orders.tick(delta)
	game.profile_sections["orders"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	game.trade.tick(delta)
	game.profile_sections["trade"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	if game.resident_staff: game.resident_staff.tick(delta)
	game.profile_sections["resident_staff"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	game.skills.tick(delta)
	game.profile_sections["skills"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	if game.gate_watch:
		game.gate_watch.refresh_blocking()
	game.profile_sections["gate_watch2"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	game.dog.tick(delta)
	game.profile_sections["dog"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	game.guard.tick(delta)
	game.profile_sections["guard"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	if game.workshop:
		game.workshop.tick(delta)
	game.profile_sections["workshop_gate2"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	if game.prison_alert:
		game.prison_alert.tick(delta)
	game.profile_sections["alert"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	game.world.end_ai_paths()
	game.profile_sections["ai_end"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	if game.room_visibility: game.room_visibility.tick(delta)
	game.profile_sections["visibility"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	if game.dialogue: game.dialogue.tick()
	game.profile_sections["dialogue"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	if game.looting: game.looting.tick(delta)
	game.profile_sections["loot"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	if game.bath_service: game.bath_service.tick(delta)
	game.profile_sections["bath"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	if game.social: game.social.tick(delta)
	game.profile_sections["social"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	if game.tutorial: game.tutorial.tick(delta)
	game.profile_sections["tutorial"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	if game.schedule and game.phase == "playing" and game.schedule.remaining() <= 0:
		game.finish_timeout()
	game.profile_sections["timeout"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	game.guard_position = game.guard.position
	if game.map_camera:
		game.map_camera.tick(delta)
	if game.phase == "playing" and game.elapsed >= game.status_until:
		game.status_text = "逃脱 %d / 1 · 锁门%s · 抓回 %d 次 · 看守%s" % [game.escape_count(),"已开" if game.world.door_open else "%d%%"%roundi(game.world.lock_progress*100),game.captures,"追击中" if game.guard.state == "chasing" else ("交谈中" if game.guard.state == "talking" else "巡逻中")]
	game.profile_sections["camera"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	game._update_ui(false)
	game.profile_sections["hud"]=(Time.get_ticks_usec()-audit_mark)/1000.0
	audit_mark=Time.get_ticks_usec()
	if game.presentation:
		game.presentation.tick(delta)
	if not game.perspective_floor:game.queue_redraw()

	game.profile_sections["presentation"]=(Time.get_ticks_usec()-audit_mark)/1000.0
