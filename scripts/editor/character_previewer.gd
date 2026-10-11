@tool
extends Control

const Library = preload("res://scripts/presentation/character_library.gd")
const PreviewCanvas = preload("res://scripts/editor/character_preview_canvas.gd")
var character_id := ""
var asset: Dictionary = {}
var motion: Dictionary = {}
var walking := true
var playing := true
var frame_index := 0
var frame_clock := 0.0
var playback_speed := 1.0
var flipped := false
var refreshing := false
var visible_ids: Array[String] = []
var character_list: ItemList
var search: LineEdit
var count_label: Label
var title_label: Label
var info_label: Label
var source_label: Label
var stage: Control
var animation_picker: OptionButton
var direction_picker: OptionButton
var play_button: Button
var frame_slider: HSlider
var frame_label: Label
var previous_button: Button
var next_button: Button
var thumbnails: HBoxContainer
var thumbnail_canvases: Array[Control] = []
var thumbnail_buttons: Array[Button] = []

func make_label(parent: Node, text: String, font_size := 15) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func make_button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 14)
	button.custom_minimum_size.y = 36
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func make_picker(parent: Node, options: Array, action: Callable) -> OptionButton:
	var picker := OptionButton.new()
	for option in options: picker.add_item(str(option))
	picker.add_theme_font_size_override("font_size", 14)
	picker.custom_minimum_size.y = 36
	picker.item_selected.connect(action)
	parent.add_child(picker)
	return picker

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = load("res://art/ui/fullscreen/theme.tres")
	build_ui()
	filter_characters("")
	if character_id.is_empty() and not visible_ids.is_empty(): select_character(visible_ids[0])
	if get_parent() == get_tree().root and not Engine.is_editor_hint():
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--character="): select_character(argument.trim_prefix("--character="))
		get_window().title = "监狱风云 · 角色与动画预览器"
		get_window().content_scale_size = Vector2i.ZERO
		get_window().min_size = Vector2i(960, 640)
		# Another tool can disable auto_accept_quit on the shared SceneTree.
		get_window().close_requested.connect(func(): get_tree().quit())

func build_ui() -> void:
	var paper := PanelContainer.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(paper)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 14)
	paper.add_child(margin)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 10)
	margin.add_child(root_box)
	make_label(root_box, "角色与动画预览", 24)
	make_label(root_box, "查看项目内已制作的角色；动画、尺寸与脚底定位均使用游戏中的素材。", 14)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	root_box.add_child(body)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 210
	body.add_child(sidebar)
	search = LineEdit.new()
	search.placeholder_text = "搜索名称或角色 ID"
	search.add_theme_font_size_override("font_size", 14)
	search.text_changed.connect(filter_characters)
	sidebar.add_child(search)
	count_label = make_label(sidebar, "")
	character_list = ItemList.new()
	character_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	character_list.fixed_icon_size = Vector2i(38, 56)
	character_list.add_theme_font_size_override("font_size", 16)
	character_list.add_theme_color_override("font_selected_color", Color("263d43"))
	character_list.add_theme_color_override("font_hovered_color", Color("263d43"))
	character_list.item_selected.connect(func(index): select_character(visible_ids[index]))
	sidebar.add_child(character_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	title_label = make_label(right, "", 22)
	info_label = make_label(right, "", 14)
	stage = PreviewCanvas.new()
	stage.custom_minimum_size = Vector2(380, 170)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(stage)
	var controls := HFlowContainer.new()
	controls.add_theme_constant_override("h_separation", 8)
	right.add_child(controls)
	animation_picker = make_picker(controls, ["行走", "站立"], func(index): set_animation(index == 0))
	play_button = make_button(controls, "暂停", func(): set_playing(not playing))
	previous_button = make_button(controls, "‹ 上一帧", func(): step_frame(-1))
	next_button = make_button(controls, "下一帧 ›", func(): step_frame(1))
	direction_picker = make_picker(controls, ["朝右", "朝左（镜像）"], func(index): set_direction(index == 1))
	var view_controls := HFlowContainer.new()
	view_controls.add_theme_constant_override("h_separation", 8)
	right.add_child(view_controls)
	make_label(view_controls, "速度")
	var speed_picker := make_picker(view_controls, ["0.25×", "0.5×", "1×", "1.5×", "2×"], func(index): playback_speed = [0.25, 0.5, 1.0, 1.5, 2.0][index])
	speed_picker.select(2)
	make_label(view_controls, "缩放")
	var zoom_picker := make_picker(view_controls, ["1×", "2×", "3×", "4×", "6×"], func(index): stage.zoom = [1.0, 2.0, 3.0, 4.0, 6.0][index]; stage.queue_redraw())
	zoom_picker.select(3)
	make_picker(view_controls, ["浅色棋盘", "深色背景", "地面色"], func(index): stage.background = index; stage.queue_redraw())
	var guide := CheckButton.new()
	guide.text = "脚底参考线"
	guide.add_theme_font_size_override("font_size", 13)
	guide.button_pressed = true
	guide.toggled.connect(func(enabled): stage.guides = enabled; stage.queue_redraw())
	view_controls.add_child(guide)
	var timeline := HBoxContainer.new()
	right.add_child(timeline)
	frame_label = make_label(timeline, "帧 1 / 8")
	frame_label.custom_minimum_size.x = 85
	frame_slider = HSlider.new()
	frame_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame_slider.step = 1
	frame_slider.value_changed.connect(func(value):
		if not refreshing: seek_frame(int(value)))
	timeline.add_child(frame_slider)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 112
	right.add_child(scroll)
	thumbnails = HBoxContainer.new()
	scroll.add_child(thumbnails)
	source_label = make_label(right, "", 12)
	source_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	make_label(root_box, "空格：播放 / 暂停　　← →：逐帧　　当前素材为左右朝向，尚无独立的朝上 / 朝下动画。", 13)

func filter_characters(query: String) -> void:
	visible_ids.clear()
	character_list.clear()
	for id in Library.all():
		var entry: Dictionary = Library.all()[id]
		if not query.is_empty() and not (str(entry.name) + " " + str(id)).to_lower().contains(query.to_lower()): continue
		visible_ids.append(id)
		character_list.add_item(str(entry.name), Library.idle(id))
		character_list.set_item_tooltip(character_list.item_count - 1, str(id))
		if id == character_id: character_list.select(character_list.item_count - 1)
	count_label.text = "%d / %d 个形象" % [visible_ids.size(), Library.all().size()]

func select_character(id: String) -> void:
	if not Library.all().has(id): return
	character_id = id
	asset = Library.all()[id]
	motion = Library.motion(id)
	frame_index = 0
	frame_clock = 0
	title_label.text = str(asset.name)
	info_label.text = "%s　·　站立 1 帧 / 行走 %d 帧　·　%d FPS　·　游戏高度 %d" % [id, asset.walk_animation.frames.size(), asset.walk_animation.fps, preload("res://scripts/core/world_scale.gd").human_height(asset)]
	source_label.text = str(asset.walk_animation.texture) if walking else str(asset.texture)
	source_label.tooltip_text = source_label.text
	if id in visible_ids: character_list.select(visible_ids.find(id))
	rebuild_thumbnails()
	sync_ui()

func rebuild_thumbnails() -> void:
	for child in thumbnails.get_children():
		thumbnails.remove_child(child)
		child.queue_free()
	thumbnail_canvases.clear()
	thumbnail_buttons.clear()
	for index in range(asset.walk_animation.frames.size() if walking else 1):
		var box := VBoxContainer.new()
		thumbnails.add_child(box)
		var button := make_button(box, "", func(): seek_frame(index))
		button.custom_minimum_size = Vector2(74, 80)
		button.toggle_mode = true
		var preview := PreviewCanvas.new()
		preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		preview.compact = true
		preview.asset = asset
		preview.motion = motion
		preview.walking = walking
		preview.frame_index = index
		# Keep the button's selection border visible around the image.
		button.add_child(preview)
		preview.offset_left = 3
		preview.offset_top = 3
		preview.offset_right = -3
		preview.offset_bottom = -3
		thumbnail_canvases.append(preview)
		thumbnail_buttons.append(button)
		var label := make_label(box, "站立" if not walking else str(index + 1), 12)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func set_animation(is_walking: bool) -> void:
	walking = is_walking
	frame_index = 0
	frame_clock = 0
	rebuild_thumbnails()
	sync_ui()

func set_playing(enabled: bool) -> void:
	playing = enabled
	sync_ui()

func set_direction(is_left: bool) -> void:
	flipped = is_left
	sync_ui()

func seek_frame(index: int) -> void:
	playing = false
	frame_index = posmod(index, asset.walk_animation.frames.size()) if walking else 0
	frame_clock = float(frame_index)
	sync_ui()

func step_frame(direction: int) -> void:
	if walking: seek_frame(frame_index + direction)

func advance(delta: float) -> void:
	if not playing or not walking or asset.is_empty(): return
	frame_clock = fposmod(frame_clock + delta * float(asset.walk_animation.fps) * playback_speed, asset.walk_animation.frames.size())
	var next := mini(int(frame_clock + 0.000001), asset.walk_animation.frames.size() - 1)
	if next != frame_index:
		frame_index = next
		sync_ui()

func _process(delta: float) -> void:
	if is_visible_in_tree(): advance(delta)

func sync_ui() -> void:
	if asset.is_empty(): return
	source_label.text = str(asset.walk_animation.texture) if walking else str(asset.texture)
	source_label.tooltip_text = source_label.text
	refreshing = true
	animation_picker.select(0 if walking else 1)
	direction_picker.select(1 if flipped else 0)
	play_button.text = "暂停" if playing else "播放"
	play_button.disabled = not walking
	previous_button.disabled = not walking
	next_button.disabled = not walking
	frame_slider.editable = walking
	frame_slider.max_value = asset.walk_animation.frames.size() - 1 if walking else 0
	frame_slider.value = frame_index
	frame_label.text = "帧 %d / %d" % [frame_index + 1, asset.walk_animation.frames.size() if walking else 1]
	stage.asset = asset
	stage.motion = motion
	stage.walking = walking
	stage.frame_index = frame_index
	stage.flipped = flipped
	stage.queue_redraw()
	for index in range(thumbnail_canvases.size()):
		thumbnail_canvases[index].flipped = flipped
		thumbnail_canvases[index].queue_redraw()
		thumbnail_buttons[index].set_pressed_no_signal(index == frame_index)
	refreshing = false

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo: return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit: return
	match event.keycode:
		KEY_SPACE: set_playing(not playing)
		KEY_LEFT: step_frame(-1)
		KEY_RIGHT: step_frame(1)
		_: return
	get_viewport().set_input_as_handled()
