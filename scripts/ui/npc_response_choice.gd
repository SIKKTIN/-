extends Button

var requirement: Label
var regular: StyleBoxFlat
var selected: StyleBoxFlat
var locked: StyleBoxFlat
var emphasized := false
var state_key: Array = []

func configure(font: Font, caption: String, callback: Callable):
	text = caption
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_font_override("font",font)
	add_theme_font_size_override("font_size",20)
	for color_name in ["font_color","font_hover_color","font_pressed_color"]:
		add_theme_color_override(color_name,Color("303b46"))
	add_theme_color_override("font_disabled_color",Color("838d83"))
	regular = StyleBoxFlat.new()
	regular.bg_color = Color("f2ebdd")
	regular.border_color = Color("68796c")
	regular.set_border_width_all(2)
	regular.set_corner_radius_all(9)
	regular.shadow_color = Color(0,0,0,0.22)
	regular.shadow_size = 3
	regular.set_content_margin_all(8)
	regular.content_margin_left = 24
	regular.content_margin_right = 44
	selected = regular.duplicate()
	selected.border_color = Color("328d84")
	selected.set_border_width_all(3)
	var hover := selected.duplicate()
	hover.bg_color = Color("eaf0e7")
	var pressed_style := hover.duplicate()
	pressed_style.bg_color = Color("ccdcd2")
	locked = regular.duplicate()
	locked.bg_color = Color("e1dfd3")
	locked.border_color = Color("919b8f")
	add_theme_stylebox_override("normal",regular)
	add_theme_stylebox_override("hover",hover)
	add_theme_stylebox_override("pressed",pressed_style)
	add_theme_stylebox_override("disabled",locked)
	requirement = Label.new()
	requirement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	requirement.add_theme_font_override("font",font)
	requirement.add_theme_font_size_override("font_size",12)
	requirement.add_theme_color_override("font_color",Color("838d83"))
	requirement.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(requirement)
	pressed.connect(callback)
	resized.connect(_place_requirement)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	set_state(false,"",false)

func set_state(unavailable: bool, reason: String, highlight: bool):
	var next := [unavailable,reason,highlight]
	if next==state_key: return
	state_key = next
	disabled = unavailable
	emphasized = highlight
	requirement.text = reason
	requirement.visible = unavailable and not reason.is_empty()
	locked.content_margin_bottom = 25 if requirement.visible else 8
	add_theme_stylebox_override("normal",selected if emphasized else regular)
	_place_requirement()
	queue_redraw()

func _place_requirement():
	if not requirement: return
	requirement.position = Vector2(24,size.y-25)
	requirement.size = Vector2(maxf(size.x-68,0),20)

func _draw():
	var center := Vector2(size.x-27,size.y/2)
	if disabled:
		var ink := Color("838d83")
		draw_arc(center-Vector2(0,3),4.5,PI,TAU,12,ink,2,true)
		draw_style_box(_lock_box(),Rect2(center-Vector2(6,3),Vector2(12,11)))
		draw_circle(center+Vector2(0,1),1.3,Color("e1dfd3"),true,-1,true)
		draw_line(center+Vector2(0,1),center+Vector2(0,4),Color("e1dfd3"),1.5,true)
	elif emphasized or is_hovered():
		draw_polyline(PackedVector2Array([center+Vector2(-3,-6),center+Vector2(3,0),center+Vector2(-3,6)]),Color("328d84"),2,true)

var lock_style: StyleBoxFlat
func _lock_box() -> StyleBoxFlat:
	if not lock_style:
		lock_style = StyleBoxFlat.new()
		lock_style.bg_color = Color("838d83")
		lock_style.set_corner_radius_all(2)
	return lock_style
