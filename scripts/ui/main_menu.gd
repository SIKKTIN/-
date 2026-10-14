extends Control

const MenuArt = preload("res://scripts/ui/hud_skin.gd")
const Preferences = preload("res://scripts/core/menu_preferences.gd")
const Frames = preload("res://scripts/core/frame_settings.gd")
const BACKGROUND = preload("res://art/ui/main_menu/campus-background-v1.png")
const FONT = preload("res://art/fonts/NotoSansCJKsc-Regular.otf")
const DESIGN := Vector2(1672, 941)
const LOADING_SCENE := "res://scenes/loading.tscn"

class StartMenuButton extends Button:
	func _draw() -> void:
		MenuArt.rivets(self, size)
		draw_line(Vector2(18, 5), Vector2(size.x-18, 5), Color(1, 1, 1, 0.28), 1, true)

var preferences := Preferences.new()
var frame_settings := Frames.new()
var canvas: Control
var start_button: Button
var continue_button: Button
var settings_button: Button
var quit_button: Button
var help_button: Button
var credits_button: Button
var modal_layer: Control
var modal_panel: PanelContainer
var modal_content: VBoxContainer
var modal_title: Label
var modal_close: Button
var frame_picker: OptionButton
var volume_slider: HSlider
var fullscreen_toggle: CheckButton
var preference_notice: Label
var transition_pending := false
var _return_focus: Control

func _ready() -> void:
	# Editor playtests retain their direct-loading behavior.
	if "--editor-room" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file.call_deferred(LOADING_SCENE)
		return
	preferences.configure()
	frame_settings.configure()
	theme = load("res://art/ui/fullscreen/theme.tres")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var backing := ColorRect.new()
	backing.color = Color("142b36")
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backing)
	canvas = Control.new()
	canvas.name = "ArtworkLayout"
	canvas.size = DESIGN
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	var art := TextureRect.new()
	art.name = "CampusBackground"
	art.texture = BACKGROUND
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.size = DESIGN
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(art)
	continue_button = _button("ContinueGame", "继续游戏", Rect2(1184, 360, 332, 66), Callable())
	continue_button.disabled = true
	continue_button.tooltip_text = "暂无可继续的游戏进度"
	start_button = _button("StartGame", "开始游戏", Rect2(1184, 447, 332, 72), start_game, true)
	settings_button = _button("GameSettings", "游戏设置", Rect2(1184, 538, 332, 65), show_settings)
	quit_button = _button("QuitGame", "退出游戏", Rect2(1184, 626, 332, 68), func(): get_tree().quit())
	help_button = _link("Instructions", "操作说明", Rect2(1185, 742, 144, 38), show_instructions)
	credits_button = _link("Credits", "制作人员", Rect2(1370, 742, 147, 38), show_credits)
	var divider := ColorRect.new()
	divider.color = Color("c4c2ae")
	divider.position = Vector2(1342, 746)
	divider.size = Vector2(1, 27)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(divider)
	_build_modal()
	resized.connect(_layout)
	_layout()
	start_button.grab_focus()

func _button(id: String, caption: String, rect: Rect2, callback: Callable, primary := false) -> Button:
	var button := StartMenuButton.new()
	button.name = id
	button.text = caption
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 35)
	button.add_theme_constant_override("outline_size", 1)
	button.add_theme_color_override("font_outline_color", Color("194641") if primary else Color("303b46"))
	MenuArt.button(button, primary)
	button.add_theme_color_override("font_focus_color", Color("f7f2e7") if primary else MenuArt.INK)
	button.add_theme_stylebox_override("disabled", MenuArt.box("paper"))
	if primary:
		var hover := MenuArt.box("teal").duplicate() as StyleBoxFlat
		hover.bg_color = Color("3a958c")
		var pressed := hover.duplicate() as StyleBoxFlat
		pressed.bg_color = Color("246e68")
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", pressed)
		button.add_theme_color_override("font_hover_color", Color("fff4d8"))
		button.add_theme_color_override("font_pressed_color", Color("f7f2e7"))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("e3c47c")
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(9)
	button.add_theme_stylebox_override("focus", focus)
	if callback.is_valid(): button.pressed.connect(callback)
	canvas.add_child(button)
	return button

func _link(id: String, caption: String, rect: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.name = id
	button.text = caption
	button.position = rect.position
	button.size = rect.size
	button.flat = true
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 23)
	button.add_theme_color_override("font_color", Color("eee6d5"))
	button.add_theme_color_override("font_hover_color", Color("fff4cd"))
	button.add_theme_color_override("font_focus_color", Color("fff4cd"))
	button.pressed.connect(callback)
	canvas.add_child(button)
	return button

func _build_modal() -> void:
	modal_layer = Control.new()
	modal_layer.name = "MenuDialog"
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.09, 0.12, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(shade)
	modal_panel = PanelContainer.new()
	modal_panel.add_theme_stylebox_override("panel", MenuArt.box("paper"))
	modal_layer.add_child(modal_panel)
	var margins := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_"+edge, 18)
	modal_panel.add_child(margins)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	margins.add_child(box)
	modal_title = Label.new()
	modal_title.add_theme_font_size_override("font_size", 26)
	box.add_child(modal_title)
	modal_content = VBoxContainer.new()
	modal_content.add_theme_constant_override("separation", 16)
	box.add_child(modal_content)
	modal_close = Button.new()
	modal_close.text = "返回"
	modal_close.custom_minimum_size.y = 46
	MenuArt.button(modal_close, true)
	modal_close.pressed.connect(close_dialog)
	box.add_child(modal_close)
	modal_layer.hide()

func _layout() -> void:
	if not canvas: return
	# Scale artwork and hit areas together, without distorting the illustration.
	var factor := maxf(size.x/DESIGN.x, size.y/DESIGN.y)
	# Very wide windows keep controls within the viewport height.
	factor = minf(factor, size.y/820.0)
	canvas.scale = Vector2.ONE*factor
	canvas.position = (size-DESIGN*factor)/2.0
	canvas.position.x = minf(canvas.position.x, size.x-24-1565*factor)
	canvas.position.y = clampf(canvas.position.y, 16-165*factor, size.y-16-780*factor)
	if modal_panel:
		modal_panel.size.x = minf(520, maxf(280, size.x-40))
		modal_panel.reset_size()
		modal_panel.size.x = minf(520, maxf(280, size.x-40))
		modal_panel.position = (size-modal_panel.size)/2.0

func start_game() -> void:
	if transition_pending: return
	transition_pending = true
	for button in [start_button, settings_button, quit_button, help_button, credits_button]:
		button.disabled = true
	var error := get_tree().change_scene_to_file(LOADING_SCENE)
	if error != OK:
		transition_pending = false
		for button in [start_button, settings_button, quit_button, help_button, credits_button]:
			button.disabled = false
		_open_dialog("无法进入游戏")
		_paragraph("加载失败，请返回后重试。")
		_layout.call_deferred()

func _open_dialog(caption: String) -> void:
	_return_focus = get_viewport().gui_get_focus_owner()
	modal_title.text = caption
	for child in modal_content.get_children():
		modal_content.remove_child(child)
		child.queue_free()
	for button in [start_button, settings_button, quit_button, help_button, credits_button]:
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_NONE
	modal_layer.show()
	modal_close.grab_focus()

func close_dialog() -> void:
	modal_layer.hide()
	for button in [start_button, settings_button, quit_button, help_button, credits_button]:
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.focus_mode = Control.FOCUS_ALL
	if is_instance_valid(_return_focus): _return_focus.grab_focus()
	else: start_button.grab_focus()

func _paragraph(caption: String) -> Label:
	var label := Label.new()
	label.text = caption
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = minf(440, maxf(200, size.x-100))
	label.add_theme_font_size_override("font_size", 18)
	modal_content.add_child(label)
	return label

func show_settings() -> void:
	_open_dialog("游戏设置")
	_paragraph("帧率")
	frame_picker = OptionButton.new()
	frame_picker.name = "FrameRate"
	frame_picker.custom_minimum_size.y = 42
	for preset in ["60 帧 · 稳定", "90 帧 · 流畅", "不限帧率"]:
		frame_picker.add_item(preset)
	frame_picker.select(Frames.MODES.find(frame_settings.target_fps))
	frame_picker.item_selected.connect(func(index):
		_saved(frame_settings.apply(Frames.MODES[index])))
	modal_content.add_child(frame_picker)
	_paragraph("音量")
	volume_slider = HSlider.new()
	volume_slider.name = "MasterVolume"
	volume_slider.max_value = 100
	volume_slider.step = 1
	volume_slider.value = preferences.volume*100
	volume_slider.custom_minimum_size.y = 36
	volume_slider.value_changed.connect(func(value):
		preferences.volume = value/100.0
		preferences.apply()
		_saved(preferences.save() == OK))
	modal_content.add_child(volume_slider)
	fullscreen_toggle = CheckButton.new()
	fullscreen_toggle.name = "Fullscreen"
	fullscreen_toggle.text = "全屏显示"
	fullscreen_toggle.button_pressed = preferences.fullscreen
	fullscreen_toggle.toggled.connect(func(value):
		preferences.fullscreen = value
		preferences.apply()
		_saved(preferences.save() == OK))
	modal_content.add_child(fullscreen_toggle)
	preference_notice = _paragraph("设置会自动保存。")
	_layout.call_deferred()
	frame_picker.grab_focus()

func _saved(ok: bool) -> void:
	preference_notice.text = "设置已保存。" if ok else "设置已应用，但保存失败。"

func show_instructions() -> void:
	_open_dialog("操作说明")
	_paragraph("移动：WASD / 方向键，或左下角摇杆。\n互动：靠近目标后按 E，或点“靠近互动”。\n背包：点击右下角“背包”。\n快捷物品：数字键 1–4。\n查看场景：拖动地图；按 F 回到人物。\n暂停：Esc 或右上角暂停按钮。")
	_layout.call_deferred()

func show_credits() -> void:
	_open_dialog("制作人员")
	_paragraph("《监狱风云》\n\n感谢参与测试和提供反馈的玩家。\n完整制作名单将在正式版本公布。")
	_layout.call_deferred()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and modal_layer and modal_layer.visible:
		close_dialog()
		get_viewport().set_input_as_handled()
