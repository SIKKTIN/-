extends Node2D

const WorldTexture = preload("res://scripts/presentation/world_texture.gd")
var dog
var game
var definition: Dictionary = {}
var idle: Texture2D
var frames: Array[Texture2D] = []
var texture: Texture2D
var frame_index := -1
var clock := 0.0
var flip_h := false
var destination := Rect2()

func configure(owner_game, manifest_path: String) -> void:
	game = owner_game
	dog = game.dog
	if not manifest_path.is_empty() and FileAccess.file_exists(manifest_path):
		definition = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		idle = WorldTexture.load_asset(definition.idle)
		var animation: Dictionary = definition.walk_animation
		for frame in animation.frames:
			frames.append(WorldTexture.load_asset({"texture":animation.texture,"region":frame.region}))
	tick_visual(0)

func tick_visual(delta: float) -> void:
	if definition.is_empty():
		return
	if game.get_tree().paused:
		return
	var animation: Dictionary = definition.walk_animation
	frame_index = -1
	if dog.moved_this_frame and game.phase == "playing" and not frames.is_empty():
		clock = fposmod(clock+delta,frames.size()/float(animation.fps))
		frame_index = mini(int(clock*float(animation.fps)),frames.size()-1)
	else:
		clock = 0
	var entry: Dictionary = animation.frames[frame_index] if frame_index >= 0 else definition.idle
	texture = frames[frame_index] if frame_index >= 0 else idle
	var scale_height: float = float(animation.scale_height) if frame_index >= 0 else float(entry.get("scale_height",definition.get("scale_height",entry.region[3])))
	var ratio := float(definition.get("world_height",44))/scale_height
	destination = Rect2(-Vector2(entry.anchor[0],entry.anchor[1])*ratio,Vector2(entry.region[2],entry.region[3])*ratio)
	if absf(dog.facing.x) > 0.08:
		flip_h = dog.facing.x < 0
	dog.z_index = int(dog.position.y)
	queue_redraw()

func _draw() -> void:
	if texture:
		if flip_h:
			draw_set_transform(Vector2.ZERO,0,Vector2(-1,1))
		draw_texture_rect(texture,destination,false)
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func paint_information(canvas: CanvasItem, font: Font) -> void:
	var barking: bool = game.elapsed < dog.bark_until
	var color := Color("efb269") if game.presentation.lighting.period == "night" else Color("715037")
	var text := "犬吠示警！" if barking else "警犬 · 休息" if dog.state == "resting" else "警犬 · 嗅探" if dog.state == "tracking" else "警犬 · 巡逻"
	canvas.draw_string(font,Vector2(-36,-52),text,HORIZONTAL_ALIGNMENT_LEFT,-1,13,color)
	if barking:
		canvas.draw_arc(Vector2(0,-20),37,0,TAU,32,Color("db8643"),2,true)
	elif dog.state == "tracking":
		canvas.draw_arc(Vector2.ZERO,22,0,TAU,32,color,1.5,true)
