extends Node2D

const Library = preload("res://scripts/presentation/character_library.gd")
const WorldScale = preload("res://scripts/core/world_scale.gd")
const Depth = preload("res://scripts/presentation/world_depth.gd")
var game
var spec: Dictionary
var definition: Dictionary
var motion: Dictionary
var route: Array = []
var target_index := 0
var waiting := 0.0
var walk_clock := 0.0
var frame_index := -1
var moving := false
var flip_h := false
var sprite: Texture2D
var sprite_rect := Rect2()
var caption: Label
var service_pose: String=""
var service_remaining: float=0
var service_textures: Dictionary={} 

func configure(owner_game, config: Dictionary) -> void:
	game = owner_game
	spec = config.duplicate(true)
	position = Vector2(spec.position[0],spec.position[1])
	var appearance: String = game.room_config.get("character_appearances",{}).get("resident:"+str(spec.id),spec.get("appearance_id","clinic_medic"))
	definition = Library.all().get(appearance,{})
	motion = Library.motion(appearance)
	route = spec.get("patrol",[]).duplicate(true)
	waiting = float(spec.get("wait_seconds",7))
	material = game.presentation.character_material
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	caption = Label.new()
	caption.text = str(spec.get("name","医务人员"))
	caption.add_theme_font_override("font",game.presentation.font)
	caption.add_theme_font_size_override("font_size",12)
	caption.add_theme_color_override("font_color",Color("354d4a"))
	caption.add_theme_color_override("font_outline_color",Color("eee8d6"))
	caption.add_theme_constant_override("outline_size",3)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.z_as_relative = false
	caption.z_index = 2000
	caption.position = Vector2(-32,-103)
	add_child(caption)
	tick(0)

func tick(delta: float) -> void:
	var old_frame := frame_index
	moving = false
	var minute: float = game.schedule.clock_minutes() if game.schedule else 480
	var on_duty: bool = minute >= float(spec.get("work_start",480)) and minute < float(spec.get("work_end",1200))
	if on_duty and route.size()>1 and game.phase == "playing":
		waiting = maxf(0,waiting-delta)
		if waiting <= 0:
			var coordinates: Array = route[target_index]
			var goal := Vector2(coordinates[0],coordinates[1])
			var next := position.move_toward(goal,float(spec.get("speed",36))*delta)
			var clear: bool = game.world.can_place_circle(next,game.ACTOR_RADIUS,null,false)
			if clear and next.distance_to(game.actors[0].position)>24:
				var direction := next-position
				moving = direction.length_squared()>0.0001
				if absf(direction.x)>0.01: flip_h = direction.x<0
				position = next
			elif not clear:
				# An edited room may block an old station. Stay still and retry;
				# never warp or walk through its new furniture.
				waiting = 1
			if position.distance_to(goal)<1:
				target_index = (target_index+1)%route.size()
				waiting = float(spec.get("wait_seconds",7))
	visible = not game.world.is_under_roof(position)
	z_index = Depth.for_y(position.y,game.world.bounds.end.y)
	if motion.is_empty(): return
	if moving:
		walk_clock = fposmod(walk_clock+delta,motion.walk.size()/float(definition.walk_animation.fps))
		frame_index = mini(int(walk_clock*float(definition.walk_animation.fps)),motion.walk.size()-1)
	else:
		walk_clock = 0
		frame_index = -1
	var frame: Dictionary = definition.walk_animation.frames[frame_index] if frame_index>=0 else {"region":definition.frames.idle,"anchor":definition.anchor.idle}
	sprite = motion.walk[frame_index] if frame_index>=0 else motion.idle
	service_remaining=maxf(0,service_remaining-delta)
	if service_remaining<=0:service_pose=""
	if not service_pose.is_empty() and definition.get("service_frames",{}).has(service_pose):
		frame=definition.service_frames[service_pose]
		sprite=service_textures[service_pose]
		frame_index=-2 if service_pose=="counting" else -3
	var ratio := WorldScale.human_height(definition)/float(definition.scale_height)
	sprite_rect = Rect2(-Vector2(frame.anchor[0],frame.anchor[1])*ratio,Vector2(frame.region[2],frame.region[3])*ratio)
	caption.text = str(spec.get("name","医务人员"))+" · "+("巡查" if moving else "值班" if on_duty else "休息")
	if old_frame!=frame_index or delta==0: queue_redraw()

func play_service_pose(pose: String, seconds: float):
	if not definition.get("service_frames",{}).has(pose):return
	if not service_textures.has(pose):
		service_textures[pose]=preload("res://scripts/presentation/world_texture.gd").load_regions(str(definition.texture),[definition.service_frames[pose].region],[0])[0]
	service_pose=pose;service_remaining=seconds
	tick(0)

func _draw() -> void:
	if sprite==null: return
	draw_set_transform(Vector2.ZERO,0,Vector2(1,0.3))
	draw_circle(Vector2(0,5),14,Color(0,0,0,0.12))
	draw_set_transform(Vector2.ZERO,0,Vector2(-1 if flip_h else 1,1))
	draw_texture_rect(sprite,sprite_rect,false)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func snapshot() -> Dictionary:
	return {"id":spec.id,"appearance_id":definition.get("id",""),"position":[position.x,position.y],"visible":visible,"moving":moving,"frame_index":frame_index,"room_id":spec.get("room_id","")}
