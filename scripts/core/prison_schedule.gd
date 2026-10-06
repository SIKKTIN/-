extends Node

var game
var config: Dictionary
var limit_seconds: float = 900
var day_seconds: float = 300
var escape_days: int = 3
var stage_day: int = -1
var skip_button: Button
var schedule_note: Label
var clock_elapsed: float = 0
var time_speed: float = 1
var curfew_returns: Dictionary = {}
var stage_index: int = -1
var clock_label: Label
var stage_button: Button
var panel: Panel
var blocker: ColorRect
var result_panel: Panel
var result_blocker: ColorRect
var result_label: Label

func configure(owner_game) -> void:
	game = owner_game
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/schedule.json"))
	_make_ui()
	reset()

func _paper_panel(name_text: String, point: Vector2, dimensions: Vector2, depth: int) -> Panel:
	var p := Panel.new()
	p.name = name_text
	p.position = point
	p.size = dimensions
	p.z_index = depth
	p.theme = game.cards[0].theme
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("f2ebdd")
	paper.border_color = Color("536052")
	paper.set_border_width_all(3)
	paper.set_corner_radius_all(8)
	p.add_theme_stylebox_override("panel",paper)
	game.get_node("HUD").add_child(p)
	return p

func _blocker(name_text: String, area: Rect2, depth: int) -> ColorRect:
	var b := ColorRect.new()
	b.name = name_text
	b.position = area.position
	b.size = area.size
	b.color = Color(0,0,0,0.25)
	b.z_index = depth
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	game.get_node("HUD").add_child(b)
	return b

func _label(parent: Node, point: Vector2, text: String, font_size: int = 18) -> Label:
	var label := Label.new()
	label.position = point
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",font_size)
	parent.add_child(label)
	return label

func _button(parent: Node, point: Vector2, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.position = point
	b.size = Vector2(140,44)
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func _make_ui() -> void:
	clock_label = _label(game.get_node("HUD"),Vector2(270,36),"",17)
	clock_label.name = "PrisonClock"
	clock_label.theme = game.cards[0].theme
	stage_button = game.presentation.lighting.toggle_button
	stage_button.pressed.connect(toggle)
	blocker = _blocker("ScheduleMapBlocker",Rect2(74,114,922,560),110)
	panel = _paper_panel("DailySchedule",Vector2(295,185),Vector2(530,364),111)
	_label(panel,Vector2(20,16),"今日监区日程",22)
	var lines := "08:00–12:00  劳动\n12:00–14:00  吃饭与休息\n14:00–18:00  劳动\n18:00–20:00  自由活动\n20:00–24:00  寝室区自由活动\n00:00–08:00  锁寝睡觉 · 警卫进房查寝"
	_label(panel,Vector2(20,60),lines,17)
	schedule_note = _label(panel,Vector2(20,235),"",15)
	skip_button = _button(panel,Vector2(20,304),"跳过夜晚",skip_night)
	_button(panel,Vector2(358,304),"继续行动",close)
	result_blocker = _blocker("RoundResultBlocker",Rect2(0,0,1200,720),200)
	result_panel = _paper_panel("RoundResult",Vector2(340,234),Vector2(500,255),201)
	result_label = _label(result_panel,Vector2(24,24),"",20)
	_button(result_panel,Vector2(180,183),"重新开始",game.reset_round)
	close()
	result_panel.hide()
	result_blocker.hide()

func reset() -> void:
	day_seconds = float(config.room_seconds.get(game.room_id,300))
	escape_days = int(config.get("escape_days",3)) if escape_days < 1 else escape_days
	limit_seconds = day_seconds*escape_days
	clock_elapsed = 0
	curfew_returns.clear()
	stage_index = -1
	stage_day = -1
	close()
	result_panel.hide()
	result_blocker.hide()
	tick(false)

func remaining() -> float:
	return maxf(0,limit_seconds-clock_elapsed)

func real_remaining() -> float:
	return remaining()/time_speed if time_speed > 0 else INF

func advance(real_delta: float) -> void:
	if game.get_tree().paused:
		return
	var target := minf(limit_seconds,clock_elapsed+maxf(0,real_delta)*time_speed)
	if game.routines and game.routine_panel and game.fullscreen_ui:
		# Land exactly on the next 08:00, including at high developer speeds.
		# Routine.tick opens its paused planner before this frame's AI runs.
		var morning := floorf(absolute_minutes()/1440.0)*1440.0+480.0
		if morning <= absolute_minutes()+0.00001:
			morning += 1440.0
		var boundary: float = (morning-float(config.start_minutes))/1440.0*day_seconds
		target = minf(target,boundary)
	clock_elapsed = target
	tick()

func set_time_speed(value: float) -> bool:
	if not is_finite(value) or value < 0 or value > 16:
		return false
	time_speed = value
	tick(false)
	return true

func absolute_minutes() -> float:
	return float(config.start_minutes)+clock_elapsed/day_seconds*1440.0

func clock_minutes() -> float:
	return fposmod(absolute_minutes(),1440.0)

func day_number() -> int:
	return 1+floori(absolute_minutes()/1440.0)

func time_left_text() -> String:
	var minutes := ceili(remaining()/day_seconds*1440)
	return "余 %d天 %02d:%02d" % [minutes/1440,(minutes%1440)/60,minutes%60]

func set_escape_days(value: int) -> bool:
	if value < 1 or value > 10:
		return false
	escape_days = value
	limit_seconds = day_seconds*escape_days
	tick(false)
	return true

func is_sleep_time() -> bool:
	return stage_index >= 0 and str(config.stages[stage_index].id) == "sleep"

func in_dorm_zone(actor_id: int) -> bool:
	return game.world.bounds.has_point(game.actors[actor_id].position) and game.actors[actor_id].position.x < game.world.guard_zone.position.x

func is_sleeping(actor_id: int) -> bool:
	var actor = game.actors[actor_id]
	if game.mobile_controls != null and game.mobile_controls.is_moving_actor(actor_id):
		return false
	return is_sleep_time() and not actor.escaped and in_dormitory(actor_id) and actor.position.distance_to(actor.home) <= 28 and not game.orders.active.has(actor_id) and actor.action_state == "idle"

func can_skip_night() -> bool:
	return game.phase == "playing" and is_sleep_time() and not (game.prison_alert != null and game.prison_alert.active) and game.actors.all(func(a): return not a.escaped and is_sleeping(a.actor_id))

func skip_night() -> void:
	if not can_skip_night():
		game.show_status("已触发警报或有人缺员，不能跳过查寝。" if (game.prison_alert != null and game.prison_alert.active) or game.actors.any(func(a): return a.escaped) else "所有伙伴需回到各自床位，停止行动后才能跳过夜晚。")
		return
	var target := absolute_minutes()-clock_minutes()+480.0
	var previous_clock := clock_elapsed
	clock_elapsed = minf(limit_seconds,(target-float(config.start_minutes))/1440.0*day_seconds)
	if game.attributes:
		game.attributes.skip_sleep(previous_clock,clock_elapsed)
	tick(false)
	close()
	if game.routines:
		game.routines.tick()
	if remaining() <= 0:
		game.finish_timeout()
	else:
		game.show_status("第%d天 08:00，寝室门已打开，继续逃脱。" % day_number(),5)

func actor_status(actor_id: int) -> String:
	if is_sleeping(actor_id):
		return "睡觉中"
	if is_sleep_time():
		return "醒着 · 查寝中"
	return "寝区自由" if in_dorm_zone(actor_id) else "室外警戒"

func is_curfew() -> bool:
	return stage_index >= 0 and bool(config.stages[stage_index].get("curfew",false))

func dormitory(actor_id: int) -> Rect2:
	var rooms: Array = config.get("room_dormitories",{}).get(game.room_id,[])
	if actor_id < rooms.size():
		var values: Array = rooms[actor_id]
		return Rect2(values[0],values[1],values[2],values[3])
	return Rect2(game.actors[actor_id].home-Vector2(64,64),Vector2(128,128)).intersection(game.world.bounds)

func in_dormitory(actor_id: int) -> bool:
	return dormitory(actor_id).grow(-17).has_point(game.actors[actor_id].position)

func inspection_point(actor_id: int) -> Vector2:
	var home: Vector2 = game.actors[actor_id].home
	var interior := dormitory(actor_id).grow(-18)
	return (home+Vector2(65,0)).clamp(interior.position,interior.end-Vector2(0.01,0.01))

func enter_curfew() -> void:
	game.skills.clear_all()
	game.orders.clear()
	if game.shop_panel:
		game.shop_panel.close()
	for actor in game.actors:
		if actor.escaped:
			continue
		var at_home: bool = in_dormitory(actor.actor_id) and actor.position.distance_to(actor.home) <= 28 if is_sleep_time() else in_dorm_zone(actor.actor_id)
		if at_home:
			curfew_returns[actor.actor_id] = "home"
			continue
		var accepted := false
		for offset in [Vector2.ZERO,Vector2(40,0),Vector2(-40,0),Vector2(0,40),Vector2(0,-40)]:
			var goal: Vector2 = actor.home+offset
			if dormitory(actor.actor_id).grow(-17).has_point(goal) and game.world.can_place_circle(goal,17,actor,true) and game.orders.issue(actor.actor_id,goal,"curfew"):
				accepted = true
				break
		curfew_returns[actor.actor_id] = "returning" if accepted else "blocked"
	if game.prison_alert != null and game.prison_alert.active:
		game.show_status("缺员警报持续：全监狱搜查中，夜晚无法跳过。",6)
	else:
		game.show_status("午夜锁寝：回床睡觉可跳过；继续行动要避开进房查寝的警卫。" if is_sleep_time() else "20:00：寝室区自由活动，室外进入警戒；午夜锁寝查房。",6)

func dog_active() -> bool:
	return (game.prison_alert != null and game.prison_alert.active) or (stage_index >= 0 and bool(config.stages[stage_index].dog_active))

func tick(announce: bool = true) -> void:
	var minute := clock_minutes()
	var next_index := 0
	for index in range(config.stages.size()):
		if minute >= float(config.stages[index].minute):
			next_index = index
	if stage_index != next_index or stage_day != day_number():
		var was_sleep: bool = is_sleep_time()
		stage_day = day_number()
		stage_index = next_index
		var stage: Dictionary = config.stages[stage_index]
		game.presentation.lighting.set_period(str(stage.period))
		if bool(stage.get("curfew",false)) and game.phase == "playing":
			enter_curfew()
		game.world.update_dorm_doors(is_sleep_time(),game.inspection_positions())
		if is_sleep_time() != was_sleep:
			game.guard.schedule_changed(is_sleep_time())
		if announce:
			if not is_curfew():
				game.show_status("缺员警报仍未解除，全监狱继续搜查。" if game.prison_alert != null and game.prison_alert.active else "%s开始：%s" % [stage.name,stage.detail],4)
	game.world.update_dorm_doors(is_sleep_time(),game.inspection_positions())
	skip_button.visible = is_sleep_time()
	if game.gate_watch:
		game.gate_watch.tick(0)
	skip_button.disabled = not can_skip_night()
	skip_button.tooltip_text = "警报或缺员时无法跳过夜晚；全员归床后才可跳过。"
	schedule_note.text = "%d天内逃出（共%d秒，流速可调）。\n" % [escape_days,int(limit_seconds)]+("回各自床位并停止行动后，可跳到次日08:00。" if is_sleep_time() else "作息每日循环；人员日常表打开时暂停游戏。")
	if game.prison_alert != null and game.prison_alert.active:
		schedule_note.text = "查寝发现缺员：全监狱警戒，增派2名警员。\n警报持续到本局结束，无法跳过夜晚。"
	var stage: Dictionary = config.stages[stage_index]
	var seconds := ceili(real_remaining()) if time_speed > 0 else 0
	var left := "剩余 %02d:%02d" % [seconds/60,seconds%60] if time_speed > 0 else "时钟暂停"
	clock_label.text = "%02d:%02d · %s · %s" % [floori(minute/60),floori(minute)%60,stage.name,left]
	clock_label.add_theme_color_override("font_color",Color("bc5348") if is_curfew() or real_remaining() <= 30 else Color("303b46"))
	stage_button.text = "日程 · %s" % stage.name
	stage_button.tooltip_text = "%d天内逃脱；人员日常表暂停，作息说明与交易继续计时。" % escape_days
	if remaining() <= 0:
		clock_label.text = "逃脱期限已到"
		stage_button.text = "日程 · 已封监"

func toggle() -> void:
	if game.phase != "playing":
		return
	if panel.visible:
		close()
	else:
		if game.shop_panel:
			game.shop_panel.close()
		if game.developer_settings:
			game.developer_settings.close()
		if game.routine_panel:
			game.routine_panel.close()
		panel.show()
		blocker.show()
		game.presentation.interaction.refresh()

func close() -> void:
	if panel:
		panel.hide()
	if blocker:
		blocker.hide()

func show_result(success: bool) -> void:
	close()
	if game.routine_panel:
		game.routine_panel.close()
	if game.developer_settings:
		game.developer_settings.close()
	if game.shop_panel:
		game.shop_panel.close()
	var count: int = game.actors.filter(func(a): return a.escaped).size()
	var carried: int = game.inventory.instances.values().filter(func(i): return i.location == "escaped").size()
	result_label.text = "%s\n逃出 %d / 3 · 带出 %d 件\n用时 %.1f 秒 · 抓回 %d 次\n%s" % ["逃脱成功！" if success else "逃脱期限已到 · 时间耗尽",count,carried,game.elapsed,game.captures,"三位伙伴都已逃出。" if success else "未逃出的伙伴被留在监区。"]
	result_panel.show()
	result_blocker.show()
	# Draw depth does not determine GUI hit order. Bring the allowed control
	# after the blocker in the HUD tree as well, so a phone can switch rooms.
	var hud: Node = game.get_node("HUD")
	if game.fullscreen_ui:
		game.fullscreen_ui.close_menu()
		hud.move_child(game.fullscreen_ui.menu_button,hud.get_child_count()-1)
	game.presentation.interaction.refresh()

func snapshot() -> Dictionary:
	return {"day":day_number(),"escape_days":escape_days,"sleep_time":is_sleep_time(),"can_skip_night":can_skip_night(),"limit_seconds":limit_seconds,"clock_elapsed":clock_elapsed,"time_speed":time_speed,"remaining":remaining(),"clock_minutes":clock_minutes(),"stage":config.stages[stage_index].id,"curfew":is_curfew(),"curfew_returns":curfew_returns.duplicate(),"dog_active":dog_active(),"panel_visible":panel.visible,"result_visible":result_panel.visible}
