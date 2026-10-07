extends Node2D

const WorldTexture = preload("res://scripts/presentation/world_texture.gd")

var actor
var game
var definition: Dictionary
var texture: Texture2D
var idle_texture: Texture2D
var walk_textures: Array[Texture2D] = []
var walk_frames: Array = []
var walk_fps: float = 12.0
var walk_scale_height: float = 0.0
var walk_frame_index: int = -1
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
var working := false
var work_clock := 0.0
var meal_clock := 0.0

func configure(owner_actor, escape_game, asset: Dictionary, icons: Dictionary, text_font: Font) -> void:
	actor = owner_actor
	game = escape_game
	definition = asset
	texture = load(asset.texture)
	idle_texture = texture
	var animation: Dictionary = asset.get("walk_animation",{})
	if animation.has("texture") and ResourceLoader.exists(animation.texture) and animation.get("frames",[]).size() > 1:
		walk_frames = animation.frames
		walk_fps = clampf(float(animation.get("fps",12)),1,60)
		walk_scale_height = float(animation.get("scale_height",walk_frames[0].region[3]))
		for frame in walk_frames:
			walk_textures.append(WorldTexture.load_asset({"texture":animation.texture,"region":frame.region}))
		if walk_scale_height <= 0 or walk_textures.any(func(t): return t == null):
			walk_frames = []
			walk_textures.clear()
			push_warning("Walk texture unavailable; retaining legacy animation for "+str(asset.actor_id))
	skill_icons = icons
	font = text_font
	is_guard = str(asset.actor_id) == "guard"
	tick_visual(0)

func tick_visual(delta: float, camera_view: Rect2 = Rect2()) -> void:
	var on_screen: bool = not camera_view.has_area() or camera_view.grow(100).has_point(actor.position)
	visible = on_screen and not actor.escaped and not game.world.is_under_roof(actor.position)
	if game.get_tree().paused:
		return
	flash_time = maxf(0,flash_time-delta)
	working = not is_guard and game.routines != null and game.routines.is_working(actor.actor_id)
	work_clock = fposmod(work_clock+maxf(0,delta)*TAU/0.8,TAU) if working else 0.0
	meal_clock = fposmod(meal_clock+maxf(0,delta)*TAU/1.1,TAU) if not is_guard and game.routines != null and game.routines.is_eating(actor.actor_id) else 0.0
	var moving: bool = actor.moved_this_frame and not actor.escaped and game.phase == "playing"
	walk_frame_index = -1
	if moving and not walk_frames.is_empty():
		var cycle: float = walk_frames.size()/walk_fps
		walk_clock = fposmod(walk_clock+maxf(delta,0),cycle)
		walk_frame_index = mini(int(walk_clock*walk_fps),walk_frames.size()-1)
		frame_name = str(walk_frames[walk_frame_index].id)
	elif moving:
		walk_clock = fposmod(walk_clock+maxf(delta,0),2*float(definition.initial_walk_frame_seconds))
		frame_name = "walk_a" if int(walk_clock / float(definition.initial_walk_frame_seconds)) % 2 == 0 else "walk_b"
	else:
		walk_clock = 0
		frame_name = "idle"
	if not visible: return
	var anchor: Array
	var scale_height: float
	if walk_frame_index >= 0:
		var frame: Dictionary = walk_frames[walk_frame_index]
		texture = walk_textures[walk_frame_index]
		source_region = Rect2(0,0,frame.region[2],frame.region[3])
		anchor = frame.anchor
		scale_height = walk_scale_height
	else:
		texture = idle_texture
		var region: Array = definition.frames[frame_name]
		anchor = definition.anchor[frame_name]
		source_region = Rect2(region[0],region[1],region[2],region[3])
		scale_height = source_region.size.y
	var ratio: float = float(definition.world_height) / scale_height
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
	var labor_bob: float = maxf(0, sin(work_clock))*1.3 if working else 0.0
	var labor_lean: float = sin(work_clock)*0.035 if working else 0.0
	draw_set_transform(Vector2(0,labor_bob),labor_lean,Vector2(-1 if flip_h else 1,1))
	draw_texture_rect_region(texture,destination,source_region)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	if working:
		_paint_work_tool()
	if not is_guard and game.routines and game.routines.carries_meal(actor.actor_id):
		var tray: Texture2D = game.world.art_textures.get("cafeteria_tray")
		if tray:
			draw_texture_rect(tray,Rect2(-17,-30,34,19),false)
		if game.routines.is_eating(actor.actor_id):
			var hand := Vector2(15,-28-absf(sin(meal_clock))*10)
			draw_line(Vector2(12,-30),hand,Color("dfb27f"),3,true)
			draw_line(hand,hand+Vector2(-5,-4),Color("9aa29a"),2,true)
	if not separate_information:
		paint_information(self)

func _paint_work_tool() -> void:
	var side := -1.0 if flip_h else 1.0
	var hand := Vector2(side*14,-float(definition.world_height)*0.47)
	draw_set_transform(hand,side*(-0.5+sin(work_clock)*0.65),Vector2(side,1))
	draw_line(Vector2(0,7),Vector2(0,-9),Color("303b46"),5,true)
	draw_line(Vector2(0,7),Vector2(0,-9),Color("b89258"),2,true)
	draw_rect(Rect2(-7,-14,14,7),Color("303b46"))
	draw_rect(Rect2(-6,-13,12,4),Color("8f9b94"))
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	if sin(work_clock) > 0.72:
		var contact := hand+Vector2(side*8,4)
		for direction in [Vector2(side*7,-6),Vector2(side*10,0),Vector2(side*4,7)]:
			draw_line(contact+direction*0.5,contact+direction,Color("d3a252"),2,true)

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
			var label := "交谈中" if actor.state == "talking" else "追击！" if actor.state == "chasing" else ("警戒守门" if actor.labor_enforcement() else "守门") if actor.has_method("is_gate_guard") else "调查" if actor.state == "searching" else "查寝" if game.schedule and game.schedule.is_sleep_time() else "宵禁警戒" if actor.curfew_alert() else "劳动警戒" if actor.labor_enforcement() else "巡逻"
			if actor.global_alert():
				label = "追击！" if actor.state == "chasing" else "交谈中" if actor.state == "talking" else "增援搜查" if actor in game.prison_alert.reinforcements else "警戒搜查"
			if actor.has_method("is_workshop_overseer"):
				label = "监工追捕！" if actor.state == "chasing" else "监工 · 查岗"
			if game.staff_traffic:
				var commute: String = game.staff_traffic.label(actor)
				if not commute.is_empty(): label = commute
			canvas.draw_string(font,Vector2(-22,top),label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,direction_color)
		if actor.state == "chasing" and not fx.is_empty():
			var symbol := "searching" if actor.lost_time > 0 else "detected"
			canvas.draw_texture_rect(fx[symbol],Rect2(16,top-15,24,24),false)
	if not is_guard:
		canvas.draw_circle(Vector2(0,12),9,Color("f2ebdd"))
		canvas.draw_string(font,Vector2(-4,17),str(actor.actor_id+1),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("303b46"))
		if game.schedule and game.schedule.is_sleeping(actor.actor_id):
			canvas.draw_string(font,Vector2(14,top),"Zz",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("d8e8dc"))
		if actor.confined and game.room_access:
			canvas.draw_string(font,Vector2(-40,top),game.room_access.label_for(actor.actor_id),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("bc5348"))
		elif game.workshop and not game.workshop.warning_label(actor.actor_id).is_empty():
			canvas.draw_string(font,Vector2(-60,top-26),game.workshop.warning_label(actor.actor_id),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("bc5348"))
		if game.routines and game.routines.is_working(actor.actor_id):
			var progress: float = game.routines.work_progress(actor.actor_id)
			var text := "工作中 %d%%" % floori(progress*100+0.000001)
			var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+16
			canvas.draw_style_box(_work_paper(),Rect2(-width/2,top-20,width,25))
			canvas.draw_string(font,Vector2(-width/2+8,top-2),text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("303b46"))
			canvas.draw_rect(Rect2(-width/2,top+7,width,4),Color("cdd4c3"))
			canvas.draw_rect(Rect2(-width/2,top+7,width*progress,4),Color("c69c5e"))
		elif game.routines and game.routines.is_eating(actor.actor_id):
			canvas.draw_style_box(_work_paper(),Rect2(-30,top-20,60,25))
			canvas.draw_string(font,Vector2(-21,top-2),"用餐中",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("303b46"))
			canvas.draw_rect(Rect2(-24,top+5,48,4),Color("cdd4c3"))
			canvas.draw_rect(Rect2(-24,top+5,48*game.attributes.values[actor.actor_id].fullness/100.0,4),Color("c69c5e"))
		elif game.routines and game.routines.is_lawful(actor.actor_id):
			canvas.draw_string(font,Vector2(-20,top),game.routines.NAMES[game.routines.records[actor.actor_id].kind],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("328b82"))
		if game.routines and game.routines.recent_wages.has(actor.actor_id):
			var payment: Dictionary = game.routines.recent_wages[actor.actor_id]
			if game.elapsed < payment.until:
				var rise: float = (game.elapsed-(payment.until-2.4))*8
				var text := "工资 +%d" % payment.amount
				var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+16
				canvas.draw_style_box(_work_paper(),Rect2(-width/2,top-49-rise,width,25))
				canvas.draw_string(font,Vector2(-width/2+8,top-31-rise),text,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("977037"))
		if actor.action_state != "idle":
			canvas.draw_circle(Vector2(20,top-2),15,Color("f2ebdd"))
			var icon: Texture2D = skill_icons.get("lockpick" if actor.action_state == "lockpicking" else "chat")
			if icon:
				canvas.draw_texture_rect(icon,Rect2(8,top-14,24,24),false)
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

func _work_paper() -> StyleBoxFlat:
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("f2ebdd")
	paper.border_color = Color("b7bca5")
	paper.set_border_width_all(1)
	paper.set_corner_radius_all(5)
	return paper

func snapshot() -> Dictionary:
	return {"frame":frame_name,"frame_index":walk_frame_index,"walk_frame_count":walk_frames.size() if not walk_frames.is_empty() else 2,"walk_fps":walk_fps if not walk_frames.is_empty() else 1.0/float(definition.initial_walk_frame_seconds),"region":[source_region.position.x,source_region.position.y,source_region.size.x,source_region.size.y],"destination":[destination.position.x,destination.position.y,destination.size.x,destination.size.y],"world_height":definition.world_height,"visible":visible,"flip_h":flip_h}
