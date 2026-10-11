extends Node

class TargetMarker extends Node2D:
	func _draw():
		draw_arc(Vector2.ZERO,22,0,TAU,32,Color("cfac65"),3,true)
		draw_line(Vector2(0,-42),Vector2(0,-28),Color("f2ebdd"),3,true)
		draw_line(Vector2(0,-28),Vector2(-6,-34),Color("f2ebdd"),3,true)
		draw_line(Vector2(0,-28),Vector2(6,-34),Color("f2ebdd"),3,true)

var game
var active := false
var completed := false
var step_id := ""
var steps := {}
var events: Array = []
var panel: Panel
var title: Label
var speaker: Label
var body: Label
var note: Label
var primary: Button
var skip_button: Button
var marker: TargetMarker
var age := 0.0
var work_seconds := 0.0
var wage_baseline := 0
var warning_seen := false
var chat_seen := false
var demonstration_captures := 0
var guide_goal := Vector2.ZERO
var guide_legs: Array[Vector2] = []
var guide_retry := 0.0
var monitor_goal := Vector2.ZERO
var cell_opened := false
var cell_closed := false
var text_revealed := 0.0
var capture_pending := false
var caught_message_until := 0.0
var transition := false
var transition_age := 0.0
var transition_reset := false
var transition_cover: ColorRect
var speech
var dialogue_ready := false
var lines: Array = []
var line_index := 0
var rendezvous := Vector2.ZERO
var rendezvous_retry := 0.0
var conversations: Array = []
var rendezvous_choice := 0

func configure(owner_game):
	game = owner_game
	process_mode = Node.PROCESS_MODE_ALWAYS
	for step in JSON.parse_string(FileAccess.get_file_as_string("res://data/tutorial_day.json")).steps:
		steps[str(step.id)] = step
	_make_ui()
	speech = preload("res://scripts/ui/tutorial_speech.gd").new()
	game.get_node("HUD").add_child(speech)
	speech.configure(self)
	marker = TargetMarker.new()
	marker.name = "TutorialDestination"
	marker.hide()
	game.add_child(marker)
	if eligible(): begin()

func eligible() -> bool:
	return game.room_id == "r04" and not game.editor_preview_mode and OS.get_environment("ESCAPE_TUTORIAL_MODE") != "off"

func _make_ui():
	panel = Panel.new()
	panel.name = "IntakeDay"
	panel.z_index = 150
	panel.theme = game.fullscreen_ui.theme
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f2ebdd")
	style.border_color = Color("7b8877")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel",style)
	game.get_node("HUD").add_child(panel)
	for size in [20,14,16,12]:
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font",game.presentation.font)
		label.add_theme_font_size_override("font_size",size)
		label.add_theme_color_override("font_color",Color("303b46"))
		panel.add_child(label)
		match size:
			20: title = label
			14: speaker = label
			16: body = label
			12: note = label
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	primary = Button.new()
	primary.focus_mode = Control.FOCUS_NONE
	primary.pressed.connect(continue_lesson)
	panel.add_child(primary)
	skip_button = Button.new()
	skip_button.text = "跳过教程"
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.pressed.connect(finish)
	panel.add_child(skip_button)
	panel.hide()
	transition_cover = ColorRect.new()
	transition_cover.name = "TutorialOvernight"
	transition_cover.color = Color("202923")
	transition_cover.z_index = 300
	transition_cover.hide()
	var morning := Label.new()
	morning.text = "入监日结束\n第2天 · 07:20"
	morning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	morning.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	morning.add_theme_font_size_override("font_size",28)
	morning.add_theme_color_override("font_color",Color("f2ebdd"))
	transition_cover.add_child(morning)
	game.get_node("HUD").add_child(transition_cover)

func layout():
	var safe: Rect2 = game.fullscreen_ui.safe_area()
	var left: float = game.mobile_controls.pad.position.x+game.mobile_controls.pad.size.x+8
	var right: float = game.fullscreen_ui.action_button.position.x-12
	var width := minf(650,maxf(400,right-left))
	panel.size = Vector2(width,164)
	panel.position = Vector2(clampf(safe.get_center().x-width/2,left,maxf(left,right-width)),safe.end.y-panel.size.y-8)
	title.position = Vector2(16,10)
	title.size = Vector2(panel.size.x-32,29)
	speaker.hide()
	body.position = Vector2(16,43)
	body.size = Vector2(panel.size.x-32,42)
	note.position = Vector2(16,88)
	note.size = Vector2(panel.size.x-32,20)
	primary.position = Vector2(16,112)
	primary.size = Vector2(panel.size.x-156,32)
	skip_button.position = Vector2(panel.size.x-126,112)
	skip_button.size = Vector2(110,32)

func cancel():
	active = false
	panel.hide()
	marker.hide()
	if speech: speech.hide()
	game.guard.path.clear()
	if is_instance_valid(game.workshop.overseer): game.workshop.overseer.path.clear()

func on_round_reset():
	if eligible() and not completed: begin()
	elif completed and eligible():
		game.schedule.calendar_day_offset = 1
		game.schedule.tick(false)

func begin():
	active = true
	completed = false
	events.clear()
	conversations.clear()
	demonstration_captures = 0
	warning_seen = false
	chat_seen = false
	capture_pending = false
	caught_message_until = 0
	monitor_goal = Vector2.ZERO
	game.fullscreen_ui.close_menu()
	game.routine_panel.close()
	game.schedule.close()
	game.dialogue.close()
	game.routines.morning_pending = false
	game.routines.take_control(0)
	game.orders.stop(0)
	game.skills.cancel(0)
	game.schedule.time_speed = 1
	game.schedule.calendar_day_offset = 0
	_enter("welcome")

func replay():
	completed = false
	game.reset_round()

func finish():
	if not active or transition: return
	transition = true
	transition_age = 0
	transition_reset = false
	transition_cover.size = game.get_viewport_rect().size
	transition_cover.get_child(0).size = transition_cover.size
	transition_cover.modulate.a = 0
	transition_cover.show()
	game.mobile_controls.cancel_input()
	game.orders.stop(0)

func _process(delta: float):
	if not transition: return
	transition_age += maxf(delta,0)
	if transition_age < 0.4:
		transition_cover.modulate.a = transition_age/0.4
	elif not transition_reset:
		transition_cover.modulate.a = 1
		transition_reset = true
		completed = true
		cancel()
		game.reset_round()
		game.show_status("入监日结束：第2天07:20，正式三天逃脱期限开始。",6)
	else:
		transition_cover.modulate.a = maxf(0,1-(transition_age-0.4)/0.6)
		if transition_age >= 1:
			transition = false
			transition_cover.hide()

func step() -> Dictionary:
	return steps.get(step_id,{})

func blocks_input() -> bool:
	return transition or (active and step().get("kind","") in ["brief","cinematic"])

func speaking() -> bool:
	return transition or (active and step().get("kind","") == "brief" and dialogue_ready)

func presenter():
	match str(step().get("presenter","instructor")):
		"overseer": return game.workshop.overseer
		"merchant": return game.trade.actors.values()[0] if not game.trade.actors.is_empty() else game.guard
	return game.guard

func presenter_name() -> String:
	match str(step().get("presenter","instructor")):
		"overseer": return "监工 · 老周"
		"merchant": return "商人"
	return "陈教官"

func current_line() -> String:
	return str(lines[line_index]) if not lines.is_empty() else ""

func _conversation_ready() -> bool:
	var actor = presenter()
	if not is_instance_valid(actor): return false
	var player = game.actors[0]
	if step_id in ["work_brief","afternoon_brief"] and not game.workshop.area.has_point(game.guard.position): return false
	return actor.position.distance_to(player.position)<145 and game.world.line_clear(actor.position,player.position) and not game.world.is_under_roof(actor.position)

func _beside_player(actor) -> Vector2:
	var player = game.actors[0]
	if actor.position.distance_to(player.position)>52 and actor.position.distance_to(player.position)<125 and game.world.line_clear(actor.position,player.position): return actor.position
	var offsets := [Vector2(82,0),Vector2(-82,0),Vector2(0,82),Vector2(0,-82),Vector2(65,65),Vector2(-65,65),Vector2(100,-60),Vector2(-100,-60)]
	for i in range(offsets.size()):
		var offset: Vector2 = offsets[(i+rendezvous_choice)%offsets.size()]
		var goal: Vector2 = player.position+offset
		if game.world.can_place_circle(goal,8,actor,true) and game.world.line_clear(goal,player.position): return goal
	return player.position

func _begin_dialogue():
	# Let the presenter and escort actually enter before the bell locks the
	# workshop. Advancing the period on arrival avoids stranding a slower NPC.
	if step_id in ["work_brief","afternoon_brief"]: _clock(float(step().clock))
	dialogue_ready = true
	text_revealed = 0
	var actor = presenter()
	# The world is held while listening. Clear the previous movement sample,
	# otherwise a companion that just arrived keeps walking in place.
	for person in game.actors+game.guard.warning_officers()+game.trade.actors.values():
		person.moved_this_frame = false
	actor.facing = actor.position.direction_to(game.actors[0].position)
	game.actors[0].facing = game.actors[0].position.direction_to(actor.position)
	conversations.append({"step":step_id,"speaker":presenter_name(),"distance":actor.position.distance_to(game.actors[0].position),"line_clear":game.world.line_clear(actor.position,game.actors[0].position)})

func supervision_enabled() -> bool:
	return not active or step_id == "warning_practice"

func advance_clock(delta: float):
	if not active: return
	var advances: bool = (step_id in ["work_practice","afternoon_work"] and game.routines.is_working(0)) or (step_id == "meal_practice" and game.routines.is_eating(0))
	if not advances or game.world_input_blocked(): return
	var ceiling: float = 600 if step_id == "work_practice" else 780 if step_id == "meal_practice" else 960
	var next := minf(ceiling,game.schedule.absolute_minutes()+maxf(delta,0)*1440.0/game.schedule.day_seconds)
	game.schedule.clock_elapsed = (next-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)

func _clock(minute: float):
	game.schedule.clock_elapsed = (minute-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.workshop.update_gate()
	game.routines.tick()
	game.routines.take_control(0)
	game.routine_panel.close()

func _enter(id: String):
	if id == "formal":
		finish()
		return
	step_id = id
	age = 0
	work_seconds = 0
	text_revealed = 0
	dialogue_ready = false
	line_index = 0
	lines = step().get("lines",[str(step().text)]).duplicate()
	rendezvous_retry = 0
	rendezvous_choice = 0
	guide_retry = 0
	game.guard.path.clear()
	events.append({"step":id,"minute":game.schedule.absolute_minutes(),"player_position":str(game.actors[0].position)})
	if step().has("clock") and step_id not in ["work_brief","afternoon_brief"]: _clock(float(step().clock))
	if step().kind == "brief":
		game.routines.take_control(0)
		rendezvous = _beside_player(presenter())
	if speaking() or blocks_input():
		game.mobile_controls.cancel_input()
		game.orders.stop(0)
	if id == "work_practice": wage_baseline = game.routines.work_rounds[0]
	if id == "warning_practice":
		game.stop_selected()
		game.workshop.warnings.erase(0)
		game.workshop.wanted.erase(0)
		warning_seen = false
	if id == "cell_tour":
		cell_opened = false
		cell_closed = false
	guide_goal = _target(str(step().get("target","")))
	guide_legs.clear()
	var gate_center: Vector2 = game.world.access_by_id(str(game.workshop.config.access_id)).rect.get_center()
	if id == "enter_work":
		guide_legs = [gate_center-Vector2(0,95),_visible_approach(game.routines._target(0,"work"))]
	elif id == "cell_tour" and game.workshop.area.has_point(game.guard.position):
		guide_legs = [gate_center-Vector2(0,95),gate_center+Vector2(0,120),guide_goal]
	if id == "monitor_arrive":
		monitor_goal = _visible_approach(game.routines._target(0,"work"))
		game.workshop.overseer.path.clear()
	game.map_camera.following = not blocks_input()
	_refresh()

func continue_lesson():
	if not active: return
	if speaking():
		if text_revealed < current_line().length():
			text_revealed = current_line().length()
			return
		if line_index+1<lines.size():
			line_index += 1
			text_revealed = 0
			return
		_enter(str(step().next))
	elif step().get("kind","") == "objective":
		game.map_camera.center_on(_target(str(step().get("target",""))))

func _visible_approach(point: Vector2) -> Vector2:
	for offset in [Vector2(100,0),Vector2(0,100),Vector2(-100,0),Vector2(0,-100),Vector2(140,80)]:
		var candidate: Vector2 = point+offset
		if game.world.can_place_circle(candidate,8,game.workshop.overseer,true) and game.world.line_clear(candidate,point): return candidate
	return game.workshop.overseer.position

func _target(symbol: String) -> Vector2:
	match symbol:
		"dorm_gate": return Vector2(game.schedule.dormitory(0).end.x+70,game.room_visibility.doorways.by_id("dorm-0").visual_rect.get_center().y+25)
		"work_gate": return game.world.access_by_id(str(game.workshop.config.access_id)).rect.get_center()+Vector2(0,95)
		"station": return game.routines._target(0,"work")
		"overseer": return monitor_goal if monitor_goal != Vector2.ZERO else game.workshop.overseer.position
		"meal": return game.routines._target(0,"meal")
		"npc": return game.actors[1].position
		"merchant": return game.trade.actors.values()[0].position if not game.trade.actors.is_empty() else game.routines._target(0,"free")
		"cell": return Vector2(game.room_config.confinement.cells[0].release[0],game.room_config.confinement.cells[0].release[1])
		"locked": return game.world.access_by_id("maintenance-entry").rect.get_center()
		"bed": return game.actors[0].home
		"inspection": return game.schedule.inspection_point(0)
	return game.actors[0].position

func controls_guard(actor, delta: float) -> bool:
	if not active: return false
	if step().kind == "brief" and actor == presenter():
		if not dialogue_ready: _walk_guard(actor,rendezvous,delta,false)
		else:
			actor.moved_this_frame = false
			actor.facing = actor.position.direction_to(game.actors[0].position)
		return true
	if actor == game.workshop.overseer and step_id in ["monitor_arrive","warning_brief"]:
		_walk_guard(actor,monitor_goal,delta,false)
		return true
	if actor != game.guard: return false
	if speaking(): return true
	var move_steps := ["guide_arrive","follow_work","enter_work","cell_tour","return_bed","inspection"]
	if step_id not in move_steps:
		rendezvous_retry -= maxf(delta,0)
		if rendezvous_retry<=0:
			if actor.path.is_empty() and actor.position.distance_to(rendezvous)>40: rendezvous_choice += 1
			rendezvous = _beside_player(actor)
			rendezvous_retry = 0.65
		_walk_guard(actor,rendezvous,delta,false)
		return true
	var destination := guide_goal
	if step_id == "enter_work": destination = _visible_approach(game.routines._target(0,"work"))
	if step_id == "return_bed": destination = _target("dorm_gate")
	if not guide_legs.is_empty():
		if actor.position.distance_to(guide_legs[0])<30:
			guide_legs.pop_front()
			actor.path.clear()
			actor.path_timer = 0
		if not guide_legs.is_empty(): destination = guide_legs[0]
	game.world.update_dorm_doors(game.schedule.is_sleep_time(),game.inspection_positions())
	_walk_guard(actor,destination,delta,step_id in ["follow_work","cell_tour"])
	return true

func _walk_guard(actor, goal: Vector2, delta: float, wait_for_player: bool):
	actor.moved_this_frame = false
	actor.state = "patrol"
	actor.target_id = -1
	# The player may reach the destination first. Stand beside them rather
	# than asking navigation to end on an occupied foot position.
	if not game.world.can_place_circle(goal,8,actor,true):
		for offset in [Vector2(0,-24),Vector2(24,0),Vector2(0,24),Vector2(-24,0)]:
			if game.world.can_place_circle(goal+offset,8,actor,true) and game.world.line_clear(goal+offset,goal):
				goal += offset
				break
	if actor.position.distance_to(goal) < 28:
		actor.facing = actor.position.direction_to(game.actors[0].position)
		return
	# Compare progress toward the final destination, not the current gate
	# staging point: a faster player may already be on the other side.
	var leash_goal := guide_goal if actor == game.guard else goal
	if wait_for_player and actor.position.distance_to(game.actors[0].position) > 150 and game.actors[0].position.distance_to(leash_goal)>actor.position.distance_to(leash_goal): return
	actor.path_timer -= delta
	var blocked: bool = not actor.path.is_empty() and not game.world.motion_clear(actor.position,actor.path[0],actor)
	if actor.path_timer <= 0 and (actor.path.is_empty() or blocked or actor.stalled_time>0.35 or actor.path_goal.distance_to(goal)>5 or actor.path_revision != game.world.obstacle_revision):
		actor.path = game.world.find_path(actor.position,goal,actor,true)
		if not actor.path_deferred:
			actor.path_timer = 0.35
			actor.path_goal = goal
			actor.path_revision = game.world.obstacle_revision
	while not actor.path.is_empty() and actor.position.distance_to(actor.path[0]) < 3: actor.path.remove_at(0)
	if actor.path.is_empty(): return
	var offset: Vector2 = actor.path[0]-actor.position
	actor.facing = offset.normalized()
	actor.moved_this_frame = game.world.move_actor(actor,actor.facing*minf(100*maxf(delta,0),offset.length())).length_squared()>0.001
	actor.stalled_time = 0 if actor.moved_this_frame else actor.stalled_time+maxf(delta,0)
	actor.queue_redraw()

func on_capture(actor_id: int):
	if actor_id != 0: return
	demonstration_captures += 1
	game.workshop.wanted.erase(0)
	game.guard.release_target()
	game.workshop.overseer.release_target()
	if step_id == "warning_practice":
		warning_seen = true
		capture_pending = true
		caught_message_until = age+5
		game.show_status("这是教程示范：不计禁闭次数。请实际工作，让警戒缓慢消退。",5)

func _focus(point: Vector2, delta: float, conversation := false):
	game.map_camera.following = false
	var limits: Array = game.map_camera.camera_limits()
	var anchor: Vector2 = Vector2(game.map_camera.view_rect().size.x/2,panel.position.y-14) if conversation else game.map_camera.view_rect().size/2
	var desired: Vector2 = (point-anchor).clamp(limits[0],limits[1])
	game.map_camera.position = game.map_camera.position.lerp(desired,1-exp(-maxf(delta,0)*3))
	game.map_camera.force_update_scroll()

func _conversation_focus(delta: float):
	var player: Vector2 = game.actors[0].position
	var host: Vector2 = presenter().position
	_focus(Vector2((player.x+host.x)/2,maxf(player.y,host.y)),delta,true)

func tick(delta: float):
	if not active or game.get_tree().paused: return
	if capture_pending:
		# The normal capture caller clears its target after this hook. Restore
		# the recovery exercise only after that cleanup, without moving anyone.
		capture_pending = false
		game.workshop.warnings[0] = 2.5
	age += maxf(delta,0)
	if step().kind == "brief" and not dialogue_ready:
		if _conversation_ready(): _begin_dialogue()
		elif presenter()==game.guard or presenter()==game.workshop.overseer:
			rendezvous_retry -= maxf(delta,0)
			if rendezvous_retry<=0:
				if presenter().path.is_empty() and presenter().position.distance_to(rendezvous)>40: rendezvous_choice += 1
				rendezvous = _beside_player(presenter())
				rendezvous_retry = 0.8
		_conversation_focus(delta)
	if speaking():
		text_revealed += maxf(delta,0)*45
		text_revealed = minf(text_revealed,current_line().length())
		_conversation_focus(delta)
	elif step().get("kind","") == "cinematic":
		_focus(game.workshop.overseer.position if step_id == "monitor_arrive" else game.guard.position,delta)
	var done := false
	var player = game.actors[0]
	match step_id:
		"guide_arrive": done = game.guard.position.distance_to(guide_goal)<30
		"follow_work": done = game.guard.position.distance_to(guide_goal)<60 and player.position.distance_to(guide_goal)<100
		"enter_work": done = game.workshop.area.grow(-8).has_point(player.position) and game.guard.position.distance_to(_visible_approach(game.routines._target(0,"work")))<30
		"work_practice": done = game.routines.work_rounds[0]>wage_baseline
		"monitor_arrive": done = game.workshop.overseer.position.distance_to(monitor_goal)<30
		"warning_practice":
			warning_seen = warning_seen or game.workshop.warnings.has(0)
			done = warning_seen and game.routines.is_working(0) and not game.workshop.warnings.has(0) and not game.workshop.wanted.has(0)
		"meal_practice": done = float(game.routines.meal_minutes[0])>=20-0.00001
		"chat_practice":
			chat_seen = chat_seen or (game.dialogue.panel.visible and game.dialogue.current_target.get("role","")=="prisoner")
			done = chat_seen and not game.dialogue.panel.visible
		"merchant_practice": done = not game.trade.actors.is_empty() and player.position.distance_to(_target("merchant"))<120 and game.world.line_clear(player.position,_target("merchant"))
		"return_work": done = player.position.distance_to(_target("station"))<85 and game.actors.slice(1).all(func(a): return game.workshop.area.has_point(a.position))
		"afternoon_work":
			if game.routines.is_working(0): work_seconds += maxf(delta,0)
			done = work_seconds>=3
		"cell_tour":
			if game.guard.position.distance_to(guide_goal)<60 and player.position.distance_to(guide_goal)<110:
				var door_id: String = game.room_config.confinement.cells[0].door_id
				if not cell_opened:
					game.world.set_access_closed(door_id,false)
					cell_opened = true
					age = 0
				elif age>1.5 and not cell_closed:
					game.world.set_access_closed(door_id,true)
					cell_closed = game.world.access_by_id(door_id).closed
				done = cell_closed
		"return_bed": done = game.actors.all(func(a):return a.position.distance_to(a.home)<28 and not game.orders.active.has(a.actor_id))
		"inspection": done = game.guard.position.distance_to(game.schedule.inspection_point(0))<30 and age>2
	if done: _enter(str(step().next))
	_refresh()

func _refresh():
	if not active: return
	layout()
	panel.visible = not game.fullscreen_ui.menu.visible and not game.dialogue.panel.visible and not game.shop_panel.panel.visible and not game.routine_panel.panel.visible and not game.schedule.panel.visible
	title.text = "入监日 %d/6 · %s" % [int(step().chapter),str(step().title)]
	speaker.text = str(step().get("speaker","你的任务"))
	var task: String = str(step().get("task",step().title))
	if step().kind == "brief": task = "与%s交谈，听完再继续。" % presenter_name() if dialogue_ready else "%s正在走来，请稍等。" % presenter_name()
	if body.text != task: body.text = task
	body.visible_characters = -1
	note.text = "现场演示 · 观察角色行动" if step().kind == "cinematic" else "交谈时暂停作息 · 不占正式期限" if step().kind == "brief" else "完成任务后继续 · 演练不计禁闭次数"
	if step_id == "warning_practice" and age<caught_message_until: note.text = "教程示范被抓，不记禁闭次数；请继续工作。"
	primary.visible = step().kind != "cinematic"
	primary.disabled = step().kind == "brief" and not dialogue_ready
	primary.text = ("继续听" if line_index+1<lines.size() else str(step().get("button","继续"))) if speaking() else "等待教官" if step().kind == "brief" else "指向目标"
	marker.visible = step().kind == "objective"
	marker.position = _target(str(step().get("target","")))
	marker.z_index = mini(4094,maxi(0,int(marker.position.y)-1))
	game.fullscreen_ui.clock.queue_redraw()
	if speech: speech.refresh()

func snapshot() -> Dictionary:
	return {"active":active,"completed":completed,"step":step_id,"chapter":step().get("chapter",0),"captures_demo":demonstration_captures,"events":events.duplicate(true),"conversations":conversations.duplicate(true),"dialogue_ready":dialogue_ready,"speaker":presenter_name() if active else "","line":line_index,"target":str(_target(str(step().get("target","")))) if active else ""}
