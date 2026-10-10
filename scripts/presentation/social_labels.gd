extends Node2D

var game
var timer := 0.0

func configure(owner_game):
	game = owner_game
	z_index = 85

func _process(delta: float):
	timer -= delta
	if timer<=0:
		timer = 0.2
		queue_redraw()

func _draw():
	if not game or not game.social: return
	var view: Rect2 = game.map_camera.world_view_rect().grow(60) if game.map_camera else game.world.bounds
	for id in game.social.people:
		var p: Dictionary = game.social.people[id]
		if p.role=="player" or not is_instance_valid(p.node) or not p.node.visible or p.node.escaped or not view.has_point(p.node.position) or game.world.is_under_roof(p.node.position): continue
		var text: String = p.name+" · "+game.social.mood_name(id)
		if game.social.now<p.line_until: text = p.name+" · "+str(p.get("activity","与你交谈"))
		var font: Font = game.presentation.font
		var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
		var point: Vector2 = p.node.position+Vector2(-width/2,-100)
		draw_string_outline(font,point,text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,3,Color(0.93,0.9,0.82,0.85))
		draw_string(font,point,text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("354d4a"))
