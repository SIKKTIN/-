extends Control

var tutorial
var target_button: BaseButton
var card: Panel
var words: Label
var heading: Label
var detail: Label
var outline: StyleBoxFlat
var target_rect := Rect2()
var direction := Vector2.DOWN
var tip := Vector2.ZERO
var phase := 0.0
var redraw_timer := 0.0
var layout_key: Array = []
var close_hint := false

func configure(owner_tutorial):
	tutorial = owner_tutorial
	name = "TutorialButtonGuide"
	z_index = 261
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	card = Panel.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("263d42")
	paper.border_color = Color("ffcf70")
	paper.set_border_width_all(2)
	paper.set_corner_radius_all(9)
	paper.shadow_color = Color(0,0,0,0.3)
	paper.shadow_size = 6
	card.add_theme_stylebox_override("panel",paper)
	add_child(card)
	words = Label.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_theme_font_override("font",tutorial.game.presentation.font)
	words.add_theme_font_size_override("font_size",22)
	words.add_theme_color_override("font_color",Color("fff9ed"))
	card.add_child(words)
	heading = Label.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.text = "下一步"
	heading.add_theme_font_override("font",tutorial.game.presentation.font)
	heading.add_theme_font_size_override("font_size",14)
	heading.add_theme_color_override("font_color",Color("ffcf70"))
	card.add_child(heading)
	detail = Label.new()
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_override("font",tutorial.game.presentation.font)
	detail.add_theme_font_size_override("font_size",16)
	detail.add_theme_color_override("font_color",Color("e2e9df"))
	card.add_child(detail)
	outline = StyleBoxFlat.new()
	outline.border_color = Color("ffcf70")
	outline.set_border_width_all(4)
	outline.set_corner_radius_all(11)
	outline.shadow_color = Color(1,0.72,0.25,0.28)
	outline.shadow_size = 8
	hide()

func refresh(prompt: Dictionary):
	target_button = prompt.get("button")
	visible = is_instance_valid(target_button) and target_button.is_visible_in_tree() and not target_button.disabled
	if not visible: return
	close_hint = target_button==tutorial.game.dialogue.end_button
	var safe: Rect2 = tutorial.game.fullscreen_ui.safe_area()
	target_rect = target_button.get_global_rect()
	var text: String = str(prompt.get("text",""))
	var blocked := [target_rect.grow(6),tutorial.panel.get_global_rect(),tutorial.game.mobile_controls.pad.get_global_rect()]
	var controls: Array[Rect2] = []
	for control in [tutorial.game.fullscreen_ui.bag_button,tutorial.game.fullscreen_ui.ability_button,tutorial.game.fullscreen_ui.action_button,tutorial.game.fullscreen_ui.target_button]:
		if control!=target_button and control.is_visible_in_tree():
			controls.append(control.get_global_rect())
			blocked.append(control.get_global_rect())
	if tutorial.game.dialogue.panel.visible:
		blocked.append(tutorial.game.dialogue.panel.get_global_rect())
		blocked.append(tutorial.game.dialogue.responses.get_global_rect())
		for control in [tutorial.game.dialogue.casual_button,tutorial.game.dialogue.rules_button,tutorial.game.dialogue.special_button]:
			controls.append(control.get_global_rect())
		var transform: Transform2D = tutorial.game.get_global_transform_with_canvas()
		for actor in [tutorial.game.actors[0],tutorial.game.dialogue.current_target.get("node")]:
			if is_instance_valid(actor): blocked.append(Rect2(transform*actor.position-Vector2(22,64),Vector2(44,64)))
	var key := [safe,target_rect,text,blocked]
	if key==layout_key: return
	layout_key = key
	var lines := text.split("\n",true,1)
	words.text = lines[0]
	detail.text = lines[1] if lines.size()>1 else ""
	var width := minf(240 if close_hint else 264,safe.size.x-36)
	var text_width := width-32
	var flags := TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE
	var font := words.get_theme_font("font")
	var text_height := maxf(30,ceilf(font.get_multiline_string_size(words.text,HORIZONTAL_ALIGNMENT_LEFT,text_width,22,-1,flags).y))
	var detail_height := maxf(22,ceilf(font.get_multiline_string_size(detail.text,HORIZONTAL_ALIGNMENT_LEFT,text_width,16,-1,flags).y))
	card.size = Vector2(width,36+text_height+6+detail_height+14)
	heading.position = Vector2(16,10)
	heading.size = Vector2(text_width,20)
	words.position = Vector2(16,36)
	words.size = Vector2(text_width,text_height)
	detail.position = Vector2(16,words.position.y+text_height+6)
	detail.size = Vector2(text_width,detail_height)
	var low := safe.position+Vector2(8,128)
	var high := (safe.end-card.size-Vector2(8,8)).max(low)
	var center := target_rect.get_center()
	var gap := 56.0
	var above := target_rect.position.y-card.size.y-gap
	for obstacle in blocked:
		if obstacle.position.y<target_rect.position.y and obstacle.end.y>=above and obstacle.end.x>center.x-width/2 and obstacle.position.x<center.x+width/2:
			above = minf(above,obstacle.position.y-card.size.y-gap)
	var candidates := [Vector2(center.x-width/2,above),Vector2(target_rect.position.x-width-gap,center.y-card.size.y/2),Vector2(center.x-width/2,target_rect.end.y+gap),Vector2(target_rect.end.x+gap,center.y-card.size.y/2)]
	if close_hint:
		var speech: Rect2 = tutorial.game.dialogue.panel.get_global_rect()
		var near := low.x if speech.get_center().x<safe.get_center().x else high.x
		var far := high.x if near==low.x else low.x
		candidates.append(Vector2(near,speech.end.y+28))
		candidates.append(Vector2(far,speech.end.y+28))
		candidates.append(low)
	var best := INF
	for candidate in candidates:
		var point: Vector2 = candidate.clamp(low,high)
		var rect := Rect2(point,card.size)
		var score: float = point.distance_to(candidate)
		for obstacle in blocked:
			if rect.intersects(obstacle): score += 10000+rect.intersection(obstacle).get_area()
		if score<best:
			best = score
			card.position = point
	var difference: Vector2 = center-card.get_rect().get_center()
	if absf(difference.x)>absf(difference.y):
		direction = Vector2(signf(difference.x),0)
		tip = Vector2(target_rect.position.x-8 if direction.x>0 else target_rect.end.x+8,center.y)
	else:
		direction = Vector2(0,signf(difference.y))
		tip = Vector2(center.x,target_rect.position.y-8 if direction.y>0 else target_rect.end.y+8)
		for x in [center.x,target_rect.end.x-10,target_rect.position.x+10]:
			var point := Vector2(x,tip.y)
			var stem := Rect2(point.min(point-direction*42),Vector2(0,42)).grow(12)
			if not controls.any(func(rect):return rect.intersects(stem)):
				tip = point
				break
	if close_hint:
		# Approach the speech header from outside, keeping the arrow off the words.
		var speech: Rect2 = tutorial.game.dialogue.panel.get_global_rect()
		if speech.end.x+54<=safe.end.x:
			direction = Vector2.LEFT
			tip = Vector2(speech.end.x+8,center.y)
		else:
			direction = Vector2.DOWN
			tip = Vector2(center.x,target_rect.position.y-8)
	queue_redraw()

func _process(delta: float):
	refresh(tutorial.button_prompt())
	if not visible: return
	phase = fmod(phase+maxf(delta,0)*4,TAU)
	redraw_timer -= maxf(delta,0)
	if redraw_timer<=0:
		redraw_timer = 0.05
		queue_redraw()

func _draw():
	if not visible: return
	var pulse := (sin(phase)+1)/2
	var gold := Color("ffcf70")
	outline.bg_color = Color(gold,0.12+0.08*pulse)
	draw_style_box(outline,target_rect.grow(4+2*pulse))
	var arrow_tip := tip-direction*(2+5*(1-pulse))
	var start := arrow_tip-direction*38
	var source: Vector2
	if not close_hint and direction.y!=0:
		source = Vector2(clampf(start.x,card.position.x+12,card.position.x+card.size.x-12),card.position.y+card.size.y if direction.y>0 else card.position.y)
		var corner := Vector2(start.x,source.y)
		_dashes(source,corner,gold)
		_dashes(corner,start,gold)
	elif not close_hint:
		source = Vector2(card.position.x+card.size.x if direction.x>0 else card.position.x,clampf(start.y,card.position.y+12,card.position.y+card.size.y-12))
		var corner := Vector2(source.x,start.y)
		_dashes(source,corner,gold)
		_dashes(corner,start,gold)
	var side := direction.orthogonal()
	var arrow := PackedVector2Array([start-side*5,start+side*5,arrow_tip-direction*16+side*5,arrow_tip-direction*16+side*13,arrow_tip,arrow_tip-direction*16-side*13,arrow_tip-direction*16-side*5])
	draw_colored_polygon(arrow,gold)
	var edge := PackedVector2Array(arrow)
	edge.append(arrow[0])
	draw_polyline(edge,Color("263d42"),2,true)
	if target_rect.size.x>=70 and target_rect.size.y>=60:
		var finger := Vector2(target_rect.end.x-27,target_rect.position.y+17+3*(1-pulse))
		var ripple := phase/TAU
		draw_arc(finger,8+16*ripple,0,TAU,24,Color(gold,0.85*(1-ripple)),3,true)
		var hand := PackedVector2Array([Vector2(0,0),Vector2(-3,2),Vector2(-3,17),Vector2(-8,13),Vector2(-11,14),Vector2(-12,18),Vector2(-4,29),Vector2(0,31),Vector2(12,31),Vector2(16,26),Vector2(16,14),Vector2(13,11),Vector2(10,11),Vector2(7,9),Vector2(4,10),Vector2(4,2),Vector2(2,0)])
		for i in hand.size(): hand[i] += finger
		draw_colored_polygon(hand,Color("fff9ed"))
		hand.append(hand[0])
		draw_polyline(hand,Color("263d42"),2,true)

func _dashes(start: Vector2, end: Vector2, color: Color):
	var length := start.distance_to(end)
	if length<1: return
	var tangent := (end-start)/length
	var offset := 0.0
	while offset<length:
		draw_line(start+tangent*offset,start+tangent*minf(offset+6,length),color,2,true)
		offset += 11
