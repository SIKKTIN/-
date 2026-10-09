extends Control

class SpeechButton extends Button:
	func _draw():
		draw_circle(Vector2(17,22),4,Color("c49c5f"),true,-1,true)
		draw_line(Vector2(14,34),Vector2(154,34),Color("b8b8a7"),1,true)

var tutorial
var bubble: Button
var name_label: Label
var words: Label
var page_label: Label
var continue_label: Label
var mouth := Vector2.ZERO
var tail := PackedVector2Array()
var text_layout_key: Array = []
var text_height := 27.0

func configure(owner_tutorial):
	tutorial = owner_tutorial
	name = "TutorialSpeech"
	z_index = 151
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble = SpeechButton.new()
	bubble.name = "ContinueTutorialSpeech"
	bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	bubble.focus_mode = Control.FOCUS_NONE
	bubble.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bubble.pressed.connect(_advance)
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("f2ebdd")
	paper.border_color = Color("68796c")
	paper.set_border_width_all(1)
	paper.set_corner_radius_all(8)
	paper.shadow_color = Color(0,0,0,0.15)
	paper.shadow_size = 4
	for state in ["normal","hover","pressed","disabled","focus"]:
		bubble.add_theme_stylebox_override(state,paper)
	add_child(bubble)
	name_label = _label(16)
	words = _label(17)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page_label = _label(12)
	page_label.add_theme_color_override("font_color",Color("778174"))
	continue_label = _label(12)
	continue_label.add_theme_color_override("font_color",Color("778174"))
	hide()

func _advance():
	if not visible or not tutorial.ui_visible() or tutorial.game.get_tree().paused: return
	tutorial.continue_lesson()
	tutorial._refresh()

func _label(size: int) -> Label:
	var result := Label.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_override("font",tutorial.game.presentation.font)
	result.add_theme_font_size_override("font_size",size)
	result.add_theme_color_override("font_color",Color("303b46"))
	bubble.add_child(result)
	return result

func refresh():
	var actor = tutorial.presenter()
	visible = tutorial.speaking() and is_instance_valid(actor) and tutorial.ui_visible()
	if not visible: return
	var safe: Rect2 = tutorial.game.fullscreen_ui.safe_area()
	var width := minf(352,safe.size.x-40)
	name_label.text = tutorial.presenter_name()
	words.text = tutorial.current_line()
	var text_key := [words.text,width]
	if text_key!=text_layout_key:
		text_height = words.get_theme_font("font").get_multiline_string_size(words.text,HORIZONTAL_ALIGNMENT_LEFT,width-28,17,-1,TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE).y
		text_height = maxf(27,ceilf(text_height))
		text_layout_key = text_key
	bubble.size = Vector2(width,text_height+76)
	name_label.position = Vector2(26,9)
	name_label.size = Vector2(width-40,25)
	words.position = Vector2(14,39)
	words.size = Vector2(width-28,text_height)
	page_label.position = Vector2(width-90,bubble.size.y-25)
	page_label.size = Vector2(76,18)
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	continue_label.position = Vector2(14,bubble.size.y-25)
	continue_label.size = Vector2(width-118,18)
	words.visible_characters = mini(words.text.length(),floori(tutorial.text_revealed))
	continue_label.text = "点击继续" if tutorial.text_revealed>=words.text.length() else "点击显示全文"
	page_label.text = "%d/%d ▾" % [tutorial.line_index+1,tutorial.lines.size()]
	# Position from the real actor's foot anchor after the camera moved.
	# Keep the speech inside the play area, away from the clock and minimap.
	mouth = tutorial.game.get_global_transform_with_canvas()*actor.position+Vector2(0,-48)
	var low := Vector2(safe.position.x+18,safe.position.y+128)
	var high := Vector2(safe.end.x-width-18,safe.end.y-bubble.size.y-18)
	high = high.max(low)
	bubble.position = (mouth-Vector2(width/2,bubble.size.y+22)).clamp(low,high)
	var player_foot: Vector2 = tutorial.game.get_global_transform_with_canvas()*tutorial.game.actors[0].position
	var host_foot: Vector2 = mouth+Vector2(0,48)
	var bodies := [Rect2(player_foot-Vector2(22,64),Vector2(44,64)),Rect2(host_foot-Vector2(22,64),Vector2(44,64))]
	if bodies.any(func(rect): return rect.intersects(bubble.get_rect())):
		for candidate in [Vector2(mouth.x+42,mouth.y-92),Vector2(mouth.x-width-42,mouth.y-92)]:
			var position: Vector2 = candidate.clamp(low,high)
			if not bodies.any(func(rect): return rect.intersects(Rect2(position,bubble.size))):
				bubble.position = position
				break
	var edge := Vector2(clampf(mouth.x,bubble.position.x+24,bubble.position.x+width-24),bubble.get_rect().end.y-1)
	var side := Vector2(8,0)
	if mouth.x<bubble.position.x or mouth.x>bubble.get_rect().end.x:
		edge = Vector2(bubble.position.x+1 if mouth.x<bubble.position.x else bubble.get_rect().end.x-1,clampf(mouth.y,bubble.position.y+20,bubble.get_rect().end.y-20))
		side = Vector2(0,8)
	var next_tail := PackedVector2Array([edge-side,edge+side,mouth])
	if tail!=next_tail:
		tail = next_tail
		queue_redraw()

func _draw():
	if visible and tail.size()==3:
		draw_colored_polygon(tail,Color("f2ebdd"))
		draw_line(tail[0],tail[2],Color("68796c"),2,true)
		draw_line(tail[2],tail[1],Color("68796c"),2,true)
