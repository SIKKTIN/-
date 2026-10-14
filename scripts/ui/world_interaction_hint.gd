extends Button

const INK := Color("303b46")
const PAPER := Color("eee8d7")
var title := ""
var action := ""
var target_key := ""
var status_text := ""
var action_enabled := true
var pointer := Vector2.ZERO
var hand: Texture2D = preload("res://art/ui/fullscreen/interaction_hint.svg")
var font: Font

func _ready():
	focus_mode = Control.FOCUS_NONE
	z_index = 55
	for state in ["normal","hover","pressed","disabled","focus"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	hide()

func set_content(name_text: String, action_text: String, key: String, status: String="", enabled:=true):
	if [title,action,target_key,status_text,action_enabled] == [name_text,action_text,key,status,enabled]: return
	status_text=status
	action_enabled=enabled
	disabled=not enabled
	title = name_text
	action = action_text
	target_key = key
	size = Vector2(clampf(maxf(font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+62,font.get_string_size(action,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+66),164,270),74)
	if not status_text.is_empty():
		size.x=clampf(maxf(size.x,font.get_string_size(status_text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+40),210,340)
		size.y=103
	queue_redraw()

func place(target: Rect2, view: Rect2, avoid: Array):
	var safe := view.grow(-12)
	var above := target.position.y-size.y-14
	var candidates := [Vector2(target.get_center().x-size.x/2,above),Vector2(target.position.x-size.x+24,above),Vector2(target.end.x-24,above),Vector2(target.get_center().x-size.x/2,target.end.y+14),Vector2(target.end.x+14,target.get_center().y-size.y/2),Vector2(target.position.x-size.x-14,target.get_center().y-size.y/2)]
	var best := Vector2.ZERO
	var score := INF
	for candidate in candidates:
		var point: Vector2 = candidate.clamp(safe.position,(safe.end-size).max(safe.position))
		var rect := Rect2(point,size).grow(4)
		var overlap := 0.0
		for obstacle: Rect2 in avoid:
			var cut := rect.intersection(obstacle)
			overlap += cut.get_area()
		if overlap < score:
			score = overlap
			best = point
	position = best
	var local := target.get_center()-position
	var next_pointer: Vector2
	if local.y > size.y: next_pointer = Vector2(clampf(local.x,20,size.x-20),size.y+12)
	elif local.y < 0: next_pointer = Vector2(clampf(local.x,20,size.x-20),-12)
	elif local.x > size.x: next_pointer = Vector2(size.x+12,clampf(local.y,18,size.y-18))
	else: next_pointer = Vector2(-12,clampf(local.y,18,size.y-18))
	if pointer != next_pointer:
		pointer = next_pointer
		queue_redraw()

func _draw():
	if not font: return
	var fill := Color("f7efda") if is_hovered() else PAPER
	if is_pressed(): fill = Color("ddd4bd")
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = Color("687469")
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.shadow_color = Color(0,0,0,0.3)
	box.shadow_size = 4
	box.shadow_offset = Vector2(0,3)
	draw_style_box(box,Rect2(Vector2.ZERO,size))
	var base: Vector2
	var side: Vector2
	if pointer.y > size.y or pointer.y < 0:
		base = Vector2(pointer.x,size.y if pointer.y > size.y else 0)
		side = Vector2(9,0)
	else:
		base = Vector2(size.x if pointer.x > size.x else 0,pointer.y)
		side = Vector2(0,9)
	draw_colored_polygon(PackedVector2Array([base-side,base+side,pointer]),fill)
	draw_polyline(PackedVector2Array([base-side,pointer,base+side]),box.border_color,2,true)
	var seam := StyleBoxFlat.new()
	seam.bg_color = Color.TRANSPARENT
	seam.border_color = Color("b7b9a5")
	seam.set_border_width_all(1)
	seam.set_corner_radius_all(5)
	draw_style_box(seam,Rect2(5,5,size.x-10,size.y-10))
	draw_string(font,Vector2(13,28),title,HORIZONTAL_ALIGNMENT_LEFT,size.x-56,16,INK)
	draw_texture_rect(hand,Rect2(size.x-37,12,22,22),false)
	if not status_text.is_empty():
		var tone:=Color("217d76") if action_enabled else Color("a6632f")
		draw_circle(Vector2(20,45),7,tone)
		draw_string(font,Vector2(17,49),"✓" if action_enabled else "!",HORIZONTAL_ALIGNMENT_LEFT,12,12,PAPER)
		draw_string(font,Vector2(33,50),status_text,HORIZONTAL_ALIGNMENT_LEFT,size.x-46,14,tone)
		draw_set_transform(Vector2(0,29))
	draw_line(Vector2(13,37),Vector2(size.x-13,37),Color("c8c5b2"),1)
	var key := StyleBoxFlat.new()
	key.bg_color = INK if action_enabled else Color("a08765")
	key.set_corner_radius_all(4)
	draw_style_box(key,Rect2(13,44,27,22))
	draw_string(font,Vector2(21,61),"E" if action_enabled else "×",HORIZONTAL_ALIGNMENT_LEFT,24,16,PAPER)
	draw_string(font,Vector2(50,62),action,HORIZONTAL_ALIGNMENT_LEFT,size.x-61,16,INK)
