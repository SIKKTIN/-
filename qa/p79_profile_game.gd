extends "res://scripts/core/escape_game.gd"
var profile_sections: Dictionary = {}
var benchmark_capture_disabled := false
func _make_world():return preload("res://qa/p79_profile_world.gd").new()
func capture_actor(id: int) -> void:
	if not benchmark_capture_disabled:super.capture_actor(id)

func _process(delta: float) -> void:
	var profile_start := Time.get_ticks_usec()
	var profile_mark := profile_start
	if get_tree().paused:
		return
	if phase != "playing":
		if map_camera:
			map_camera.tick(delta)
		if presentation:
			presentation.tick(delta)
		return
	delta = minf(delta,schedule.real_remaining()) if schedule else delta
	var workers_before: Array = routines.working_ids() if routines else []
	var behaviors_before: Array = attributes.behaviors() if attributes else []
	var previous_clock: float = schedule.clock_elapsed if schedule else 0.0
	if schedule:
		schedule.advance(delta)
		if schedule.time_speed > 0:
			delta = minf(delta,(schedule.clock_elapsed-previous_clock)/schedule.time_speed)
	elapsed += delta
	if room_access:
		room_access.tick()
	if workshop:
		workshop.update_gate()
	var work_credit: Dictionary = attributes.accrue(previous_clock,schedule.clock_elapsed,behaviors_before) if attributes else {}
	for actor in actors:
		actor.moved_this_frame = false
	if routines:
		# Credit the old work state before tick replaces it at 12:00/18:00.
		routines.accrue_work(previous_clock, schedule.clock_elapsed, workers_before, work_credit)
		routines.tick()
		# Opening the morning planner inside this tick must also stop the
		# remainder of this frame, before movement, skills and enemy AI.
		if get_tree().paused:
			_update_ui()
			return
	world.begin_ai_paths()
	if staff_traffic:
		staff_traffic.update_gate()
	if gate_watch:
		gate_watch.tick(delta)
	if mobile_controls:
		mobile_controls.tick(delta)
	profile_sections["routine"] = (Time.get_ticks_usec()-profile_mark)/1000.0
	profile_mark = Time.get_ticks_usec()
	orders.tick(delta)
	trade.tick(delta)
	skills.tick(delta)
	if gate_watch:
		gate_watch.tick(0)
	dog.tick(delta)
	profile_sections["before_guard"] = (Time.get_ticks_usec()-profile_mark)/1000.0
	profile_mark = Time.get_ticks_usec()
	guard.tick(delta)
	if workshop:
		workshop.tick(delta)
	if prison_alert:
		prison_alert.tick(delta)
	profile_sections["guards"] = (Time.get_ticks_usec()-profile_mark)/1000.0
	profile_mark = Time.get_ticks_usec()
	world.end_ai_paths()
	if room_visibility: room_visibility.tick(delta)
	if dialogue: dialogue.tick()
	if schedule and phase == "playing" and schedule.remaining() <= 0:
		finish_timeout()
	guard_position = guard.position
	if map_camera:
		map_camera.tick(delta)
	if phase == "playing" and elapsed >= status_until:
		status_text = "逃脱 %d / 1 · 锁门%s · 抓回 %d 次 · 看守%s" % [escape_count(),"已开" if world.door_open else "%d%%"%roundi(world.lock_progress*100),captures,"追击中" if guard.state == "chasing" else ("交谈中" if guard.state == "talking" else "巡逻中")]
	_update_ui(false)
	profile_sections["ui"] = (Time.get_ticks_usec()-profile_mark)/1000.0
	profile_mark = Time.get_ticks_usec()
	if presentation:
		presentation.tick(delta)
	profile_sections["presentation"] = (Time.get_ticks_usec()-profile_mark)/1000.0
	profile_sections["total"] = (Time.get_ticks_usec()-profile_start)/1000.0
	queue_redraw()
