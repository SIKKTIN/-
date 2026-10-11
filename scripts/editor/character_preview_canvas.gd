@tool
extends Control

var asset: Dictionary = {}
var motion: Dictionary = {}
var walking := true
var frame_index := 0
var zoom := 4.0
var flipped := false
var guides := true
var background := 0
var compact := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	resized.connect(queue_redraw)

func pose_texture() -> Texture2D:
	if motion.is_empty(): return null
	return motion.walk[frame_index] if walking else motion.idle

func pose_anchor() -> Vector2:
	if asset.is_empty(): return Vector2.ZERO
	var point: Array = asset.walk_animation.frames[frame_index].anchor if walking else asset.anchor.idle
	return Vector2(point[0], point[1])

func world_ratio() -> float:
	if asset.is_empty(): return 1.0
	var height: float = asset.walk_animation.scale_height if walking else asset.scale_height
	return preload("res://scripts/core/world_scale.gd").human_height(asset) / height

func pose_rect(scale_factor: float) -> Rect2:
	var texture := pose_texture()
	if texture == null: return Rect2()
	return Rect2(-pose_anchor() * world_ratio() * scale_factor, texture.get_size() * world_ratio() * scale_factor)

func draw_pose(foot: Vector2, scale_factor: float) -> void:
	var texture := pose_texture()
	if texture == null: return
	draw_set_transform(foot, 0, Vector2(-1 if flipped else 1, 1))
	draw_texture_rect(texture, pose_rect(scale_factor), false)
	draw_set_transform(Vector2.ZERO)
	if guides and not compact:
		draw_line(foot - Vector2(10, 0), foot + Vector2(10, 0), Color("2a9188"), 1)
		draw_line(foot - Vector2(0, 7), foot + Vector2(0, 7), Color("2a9188"), 1)

func _draw() -> void:
	var colors: Array[Color] = [Color("e7e4db"), Color("34414a"), Color("89927a")]
	draw_rect(Rect2(Vector2.ZERO, size), colors[background])
	if background == 0:
		for y in range(0, int(size.y), 20):
			for x in range(0, int(size.x), 20):
				if (x / 20 + y / 20) % 2 == 0:
					draw_rect(Rect2(x, y, 20, 20), Color(1, 1, 1, 0.12))
	if asset.is_empty(): return
	var text_color := Color("e9eee9") if background == 1 else Color("364844")
	var font := get_theme_default_font()
	if compact:
		var rect := pose_rect(1)
		var fit := minf((size.y - 18) / rect.size.y, (size.x - 16) / rect.size.x)
		draw_pose(Vector2(size.x / 2, size.y - 5), fit)
		return
	var foot := Vector2(size.x * 0.46, size.y * 0.81)
	var rect := pose_rect(1)
	var fit := minf(zoom, minf((foot.y - 35) / rect.size.y, size.x * 0.5 / rect.size.x))
	if guides:
		draw_line(Vector2(24, foot.y), Vector2(size.x - 24, foot.y), Color(text_color, 0.3), 1)
		draw_line(Vector2(foot.x, 28), Vector2(foot.x, size.y - 20), Color(text_color, 0.15), 1)
	draw_pose(foot, fit)
	draw_string(font, Vector2(24, 26), "放大预览 · %.1f×" % fit, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, text_color)
	var actual_foot := Vector2(size.x * 0.86, foot.y)
	draw_pose(actual_foot, 1)
	draw_string(font, actual_foot + Vector2(-48, 26), "游戏尺寸 · 1×", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, text_color)
