extends Node2D

var actor
var game
var definition: Dictionary
var texture: Texture2D
var frame_name: String = "idle"
var walk_clock: float = 0.0
var destination := Rect2()
var source_region := Rect2()
var skill_icons: Dictionary = {}
var font: Font
var is_guard: bool = false
var fx: Dictionary = {}
var flash_state: String = ""
var flash_time: float = 0
var flip_h: bool = false
var separate_information: bool = false

func configure(owner_actor, escape_game, asset: Dictionary, icons: Dictionary, text_font: Font) -> void:
	actor = owner_actor
	game = escape_game
	definition = asset
	texture = load(asset.texture)
	skill_icons = icons
	font = text_font
	is_guard = str(asset.actor_id) == "guard"
	tick_visual(0)

func tick_visual(delta: float) -> void:
	flash_time = maxf(0,flash_time-delta)
	visible = not actor.escaped
	if actor.moved_this_frame and game.phase == "playing" and not game.get_tree().paused:
		walk_clock += delta
		frame_name = "walk_a" if int(walk_clock / float(definition.initial_walk_frame_seconds)) % 2 == 0 else "walk_b"
	else:
		walk_clock = 0
		frame_name = "idle"
	var region: Array = definition.frames[frame_name]
	var anchor: Array = definition.anchor[frame_name]
	source_region = Rect2(region[0],region[1],region[2],region[3])
	var ratio: float = float(definition.world_height) / source_region.size.y
	destination = Rect2(-Vector2(anchor[0],anchor[1])*ratio,source_region.size*ratio)
	if absf(actor.facing.x) > 0.08:
		flip_h = actor.facing.x < 0
	queue_redraw()

func _draw() -> void:
	if not texture or not visible:
		return
	if not separate_information:
		draw_ellipse(Vector2(0,2),15,4,Color(0,0,0,0.12))
	# Mirror only the body about its registered foot origin. UI and facing
	# overlays stay in world orientation, including asymmetric frame anchors.
	if flip_h:
		draw_set_transform(Vector2.ZERO,0,Vector2(-1,1))
	draw_texture_rect_region(texture,destination,source_region)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	if not separate_information:
		paint_information(self)

func paint_information(canvas: CanvasItem) -> void:
	var top: float = -float(definition.world_height)-10
	if separate_information and not is_guard and actor.selected:
		canvas.draw_arc(Vector2.ZERO,23,0,TAU,40,Color("328b82"),3,true)
	var direction_color := Color("c9534b") if is_guard and actor.state == "chasing" else Color("303b46") if is_guard else Color("328b82")
	if is_guard and actor.state != "chasing" and game.presentation and game.presentation.lighting and game.presentation.lighting.period == "night":
		direction_color = Color("e5dfce")
	canvas.draw_line(actor.facing*18,actor.facing*31,direction_color,3,true)
	canvas.draw_line(actor.facing*31,actor.facing*25+actor.facing.orthogonal()*4,direction_color,2,true)
	canvas.draw_line(actor.facing*31,actor.facing*25-actor.facing.orthogonal()*4,direction_color,2,true)
	if is_guard:
		if separate_information:
			var label := "追击！" if actor.state == "chasing" else "交谈中" if actor.state == "talking" else "巡逻"
			canvas.draw_string(font,Vector2(-22,top),label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,direction_color)
		if actor.state == "chasing" and not fx.is_empty():
			var symbol := "searching" if actor.lost_time > 0 else "detected"
			canvas.draw_texture_rect(fx[symbol],Rect2(16,top-15,24,24),false)
	if not is_guard:
		canvas.draw_circle(Vector2(0,12),9,Color("f2ebdd"))
		canvas.draw_string(font,Vector2(-4,17),str(actor.actor_id+1),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("303b46"))
		if actor.action_state != "idle":
			canvas.draw_circle(Vector2(20,top-2),15,Color("f2ebdd"))
			canvas.draw_texture_rect(skill_icons[actor.skill_id],Rect2(8,top-14,24,24),false)
		if game.elapsed < actor.immune_until:
			canvas.draw_arc(Vector2.ZERO,20,0,TAU,32,Color("c9534b"),2,true)
		if flash_time > 0 and fx.has(flash_state):
			canvas.draw_texture_rect(fx[flash_state],Rect2(-36,top-14,24,24),false)

func show_event(state: String) -> void:
	flash_state = state
	flash_time = 1.3
	queue_redraw()

func body_bounds() -> Rect2:
	return Rect2(Vector2(-destination.end.x,destination.position.y),destination.size) if flip_h else destination

func snapshot() -> Dictionary:
	return {"frame":frame_name,"region":[source_region.position.x,source_region.position.y,source_region.size.x,source_region.size.y],"destination":[destination.position.x,destination.position.y,destination.size.x,destination.size.y],"world_height":definition.world_height,"visible":visible,"flip_h":flip_h}
