extends RefCounted

# Frame order is authoritative: clock/accrual, movement and AI, visibility, UI.
# Delta is never throttled; presentation caches cannot change game time.
static func tick(game, delta: float) -> void:
	game.profile_sections.clear()
	var profile_mark:=Time.get_ticks_usec()
	if game.get_tree().paused:
		return
	if game.tutorial and game.tutorial.speaking():
		if game.looting: game.looting.close()
		game.tutorial.tick(delta)
		game.presentation.tick(delta)
		game.fullscreen_ui.refresh()
		return
	if game.phase != "playing":
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
	if game.room_access:
		var fine_start_room_access:=Time.get_ticks_usec()
		game.room_access.tick()
		game.profile_sections["fine_room_access"]=(Time.get_ticks_usec()-fine_start_room_access)/1000.0
	if game.workshop:
		game.workshop.update_gate()
	var work_credit: Dictionary = game.attributes.accrue(previous_clock,game.schedule.clock_elapsed,behaviors_before) if game.attributes else {}
	for actor in game.actors:
		actor.moved_this_frame = false
	if game.routines:
		# Credit the old work state before tick replaces it at 12:00/18:00.
		game.routines.accrue_work(previous_clock, game.schedule.clock_elapsed, workers_before, work_credit)
		var fine_start_routines:=Time.get_ticks_usec()
		game.routines.tick()
		game.profile_sections["fine_routines"]=(Time.get_ticks_usec()-fine_start_routines)/1000.0
		# Opening the morning planner inside this tick must also stop the
		# remainder of this frame, before movement, game.skills and enemy AI.
		if game.get_tree().paused:
			game._update_ui()
			return
	if game.npc_life:
		var fine_start_npc_life:=Time.get_ticks_usec()
		game.npc_life.tick(delta)
		game.profile_sections["fine_npc_life"]=(Time.get_ticks_usec()-fine_start_npc_life)/1000.0
	game.profile_sections["clock_routines_npc"]=(Time.get_ticks_usec()-profile_mark)/1000.0
	profile_mark=Time.get_ticks_usec()
	game.world.begin_ai_paths()
	if game.staff_traffic:
		var fine_start_staff_traffic:=Time.get_ticks_usec()
		game.staff_traffic.update_gate()
		game.profile_sections["fine_staff_traffic"]=(Time.get_ticks_usec()-fine_start_staff_traffic)/1000.0
	if game.gate_watch:
		var fine_start_gate_watch:=Time.get_ticks_usec()
		game.gate_watch.tick(delta)
		game.profile_sections["fine_gate_watch"]=(Time.get_ticks_usec()-fine_start_gate_watch)/1000.0
	if game.mobile_controls:
		game.mobile_controls.tick(delta)
	game.profile_sections["staff_input"]=(Time.get_ticks_usec()-profile_mark)/1000.0
	profile_mark=Time.get_ticks_usec()
	game.orders.tick(delta)
	game.profile_sections["movement_orders"]=(Time.get_ticks_usec()-profile_mark)/1000.0
	profile_mark=Time.get_ticks_usec()
	game.trade.tick(delta)
	game.skills.tick(delta)
	if game.gate_watch:
		game.gate_watch.refresh_blocking()
	game.dog.tick(delta)
	game.profile_sections["skills_trade_dog"]=(Time.get_ticks_usec()-profile_mark)/1000.0
	profile_mark=Time.get_ticks_usec()
	var fine_start_guard:=Time.get_ticks_usec()
	game.guard.tick(delta)
	game.profile_sections["fine_guard"]=(Time.get_ticks_usec()-fine_start_guard)/1000.0
	if game.workshop:
		var fine_start_workshop:=Time.get_ticks_usec()
		game.workshop.tick(delta)
		game.profile_sections["fine_workshop"]=(Time.get_ticks_usec()-fine_start_workshop)/1000.0
	if game.prison_alert:
		var fine_start_prison_alert:=Time.get_ticks_usec()
		game.prison_alert.tick(delta)
		game.profile_sections["fine_prison_alert"]=(Time.get_ticks_usec()-fine_start_prison_alert)/1000.0
	game.profile_sections["guard_work_alert"]=(Time.get_ticks_usec()-profile_mark)/1000.0
	profile_mark=Time.get_ticks_usec()
	game.world.end_ai_paths()
	if game.room_visibility: game.room_visibility.tick(delta)
	if game.dialogue: game.dialogue.tick()
	if game.looting: game.looting.tick(delta)
	if game.social: game.social.tick(delta)
	if game.tutorial: game.tutorial.tick(delta)
	if game.schedule and game.phase == "playing" and game.schedule.remaining() <= 0:
		game.finish_timeout()
	game.guard_position = game.guard.position
	game.profile_sections["visibility_dialogue_loot_social"]=(Time.get_ticks_usec()-profile_mark)/1000.0
	profile_mark=Time.get_ticks_usec()
	if game.map_camera:
		game.map_camera.tick(delta)
	if game.phase == "playing" and game.elapsed >= game.status_until:
		game.status_text = "逃脱 %d / 1 · 锁门%s · 抓回 %d 次 · 看守%s" % [game.escape_count(),"已开" if game.world.door_open else "%d%%"%roundi(game.world.lock_progress*100),game.captures,"追击中" if game.guard.state == "chasing" else ("交谈中" if game.guard.state == "talking" else "巡逻中")]
	game.profile_sections["camera_status"]=(Time.get_ticks_usec()-profile_mark)/1000.0
	profile_mark=Time.get_ticks_usec()
	game._update_ui(false)
	game.profile_sections["hud_panels"]=(Time.get_ticks_usec()-profile_mark)/1000.0
	profile_mark=Time.get_ticks_usec()
	if game.presentation:
		game.presentation.tick(delta)
	if not game.perspective_floor:game.queue_redraw()

	game.profile_sections["presentation"]=(Time.get_ticks_usec()-profile_mark)/1000.0
