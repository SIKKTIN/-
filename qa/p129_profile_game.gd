extends "res://scripts/core/escape_game.gd"
var profile_sections: Dictionary={}
func _process(delta: float) -> void:
	var bench_mark := Time.get_ticks_usec()
	profile_sections.clear()
	if self.get_tree().paused:
		return
	if self.tutorial and self.tutorial.speaking():
		if self.looting: self.looting.close()
		self.tutorial.tick(delta)
		self.presentation.tick(delta)
		self.fullscreen_ui.refresh()
		return
	if self.phase != "playing":
		if self.map_camera:
			self.map_camera.tick(delta)
		if self.presentation:
			self.presentation.tick(delta)
		return
	delta = minf(delta,self.schedule.real_remaining()) if self.schedule else delta
	var workers_before: Array = self.routines.working_ids() if self.routines else []
	var behaviors_before: Array = self.attributes.behaviors() if self.attributes else []
	var previous_clock: float = self.schedule.clock_elapsed if self.schedule else 0.0
	if self.schedule:
		if self.tutorial and self.tutorial.active: self.tutorial.advance_clock(delta)
		else: self.schedule.advance(delta)
		if self.schedule.time_speed > 0 and not (self.tutorial and self.tutorial.active):
			delta = minf(delta,(self.schedule.clock_elapsed-previous_clock)/self.schedule.time_speed)
	self.elapsed += delta
	if self.room_access:
		self.room_access.tick()
	if self.workshop:
		self.workshop.update_gate()
	var work_credit: Dictionary = self.attributes.accrue(previous_clock,self.schedule.clock_elapsed,behaviors_before) if self.attributes else {}
	for actor in self.actors:
		actor.moved_this_frame = false
	if self.routines:
		# Credit the old work state before tick replaces it at 12:00/18:00.
		self.routines.accrue_work(previous_clock, self.schedule.clock_elapsed, workers_before, work_credit)
		self.routines.tick()
		# Opening the morning planner inside this tick must also stop the
		# remainder of this frame, before movement, self.skills and enemy AI.
		if self.get_tree().paused:
			self._update_ui()
			return
	if self.npc_life: self.npc_life.tick(delta)
	profile_sections["routines"]=(Time.get_ticks_usec()-bench_mark)/1000.0
	bench_mark=Time.get_ticks_usec()
	self.world.begin_ai_paths()
	if self.staff_traffic:
		self.staff_traffic.update_gate()
	if self.gate_watch:
		self.gate_watch.tick(delta)
	if self.mobile_controls:
		self.mobile_controls.tick(delta)
	self.orders.tick(delta)
	profile_sections["input"]=(Time.get_ticks_usec()-bench_mark)/1000.0
	bench_mark=Time.get_ticks_usec()
	self.trade.tick(delta)
	self.skills.tick(delta)
	if self.gate_watch:
		self.gate_watch.refresh_blocking()
	self.dog.tick(delta)
	profile_sections["movement"]=(Time.get_ticks_usec()-bench_mark)/1000.0
	bench_mark=Time.get_ticks_usec()
	self.guard.tick(delta)
	if self.workshop:
		self.workshop.tick(delta)
	if self.prison_alert:
		self.prison_alert.tick(delta)
	self.world.end_ai_paths()
	profile_sections["guards"]=(Time.get_ticks_usec()-bench_mark)/1000.0
	bench_mark=Time.get_ticks_usec()
	if self.room_visibility: self.room_visibility.tick(delta)
	if self.dialogue: self.dialogue.tick()
	if self.looting: self.looting.tick(delta)
	if self.social: self.social.tick(delta)
	if self.tutorial: self.tutorial.tick(delta)
	if self.schedule and self.phase == "playing" and self.schedule.remaining() <= 0:
		self.finish_timeout()
	self.guard_position = self.guard.position
	profile_sections["visibility_tutorial"]=(Time.get_ticks_usec()-bench_mark)/1000.0
	bench_mark=Time.get_ticks_usec()
	if self.map_camera:
		self.map_camera.tick(delta)
	if self.phase == "playing" and self.elapsed >= self.status_until:
		self.status_text = "逃脱 %d / 1 · 锁门%s · 抓回 %d 次 · 看守%s" % [self.escape_count(),"已开" if self.world.door_open else "%d%%"%roundi(self.world.lock_progress*100),self.captures,"追击中" if self.guard.state == "chasing" else ("交谈中" if self.guard.state == "talking" else "巡逻中")]
	self._update_ui(false)
	profile_sections["camera_ui"]=(Time.get_ticks_usec()-bench_mark)/1000.0
	bench_mark=Time.get_ticks_usec()
	if self.presentation:
		self.presentation.tick(delta)
	if not self.perspective_floor:self.queue_redraw()
	profile_sections["presentation"]=(Time.get_ticks_usec()-bench_mark)/1000.0
	bench_mark=Time.get_ticks_usec()

