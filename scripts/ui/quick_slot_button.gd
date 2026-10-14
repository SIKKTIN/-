extends Button

signal clear_requested(index: int)
const Art = preload("res://scripts/ui/looting_skin.gd")
var index := 0
var font: Font
var display_icon: Texture2D
var state: Dictionary = {}
var binding_mode := false
var drop_state := 0
var display_key: Array = []
var touch_started := -1

func _ready():
	focus_mode = Control.FOCUS_NONE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for variant in ["normal", "hover", "pressed", "disabled"]:
		var fill := Color("e9dfca") if variant != "disabled" else Color("c5c3b7")
		var border := Art.AMBER if variant == "hover" else Color("867f6d")
		var style := Art.box(fill, border, 5, 2)
		style.shadow_color = Color(0, 0, 0, 0.25)
		style.shadow_size = 2
		style.shadow_offset = Vector2(0, 2)
		add_theme_stylebox_override(variant, style)
	resized.connect(queue_redraw)
	set_process(false)

func update_state(next: Dictionary, icon: Texture2D, locked_ui := false):
	var key: Array = [next, icon, locked_ui, size]
	if display_key == key: return
	display_key = key.duplicate(true)
	state = next
	display_icon = icon
	disabled = locked_ui
	tooltip_text = str(next.label)
	if not str(next.reason).is_empty(): tooltip_text += "\n" + str(next.reason)
	else: tooltip_text += "\n" + str(next.action)
	if binding_mode: tooltip_text += "\n拖入替换 · 右键或长按移除绑定"
	queue_redraw()

func preview_drop(value: int):
	if drop_state == value: return
	drop_state = value
	queue_redraw()

func _draw():
	for x in range(7, int(size.x)-6, 7):
		for y in [4.0, size.y-4]: draw_line(Vector2(x,y), Vector2(x+3,y), Color("afa28a"), 1, true)
	for y in range(7, int(size.y)-6, 7):
		for x in [4.0, size.x-4]: draw_line(Vector2(x,y), Vector2(x,y+3), Color("afa28a"), 1, true)
	var unavailable := not str(state.get("reason", "")).is_empty()
	if display_icon:
		var area := Rect2(7, 6, size.x-14, size.y-13)
		var fitted := display_icon.get_size()*minf(area.size.x/display_icon.get_width(), area.size.y/display_icon.get_height())
		draw_texture_rect(display_icon, Rect2(area.position+(area.size-fitted)/2, fitted), false, Color(1,1,1,0.38) if unavailable else Color.WHITE)
	else:
		var center := size/2
		draw_line(center-Vector2(7,0),center+Vector2(7,0),Color("b0a68f"),2,true)
		draw_line(center-Vector2(0,7),center+Vector2(0,7),Color("b0a68f"),2,true)
	if font and state.get("quantity",false):
		var quantity := "×%d" % int(state.get("count",0))
		var width := font.get_string_size(quantity,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
		draw_style_box(Art.box(Color("e9dfca"),Color.TRANSPARENT,3,0),Rect2(size-Vector2(width+8,20),Vector2(width+5,17)))
		draw_string(font,size-Vector2(width+6,6),quantity,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Art.INK)
	if unavailable and str(state.get("kind", "")) in ["lock_tool","door_key"]:
		var pos := Vector2(size.x-15,6)
		draw_arc(pos+Vector2(4,4),3,PI,TAU,12,Color("697367"),1.5,true)
		draw_rect(Rect2(pos+Vector2(0,4),Vector2(8,7)),Color("697367"),true)
	if drop_state != 0:
		var tint := Art.AMBER if drop_state > 0 else Color("d27b64")
		draw_style_box(Art.box(Color(tint,0.12),tint,5,0),Rect2(Vector2.ONE,size-Vector2.ONE*2))

func _gui_input(event: InputEvent):
	if not binding_mode or disabled: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		clear_requested.emit(index)
		accept_event()
	elif event is InputEventScreenTouch:
		touch_started = Time.get_ticks_msec() if event.pressed and not event.canceled else -1
		set_process(touch_started >= 0)

func _process(_delta: float):
	if touch_started >= 0 and Time.get_ticks_msec()-touch_started >= 650:
		touch_started = -1
		set_process(false)
		clear_requested.emit(index)

func _notification(what: int):
	if what == NOTIFICATION_DRAG_END: preview_drop(0)
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		touch_started = -1
		set_process(false)
