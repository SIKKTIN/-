extends Node

const Board = preload("res://scripts/ui/routine_board.gd")
const KINDS := ["idle", "work", "rest", "free", "meal"]
const COLORS := {"idle": Color("eee7d9"), "work": Color("efd09c"), "rest": Color("d5dcc3"), "free": Color("cce0de"), "meal":Color("e6d9ba")}

class ActivityCell extends Button:
	var ui
	var kind := "idle"
	func _draw() -> void:
		var ink := Color("899087") if disabled else Color("303b46")
		var font: Font = ui.game.presentation.font
		var font_size := 16 if size.x < 156 else 18
		var label: String = ui.game.routines.NAMES[kind]
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var left := (size.x-width-36)/2
		Board.draw_activity_icon(self, kind, Vector2(left+12, size.y/2), ink)
		draw_string(font, Vector2(left+32, size.y/2+font_size*0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)

var game
var panel: Panel
var blocker: ColorRect
var board: Control
var title: Label
var day_label: Label
var clock_label: Label
var deadline_label: Label
var live_label: Label
var note: Label
var selectors: Array = [] # [time slot][actor], actual touch buttons.
var identities: Array = []
var portraits: Array = []
var apply_button: Button
var restore_button: Button
var close_button: Button
var picker: Panel
var picker_blocker: ColorRect
var picker_title: Label
var picker_options: Array = []
var draft: Array = []
var loaded_day := -1
var pause_active := false
var paused_before_open := false
var editing_actor := 0
var editing_slot := -1
var row_rects: Array = []
var pad := 24.0
var activity_left := 180.0
var column_width := 180.0
var timeline_y := 110.0
var rule_y := 158.0
var legend_y := 476.0

func configure(owner_game) -> void:
	game = owner_game
	process_mode = Node.PROCESS_MODE_ALWAYS
	blocker = game.schedule._blocker("RoutineBlocker", Rect2(), 130)
	blocker.process_mode = Node.PROCESS_MODE_ALWAYS
	blocker.color = Color(0.12, 0.17, 0.15, 0.48)
	panel = game.schedule._paper_panel("DailyRoutine", Vector2.ZERO, Vector2(1144, 622), 131)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.theme = load("res://art/ui/fullscreen/theme.tres")
	var paper := panel.theme.get_stylebox("panel", "HudPanel").duplicate() as StyleBoxFlat
	paper.bg_color = Color("f4eedf")
	paper.border_color = Color("888e79")
	paper.set_border_width_all(2)
	paper.set_corner_radius_all(16)
	paper.shadow_size = 8
	panel.add_theme_stylebox_override("panel", paper)
	board = Board.new()
	board.ui = self
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(board)
	title = _label("今日安排", 32)
	day_label = _label("", 20)
	clock_label = _label("", 22)
	deadline_label = _label("", 14)
	live_label = _label("已暂停 · 安排后继续", 14)
	note = _label("", 14)
	for id in range(3):
		portraits.append(load("res://art/ui/fullscreen/portrait_%d.tres" % (id+1)))
		var b := Button.new()
		b.name = "RoutinePartner%d" % (id+1)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
		b.pressed.connect(func(): _select_actor(id))
		panel.add_child(b)
		identities.append(b)
	for index in range(5):
		var row := []
		for id in range(3):
			var b := ActivityCell.new()
			b.ui = self
			b.name = "Routine_%d_%d" % [id, index]
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(48, 48)
			b.pressed.connect(func(): open_picker(id, index))
			panel.add_child(b)
			row.append(b)
		selectors.append(row)
	restore_button = game.schedule._button(panel, Vector2.ZERO, "恢复主角日程", restore)
	close_button = game.schedule._button(panel, Vector2.ZERO, "关闭", close)
	apply_button = game.schedule._button(panel, Vector2.ZERO, "应用今日安排", apply)
	apply_button.add_theme_stylebox_override("normal", _style(Color("328b82"), false))
	apply_button.add_theme_stylebox_override("hover", _style(Color("3b9b91"), false))
	apply_button.add_theme_stylebox_override("pressed", _style(Color("246e67"), false))
	apply_button.add_theme_color_override("font_color", Color("fffdf5"))
	apply_button.add_theme_color_override("font_hover_color", Color("fffdf5"))
	apply_button.add_theme_color_override("font_pressed_color", Color("fffdf5"))
	_make_picker()
	close()

func _label(text: String, font_size: int) -> Label:
	var label: Label = game.schedule._label(panel, Vector2.ZERO, text, font_size)
	label.add_theme_color_override("font_color", Color("303b46"))
	return label

func _style(color: Color, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("328b82") if selected else Color(0.40, 0.44, 0.38, 0.12)
	style.set_border_width_all(3 if selected else 1)
	style.set_corner_radius_all(10)
	return style

func _skin(b: ActivityCell, selected: bool) -> void:
	var color: Color = COLORS[b.kind]
	b.add_theme_stylebox_override("normal", _style(color, selected))
	b.add_theme_stylebox_override("hover", _style(color.lightened(0.10), true))
	b.add_theme_stylebox_override("pressed", _style(color.darkened(0.08), true))
	b.add_theme_stylebox_override("disabled", _style(color.lerp(Color("eee9df"), 0.6), false))
	b.queue_redraw()

func _make_picker() -> void:
	picker_blocker = ColorRect.new()
	picker_blocker.color = Color(0, 0, 0, 0.08)
	picker_blocker.z_index = 1
	picker_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	picker_blocker.gui_input.connect(func(event):
		if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
			close_picker()
			picker_blocker.accept_event())
	panel.add_child(picker_blocker)
	picker = Panel.new()
	picker.name = "ActivityPicker"
	picker.z_index = 2
	picker.size = Vector2(236, 316)
	picker.add_theme_stylebox_override("panel", panel.get_theme_stylebox("panel").duplicate())
	panel.add_child(picker)
	picker_title = game.schedule._label(picker, Vector2(16, 12), "", 16)
	for index in range(KINDS.size()):
		var b := ActivityCell.new()
		b.ui = self
		b.kind = KINDS[index]
		b.name = "Choose_"+b.kind
		b.position = Vector2(12, 44+index*52)
		b.size = Vector2(212, 48)
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(func(): choose_activity(b.kind))
		picker.add_child(b)
		picker_options.append(b)
	close_picker()

func layout(safe: Rect2) -> void:
	if not panel:
		return
	panel.size = Vector2(minf(1280, safe.size.x-24), minf(622, safe.size.y))
	panel.position = safe.get_center()-panel.size/2
	board.size = panel.size
	picker_blocker.size = panel.size
	var compact: bool = panel.size.y < 590
	pad = 18.0 if compact else 24.0
	activity_left = pad+(132.0 if panel.size.x < 1050 else 156.0)
	column_width = (panel.size.x-pad-activity_left)/5
	var row_top := 138.0 if compact else 174.0
	var footer_y: float = panel.size.y-pad-56
	note.position = Vector2(pad, footer_y-32)
	note.size = Vector2(panel.size.x-pad*2, 24)
	legend_y = note.position.y-36
	var row_height: float = (legend_y-18-row_top-16)/3
	row_rects.clear()
	for id in range(3):
		var rect := Rect2(pad, row_top+id*(row_height+8), panel.size.x-pad*2, row_height)
		row_rects.append(rect)
		identities[id].position = rect.position
		identities[id].size = Vector2(activity_left-pad-8, row_height)
		for index in range(5):
			var b: Button = selectors[index][id]
			b.position = Vector2(activity_left+index*column_width+4, rect.position.y+6)
			b.size = Vector2(column_width-8, row_height-12)
	title.position = Vector2(pad+8, pad)
	title.add_theme_font_size_override("font_size", 28 if compact else 32)
	day_label.position = Vector2(pad+170, pad+6)
	var clock_x: float = maxf(330, panel.size.x*0.53)
	clock_label.position = Vector2(clock_x+32, pad+2)
	deadline_label.position = Vector2(clock_x+32, pad+34)
	live_label.position = Vector2(panel.size.x-pad-176, pad+9)
	live_label.size = Vector2(176, 24)
	live_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	live_label.add_theme_font_size_override("font_size", 13)
	timeline_y = row_top-70
	rule_y = row_top-16
	restore_button.position = Vector2(pad, footer_y)
	restore_button.size = Vector2(216, 56)
	apply_button.position = Vector2(panel.size.x-pad-224, footer_y)
	apply_button.size = Vector2(224, 56)
	close_button.position = apply_button.position-Vector2(168, 0)
	close_button.size = Vector2(156, 56)
	for b in [apply_button, close_button, restore_button]:
		b.add_theme_font_size_override("font_size", 18)
	if picker.visible:
		_position_picker()
	board.queue_redraw()

func reload() -> void:
	close_picker()
	loaded_day = game.routines.day
	draft = game.routines.plans.duplicate(true)
	editing_actor = game.selected_actor_id
	editing_slot = game.routines.current_slot()
	refresh()

func editable(id: int, index: int) -> bool:
	return game.actor_is_controllable(id) and not game.actors[id].escaped and not game.schedule.is_sleep_time() and game.phase == "playing" and game.schedule.clock_minutes() < game.routines.SLOTS[index].end

func refresh() -> void:
	if not panel.visible:
		return
	if loaded_day != game.routines.day:
		reload()
		return
	day_label.text = "第%d天" % loaded_day
	var minute: float = game.schedule.clock_minutes()
	clock_label.text = "%02d:%02d · %s" % [floori(minute/60), floori(minute)%60, game.schedule.config.stages[game.schedule.stage_index].name]
	deadline_label.text = "逃脱期限：%d天 · %s" % [game.schedule.escape_days, game.schedule.time_left_text()]
	for index in range(5):
		for id in range(3):
			var b: ActivityCell = selectors[index][id]
			b.disabled = not editable(id, index)
			b.tooltip_text = "自动囚徒的固定日程，只读" if not game.actor_is_controllable(id) else "点击调整主角安排"
			# A live clock may finish a slot while its draft/menu is open.
			if b.disabled:
				draft[id][index] = game.routines.plans[id][index]
			var selected: bool = editing_actor == id and editing_slot == index
			if not b.has_meta("locked") or b.kind != draft[id][index] or b.get_meta("chosen", false) != selected or b.get_meta("locked", false) != b.disabled:
				b.kind = draft[id][index]
				b.set_meta("chosen", selected)
				b.set_meta("locked", b.disabled)
				_skin(b, selected)
	for id in range(3):
		identities[id].disabled = game.actors[id].escaped or not game.actor_is_controllable(id)
	apply_button.disabled = game.schedule.is_sleep_time() or game.phase != "playing"
	restore_button.disabled = game.schedule.is_sleep_time() or game.actors[game.selected_actor_id].escaped
	note.text = "午夜只读；早晨07:20可安排新一天。" if game.schedule.is_sleep_time() else "本关没有工作岗位，可安排休息与自由活动。" if game.room_config.get("routine_points", {}).get("work", []).is_empty() else "点击活动格修改；工作仅限劳动时段，20点后自由活动留在寝室区。"
	if draft != game.routines.plans:
		note.text = "尚未应用 · "+note.text
	if not game.schedule.is_sleep_time() and game.routines.allowed(0, "work"):
		note.text = ("尚未应用 · " if draft != game.routines.plans else "")+"满%d有效分钟工资 +%d；休息恢复体力，" % [roundi(game.routines.work_duration()), game.routines.work_wage()]+("12–14选吃饭，赴食堂取餐就座。" if game.routines.has_cafeteria() else "12–14寝室进食。")
	note.text += " 囚徒2、3自动日程只读。"
	if game.room_config.has("workshop"):
		note.text = "07:20起床前往车间，08:00锁门；外围圆形警戒，监工查岗。2、3自动劳动。"
	if picker.visible:
		if not editable(editing_actor, editing_slot):
			close_picker()
		else:
			for b in picker_options:
				b.disabled = not game.routines.allowed(editing_slot, b.kind)
	board.queue_redraw()

func _select_actor(id: int) -> void:
	if not game.actor_is_controllable(id): return
	close_picker()
	editing_actor = id
	game.select_actor(id)
	refresh()

func open_picker(id: int, index: int) -> void:
	if not editable(id, index):
		return
	editing_actor = id
	editing_slot = index
	game.select_actor(id)
	picker_title.text = "伙伴%d · %s" % [id+1, game.routines.SLOTS[index].label]
	picker.size.y = 316 if game.routines.has_cafeteria() else 292
	for b in picker_options:
		b.visible = b.kind != "meal" or game.routines.has_cafeteria()
		b.disabled = not game.routines.allowed(index, b.kind)
		_skin(b, draft[id][index] == b.kind)
	picker_blocker.show()
	picker.show()
	_position_picker()
	refresh()

func _position_picker() -> void:
	var cell: Button = selectors[editing_slot][editing_actor]
	var x: float = clampf(cell.position.x+cell.size.x/2-picker.size.x/2, pad, panel.size.x-pad-picker.size.x)
	# Keep the menu inside the board and clear of its footer actions.
	var y: float = clampf(cell.position.y+cell.size.y+8, 86, apply_button.position.y-picker.size.y-12)
	picker.position = Vector2(x, y)

func choose_activity(kind: String) -> void:
	if loaded_day != game.routines.day:
		reload()
		return
	if editable(editing_actor, editing_slot) and game.routines.allowed(editing_slot, kind):
		draft[editing_actor][editing_slot] = kind
	close_picker()
	refresh()

func close_picker() -> void:
	if picker:
		picker.hide()
	if picker_blocker:
		picker_blocker.hide()

func apply() -> void:
	if loaded_day != game.routines.day:
		reload()
		game.show_status("已进入新一天，请重新安排今天的活动。")
		return
	refresh()
	if game.routines.apply_today(draft):
		close()

func restore() -> void:
	game.routines.resume(game.selected_actor_id)
	game.show_status("伙伴%d恢复当前时段安排。" % (game.selected_actor_id+1))
	close()

func toggle() -> void:
	if game.phase != "playing":
		return
	if panel.visible:
		close()
	else:
		open()

func open() -> void:
	if game.phase != "playing" or panel.visible:
		return
	if game.fullscreen_ui.menu.visible:
		game.fullscreen_ui.close_menu()
	game.shop_panel.close()
	game.schedule.close()
	game.developer_settings.close()
	paused_before_open = game.get_tree().paused
	pause_active = true
	layout(game.fullscreen_ui.safe_area())
	panel.show()
	blocker.show()
	# Its normal visibility tick is pausable, so hide it before freezing.
	game.mini_map.hide()
	game.get_tree().paused = true
	reload()
	game.presentation.interaction.refresh()
	game.fullscreen_ui.refresh()

func close() -> void:
	close_picker()
	if panel:
		panel.hide()
	if blocker:
		blocker.hide()
	if pause_active:
		pause_active = false
		var menu_paused: bool = game.fullscreen_ui != null and game.fullscreen_ui.menu.visible
		game.get_tree().paused = paused_before_open or menu_paused
	if game and game.fullscreen_ui:
		game.fullscreen_ui.refresh()

func _unhandled_input(event: InputEvent) -> void:
	if picker and picker.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_picker()
		game.get_viewport().set_input_as_handled()
