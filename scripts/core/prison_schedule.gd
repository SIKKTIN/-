extends Node

var game
var config: Dictionary
var limit_seconds: float = 300
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
	var lines := ""
	for index in range(config.stages.size()):
		var stage: Dictionary = config.stages[index]
		var end_minute: int = int(config.stages[index+1].minute) if index+1 < config.stages.size() else int(config.end_minutes)
		lines += "%02d:%02d–%02d:%02d  %s\n" % [int(stage.minute)/60,int(stage.minute)%60,end_minute/60,end_minute%60,stage.name]
	lines += "22:00  封监 · 未全部逃出则本局失败"
	_label(panel,Vector2(20,60),lines,17)
	_label(panel,Vector2(20,245),"20:00各自归寝；外出违规，警卫加强戒备。\n查看日程、交易时，时间仍然流逝。",15)
	_button(panel,Vector2(195,304),"继续行动",close)
	result_blocker = _blocker("RoundResultBlocker",Rect2(0,0,1200,720),200)
	result_panel = _paper_panel("RoundResult",Vector2(340,234),Vector2(500,255),201)
	result_label = _label(result_panel,Vector2(24,24),"",20)
	_button(result_panel,Vector2(180,183),"重新开始",game.reset_round)
	close()
	result_panel.hide()
	result_blocker.hide()

func reset() -> void:
	limit_seconds = float(config.room_seconds.get(game.room_id,300))
	clock_elapsed = 0
	curfew_returns.clear()
	stage_index = -1
	close()
	result_panel.hide()
	result_blocker.hide()
	tick(false)

func remaining() -> float:
	return maxf(0,limit_seconds-clock_elapsed)

func real_remaining() -> float:
	return remaining()/time_speed if time_speed > 0 else INF

func advance(real_delta: float) -> void:
	clock_elapsed = minf(limit_seconds,clock_elapsed+maxf(0,real_delta)*time_speed)
	tick()

func set_time_speed(value: float) -> bool:
	if not is_finite(value) or value < 0 or value > 16:
		return false
	time_speed = value
	tick(false)
	return true

func clock_minutes() -> float:
	return lerpf(float(config.start_minutes),float(config.end_minutes),clampf(clock_elapsed/limit_seconds,0,1))

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

func enter_curfew() -> void:
	game.skills.clear_all()
	game.orders.clear()
	if game.shop_panel:
		game.shop_panel.close()
	for actor in game.actors:
		if actor.escaped:
			continue
		if in_dormitory(actor.actor_id):
			curfew_returns[actor.actor_id] = "home"
			continue
		var accepted := false
		for offset in [Vector2.ZERO,Vector2(40,0),Vector2(-40,0),Vector2(0,40),Vector2(0,-40)]:
			var goal: Vector2 = actor.home+offset
			if dormitory(actor.actor_id).grow(-17).has_point(goal) and game.world.can_place_circle(goal,17,actor,true) and game.orders.issue(actor.actor_id,goal):
				accepted = true
				break
		curfew_returns[actor.actor_id] = "returning" if accepted else "blocked"
	game.show_status("20:00归寝：路线受阻的伙伴需手动开路；寝室外已进入宵禁警戒。" if curfew_returns.values().has("blocked") else "20:00归寝：伙伴返回各自寝室；寝室外已进入宵禁警戒。",6)

func dog_active() -> bool:
	return stage_index >= 0 and bool(config.stages[stage_index].dog_active)

func tick(announce: bool = true) -> void:
	var minute := clock_minutes()
	var next_index := 0
	for index in range(config.stages.size()):
		if minute >= float(config.stages[index].minute):
			next_index = index
	if stage_index != next_index:
		stage_index = next_index
		var stage: Dictionary = config.stages[stage_index]
		game.presentation.lighting.set_period(str(stage.period))
		if bool(stage.get("curfew",false)) and game.phase == "playing":
			enter_curfew()
		if announce:
			if not is_curfew():
				game.show_status("%s开始：%s" % [stage.name,stage.detail],4)
	var stage: Dictionary = config.stages[stage_index]
	var seconds := ceili(real_remaining()) if time_speed > 0 else 0
	var left := "剩余 %02d:%02d" % [seconds/60,seconds%60] if time_speed > 0 else "时钟暂停"
	clock_label.text = "%02d:%02d · %s · %s" % [floori(minute/60),floori(minute)%60,stage.name,left]
	clock_label.add_theme_color_override("font_color",Color("bc5348") if is_curfew() or real_remaining() <= 30 else Color("303b46"))
	stage_button.text = "日程 · %s" % stage.name
	stage_button.tooltip_text = "查看日程；22:00封监。时间不会因交易或查看日程暂停。"
	if remaining() <= 0:
		clock_label.text = "22:00 · 封监 · 剩余 00:00"
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
	if game.developer_settings:
		game.developer_settings.close()
	if game.shop_panel:
		game.shop_panel.close()
	var count: int = game.actors.filter(func(a): return a.escaped).size()
	var carried: int = game.inventory.instances.values().filter(func(i): return i.location == "escaped").size()
	result_label.text = "%s\n逃出 %d / 3 · 带出 %d 件\n用时 %.1f 秒 · 抓回 %d 次\n%s" % ["逃脱成功！" if success else "22:00 封监 · 时间耗尽",count,carried,game.elapsed,game.captures,"三位伙伴都已逃出。" if success else "未逃出的伙伴被留在监区。"]
	result_panel.show()
	result_blocker.show()
	# Draw depth does not determine GUI hit order. Bring the allowed control
	# after the blocker in the HUD tree as well, so a phone can switch rooms.
	var hud: Node = game.get_node("HUD")
	hud.move_child(game.room_selector,hud.get_child_count()-1)
	game.presentation.interaction.refresh()

func snapshot() -> Dictionary:
	return {"limit_seconds":limit_seconds,"clock_elapsed":clock_elapsed,"time_speed":time_speed,"remaining":remaining(),"clock_minutes":clock_minutes(),"stage":config.stages[stage_index].id,"curfew":is_curfew(),"curfew_returns":curfew_returns.duplicate(),"dog_active":dog_active(),"panel_visible":panel.visible,"result_visible":result_panel.visible}
