extends Node

var game
var button: Button
var panel: Panel
var blocker: ColorRect
var days_input: SpinBox
var speed_input: SpinBox
var summary: Label
var preference_path := "user://developer-settings.cfg"

func configure(owner_game) -> void:
	game = owner_game
	var override_path := OS.get_environment("ESCAPE_DEV_SETTINGS_PATH")
	if override_path.begins_with("user://"):
		preference_path = override_path
	var saved := ConfigFile.new()
	if saved.load(preference_path) == OK:
		var value = saved.get_value("clock","speed",1.0)
		if typeof(value) in [TYPE_INT,TYPE_FLOAT]:
			game.schedule.set_time_speed(float(value))
		game.schedule.set_escape_days(int(saved.get_value("clock","days",3)))
	button = Button.new()
	button.name = "DeveloperSettingsButton"
	button.text = "开发者设置"
	button.position = Vector2(819,62)
	button.size = Vector2(159,42)
	button.theme = game.cards[0].theme
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(toggle)
	game.get_node("HUD").add_child(button)
	game.presentation.mute_button.position.y = 16
	game.presentation.mute_button.size.y = 38
	blocker = game.schedule._blocker("DeveloperMapBlocker",Rect2(74,114,922,560),120)
	panel = game.schedule._paper_panel("DeveloperSettings",Vector2(310,202),Vector2(510,406),121)
	game.schedule._label(panel,Vector2(22,18),"开发者设置",23)
	game.schedule._label(panel,Vector2(22,61),"时间流速",18)
	summary = game.schedule._label(panel,Vector2(22,308),"",15)
	game.schedule._label(panel,Vector2(22,87),"只调整日程时钟；人物、技能、巡逻保持原速。",15)
	speed_input = SpinBox.new()
	speed_input.name = "ClockSpeed"
	speed_input.position = Vector2(137,122)
	speed_input.size = Vector2(235,48)
	speed_input.min_value = 0
	speed_input.max_value = 16
	speed_input.step = 0.25
	speed_input.suffix = "×"
	speed_input.value_changed.connect(change_speed)
	panel.add_child(speed_input)
	var minus: Button = game.schedule._button(panel,Vector2(22,122),"−",func(): change_speed(maxf(0,game.schedule.time_speed-0.25)))
	minus.size = Vector2(98,48)
	var plus: Button = game.schedule._button(panel,Vector2(390,122),"+",func(): change_speed(minf(16,game.schedule.time_speed+0.25)))
	plus.size = Vector2(98,48)
	var values := [0.0,0.5,1.0,4.0]
	for index in range(values.size()):
		var preset: Button = game.schedule._button(panel,Vector2(22+index*118,181),"暂停时钟" if index == 0 else "%s×" % str(values[index]),change_speed.bind(values[index]))
		preset.name = "SpeedPreset%d" % index
		preset.size = Vector2(110,42)
	game.schedule._button(panel,Vector2(185,350),"继续行动",close)
	game.schedule._label(panel,Vector2(22,251),"逃脱期限（天）",18)
	days_input = SpinBox.new()
	days_input.name = "EscapeDays"
	days_input.position = Vector2(250,242)
	days_input.size = Vector2(238,48)
	days_input.min_value = 1
	days_input.max_value = 10
	days_input.step = 1
	days_input.value_changed.connect(func(value):
		game.schedule.set_escape_days(int(value))
		_save_preferences()
		_refresh())
	panel.add_child(days_input)
	_refresh()
	close()

func change_speed(value: float) -> void:
	if not game.schedule.set_time_speed(value):
		return
	_refresh()
	_save_preferences()

func _save_preferences() -> void:
	var saved := ConfigFile.new()
	saved.set_value("clock","days",game.schedule.escape_days)
	saved.set_value("clock","speed",game.schedule.time_speed)
	var error := saved.save(preference_path)
	if error != OK:
		game.show_status("流速已应用，本地保存失败。")

func _refresh() -> void:
	speed_input.set_value_no_signal(game.schedule.time_speed)
	days_input.set_value_no_signal(game.schedule.escape_days)
	summary.text = "0×暂停时钟；期限按24小时/天计算，偏好会保存。"
	button.tooltip_text = "当前日程流速 %s×；不会改变移动或技能速度。" % str(game.schedule.time_speed)

func toggle() -> void:
	if game.phase != "playing":
		return
	if panel.visible:
		close()
	else:
		if game.routine_panel:
			game.routine_panel.close()
		game.schedule.close()
		game.shop_panel.close()
		_refresh()
		panel.show()
		blocker.show()
		game.presentation.interaction.refresh()

func close() -> void:
	if panel:
		panel.hide()
	if blocker:
		blocker.hide()
