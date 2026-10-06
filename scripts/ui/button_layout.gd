extends Node

# Positions are proportions of the available safe area, independent of pixels.
class DragHandle extends Control:
	var editor
	var id: String
	func _draw() -> void:
		var selected: bool = editor.drag_id == id
		var box := StyleBoxFlat.new()
		box.bg_color = Color("e8f2e9") if selected else Color("f2ebdd")
		box.border_color = Color("328b82")
		box.set_border_width_all(3 if selected else 2)
		box.set_corner_radius_all(20)
		draw_style_box(box,Rect2(Vector2.ZERO,size))
		var icon: Texture2D = editor.ui._icon("locate") if id == "pad" else editor.controls[id].display_icon if id != "target" else null
		if icon:
			draw_texture_rect(icon,Rect2((size.x-24)/2,12,24,24),false)
		var label: String = {"pad":"移动摇杆","action":"互动","ability":"技能","bag":"背包","target":"换目标"}[id]
		var font_size := 14 if id in ["pad","action"] else 12
		var width: float = editor.ui.font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		draw_string(editor.ui.font,Vector2((size.x-width)/2,size.y-14),label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("303b46"))
		if id == "pad":
			draw_circle(size/2,24,Color("328b82"),true,-1,true)

var ui
var game
var controls: Dictionary = {}
var handles: Dictionary = {}
var defaults: Dictionary = {}
var positions: Dictionary = {}
var draft: Dictionary = {}
var overlay: Control
var header: Panel
var hint: Label
var save_button: Button
var cancel_button: Button
var reset_button: Button
var editing := false
var drag_id := ""
var drag_pointer := -2
var drag_offset := Vector2.ZERO
var held_button: Button
var button_pointer := -2
var preference_path := "user://button-layout.cfg"

func configure(owner_ui) -> void:
	ui = owner_ui
	game = ui.game
	process_mode = Node.PROCESS_MODE_ALWAYS
	controls = {"pad":game.mobile_controls.pad,"action":ui.action_button,"ability":ui.ability_button,"bag":ui.bag_button,"target":ui.target_button}
	var override_path := OS.get_environment("ESCAPE_BUTTON_LAYOUT_PATH")
	if override_path.begins_with("user://"):
		preference_path = override_path
	load_preferences()
	overlay = Control.new()
	overlay.name = "ButtonLayoutEditor"
	overlay.z_index = 260
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	game.get_node("HUD").add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.08,0.14,0.13,0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)
	header = Panel.new()
	header.theme = ui.theme
	header.add_theme_stylebox_override("panel",ui.theme.get_stylebox("panel","HudPanel"))
	overlay.add_child(header)
	game.schedule._label(header,Vector2(16,8),"按键布局",22)
	hint = game.schedule._label(header,Vector2(16,40),"拖动摇杆和按键；绿色边框内可调整，游戏已暂停。",14)
	reset_button = game.schedule._button(header,Vector2.ZERO,"恢复默认",reset_draft)
	cancel_button = game.schedule._button(header,Vector2.ZERO,"取消",cancel)
	save_button = game.schedule._button(header,Vector2.ZERO,"保存布局",save)
	for id in controls:
		var handle := DragHandle.new()
		handle.editor = self
		handle.id = id
		handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(handle)
		handles[id] = handle
	overlay.hide()
	game.get_window().focus_exited.connect(end_drag)

func bounds() -> Rect2:
	var safe: Rect2 = ui.safe_area()
	return Rect2(safe.position+Vector2(12,112),safe.size-Vector2(24,124))

func load_preferences() -> void:
	positions.clear()
	var file := ConfigFile.new()
	if file.load(preference_path) != OK:
		return
	for id in controls:
		if not file.has_section_key("positions",id):
			continue
		var value = file.get_value("positions",id,null)
		if value is Vector2 and is_finite(value.x) and is_finite(value.y):
			positions[id] = value.clamp(Vector2.ZERO,Vector2.ONE)

func remember_defaults() -> void:
	for id in controls:
		defaults[id] = controls[id].position

func valid_position(id: String, point: Vector2) -> bool:
	var rect := Rect2(point,controls[id].size)
	if not bounds().encloses(rect):
		return false
	var fixed: Array = game.cards + [ui.clock,ui.routine_button,ui.menu_button,ui.wallet,ui.goal]
	if not ui.minimap_collapsed:
		fixed.append(game.mini_map)
	for control in fixed:
		if rect.grow(6).intersects(control.get_global_rect()):
			return false
	for other in controls:
		if other != id and rect.grow(6).intersects(controls[other].get_global_rect()):
			return false
	return true

func apply_positions() -> void:
	var data: Dictionary = draft if editing else positions
	var area := bounds()
	for id in controls:
		if data.has(id):
			controls[id].position = area.position+(area.size-controls[id].size)*data[id]
	# A smaller screen can make a formerly valid arrangement overlap fixed HUD.
	# Fall back as a complete group, preserving saved proportions for later.
	for id in controls:
		if data.has(id) and not valid_position(id,controls[id].position):
			for key in controls:
				controls[key].position = defaults[key]
			break
	if editing:
		sync_handles()

func sync_handles() -> void:
	overlay.size = game.get_viewport_rect().size
	var safe: Rect2 = ui.safe_area()
	header.position = safe.position
	header.size = Vector2(safe.size.x,88)
	for index in range(3):
		var button: Button = [reset_button,cancel_button,save_button][index]
		button.size = Vector2(112,48)
		button.position = Vector2(header.size.x-368+index*120,20)
	for id in controls:
		handles[id].position = controls[id].position
		handles[id].size = controls[id].size
		handles[id].queue_redraw()

func open() -> void:
	if game.phase != "playing":
		return
	ui.close_menu()
	ui.bag_open = false
	game.mobile_controls.cancel_input()
	draft = positions.duplicate(true)
	editing = true
	game.get_tree().paused = true
	overlay.show()
	game.get_node("HUD").move_child(overlay,game.get_node("HUD").get_child_count()-1)
	ui.layout()
	ui.refresh()

func end_drag() -> void:
	drag_id = ""
	drag_pointer = -2
	held_button = null
	button_pointer = -2
	if editing:
		sync_handles()

func move_handle(point: Vector2) -> void:
	if drag_id == "":
		return
	var control: Control = controls[drag_id]
	var area := bounds()
	var next := (point-drag_offset).clamp(area.position,area.end-control.size)
	if not valid_position(drag_id,next):
		hint.text = "这里会遮住其他按键或界面，请留出一点距离。"
		return
	control.position = next
	draft[drag_id] = (next-area.position)/(area.size-control.size)
	hint.text = "拖动调整位置；点击保存后，会记住这套布局。"
	sync_handles()

func reset_draft() -> void:
	end_drag()
	draft.clear()
	ui.layout()
	hint.text = "已恢复默认位置；点击保存生效，取消可返回原布局。"

func save() -> void:
	var file := ConfigFile.new()
	for id in draft:
		file.set_value("positions",id,draft[id])
	if file.save(preference_path) != OK:
		hint.text = "布局保存失败，请重试；当前仍是预览。"
		return
	positions = draft.duplicate(true)
	finish()
	game.show_status("按键布局已保存；暂停菜单里可随时调整。")

func cancel() -> void:
	finish()

func finish() -> void:
	end_drag()
	editing = false
	overlay.hide()
	game.mobile_controls.cancel_input()
	game.get_tree().paused = false
	ui.layout()
	ui.toggle_menu()

func _input(event: InputEvent) -> void:
	if not editing:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel()
		get_viewport().set_input_as_handled()
		return
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == -1:
		get_viewport().set_input_as_handled()
		return
	var pointer := -2
	var pressed := false
	var released := false
	var point := Vector2.ZERO
	if event is InputEventScreenTouch:
		pointer = event.index
		pressed = event.pressed and not event.canceled
		released = not event.pressed or event.canceled
		point = event.position
	elif event is InputEventScreenDrag:
		pointer = event.index
		point = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pointer = -1
		pressed = event.pressed
		released = not event.pressed
		point = event.position
	elif event is InputEventMouseMotion:
		pointer = -1
		point = event.position
	else:
		return
	if released:
		if pointer == button_pointer:
			var button := held_button
			held_button = null
			button_pointer = -2
			if button and button.get_global_rect().has_point(point) and not (event is InputEventScreenTouch and event.canceled):
				button.pressed.emit()
		elif pointer == drag_pointer:
			end_drag()
	elif pressed:
		if drag_pointer == -2 and button_pointer == -2:
			for button in [reset_button,cancel_button,save_button]:
				if button.get_global_rect().has_point(point):
					held_button = button
					button_pointer = pointer
					break
			if button_pointer == -2:
				for id in handles:
					if handles[id].get_global_rect().has_point(point):
						drag_id = id
						drag_pointer = pointer
						drag_offset = point-controls[id].position
						sync_handles()
						break
	elif pointer == drag_pointer:
		move_handle(point)
	get_viewport().set_input_as_handled()
