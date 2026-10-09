extends Control

var tutorial
var target_button: BaseButton
var card: Panel
var words: Label
var outline: StyleBoxFlat
var target_rect := Rect2()
var direction := Vector2.DOWN
var tip := Vector2.ZERO
var phase := 0.0
var redraw_timer := 0.0
var layout_key: Array = []

func configure(owner_tutorial):
	tutorial = owner_tutorial
	name = "TutorialButtonGuide"
	z_index = 261
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	card = Panel.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("f2ebdd")
	paper.border_color = Color("b89659")
	paper.set_border_width_all(1)
	paper.set_corner_radius_all(7)
	paper.shadow_color = Color(0,0,0,0.15)
	paper.shadow_size = 3
	card.add_theme_stylebox_override("panel",paper)
	add_child(card)
	words = Label.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_theme_font_override("font",tutorial.game.presentation.font)
	words.add_theme_font_size_override("font_size",14)
	words.add_theme_color_override("font_color",Color("303b46"))
	card.add_child(words)
	outline = StyleBoxFlat.new()
	outline.bg_color = Color(0,0,0,0)
	outline.border_color = Color("d5b16b")
	outline.set_border_width_all(2)
	outline.set_corner_radius_all(11)
	hide()

func refresh(prompt: Dictionary):
	target_button = prompt.get("button")
	visible = is_instance_valid(target_button) and target_button.is_visible_in_tree() and not target_button.disabled
	if not visible: return
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
		var transform: Transform2D = tutorial.game.get_global_transform_with_canvas()
		for actor in [tutorial.game.actors[0],tutorial.game.dialogue.current_target.get("node")]:
			if is_instance_valid(actor): blocked.append(Rect2(transform*actor.position-Vector2(22,64),Vector2(44,64)))
	var key := [safe,target_rect,text,blocked]
	if key==layout_key: return
	layout_key = key
	words.text = text
	var width := minf(220,safe.size.x-36)
	var text_height := maxf(22,ceilf(words.get_theme_font("font").get_multiline_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,width-24,14,-1,TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE).y))
	card.size = Vector2(width,text_height+20)
	words.position = Vector2(12,10)
	words.size = Vector2(width-24,text_height)
	var low := safe.position+Vector2(8,128)
	var high := (safe.end-card.size-Vector2(8,8)).max(low)
	var center := target_rect.get_center()
	var above := target_rect.position.y-card.size.y-28
	for obstacle in blocked:
		if obstacle.position.y<target_rect.position.y and obstacle.end.y>=above and obstacle.end.x>center.x-width/2 and obstacle.position.x<center.x+width/2:
			above = minf(above,obstacle.position.y-card.size.y-28)
	var candidates := [Vector2(center.x-width/2,above),Vector2(target_rect.position.x-width-28,center.y-card.size.y/2),Vector2(center.x-width/2,target_rect.end.y+28),Vector2(target_rect.end.x+28,center.y-card.size.y/2)]
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
			var stem := Rect2(point.min(point-direction*26),Vector2(0,26)).grow(4)
			if not controls.any(func(rect):return rect.intersects(stem)):
				tip = point
				break
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
	var color := Color(Color("d5b16b"),0.6+0.4*pulse)
	outline.border_color = color
	draw_style_box(outline,target_rect.grow(4+2*pulse))
	var length := 20+4*pulse
	var start := tip-direction*length
	draw_line(start,tip,color,3,true)
	var wing := direction.orthogonal()*6
	draw_line(tip-direction*7+wing,tip,color,3,true)
	draw_line(tip-direction*7-wing,tip,color,3,true)
