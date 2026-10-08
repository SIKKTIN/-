extends Node2D

const Footprint = preload("res://scripts/core/actor_footprint.gd")

var actor_id: int = 0
var skill_id: String = "chat"
var home := Vector2.ZERO
var facing := Vector2.UP
var action_state: String = "idle"
var escaped: bool = false
var confined := false
var confinement_rect := Rect2()

func movement_allowed(point: Vector2, radius: float = Footprint.RADIUS) -> bool:
	return not confined or confinement_rect.grow(-radius).has_point(point)
var selected: bool = false
var immune_until: float = 0.0
var moved_this_frame: bool = false
var art_body: bool = false
var presentation_layers: bool = false

func _draw() -> void:
	if escaped:
		return
	if presentation_layers:
		return
	if art_body:
		if selected:
			draw_arc(Vector2.ZERO,23,0,TAU,40,Color("328b82"),3,true)
		draw_line(facing*17,facing*25,Color("328b82"),3,true)
		return
	var outline := Color("303b46")
	_draw_shadow_ellipse(Vector2(0, 2), Vector2(16, 5), Color(0, 0, 0, 0.14))
	if selected:
		draw_arc(Vector2.ZERO, 23, 0, TAU, 40, Color("328b82"), 3, true)
	draw_line(Vector2(-5, -8), Vector2(-7, 1), outline, 7, true)
	draw_line(Vector2(5, -8), Vector2(7, 1), outline, 7, true)
	draw_style_box(_body_style(), Rect2(-13, -28, 26, 22))
	draw_circle(Vector2(0, -33), 11, Color("f0c99e"))
	draw_arc(Vector2(0, -33), 11, 0, TAU, 24, outline, 2, true)
	draw_circle(Vector2(-4, -35), 1.5, outline)
	draw_circle(Vector2(4, -35), 1.5, outline)
	draw_line(Vector2(-3, -28), Vector2(3, -28), outline, 1.5)
	draw_line(Vector2.ZERO, facing * 11, Color("328b82"), 2)
	draw_string(ThemeDB.fallback_font, Vector2(-4, -12), str(actor_id + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, outline)
	if action_state != "idle":
		draw_circle(Vector2(18, -40), 6, Color("9a8fb9"))

func _draw_shadow_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * index / 24.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)

func _body_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("de8d59")
	style.border_color = Color("303b46")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style

func reset_actor() -> void:
	position = home
	facing = Vector2.UP
	action_state = "idle"
	escaped = false
	confined = false
	immune_until = 0.0
	queue_redraw()

func snapshot() -> Dictionary:
	return {"actor_id": actor_id, "skill_id": skill_id, "position": [position.x, position.y], "facing": [facing.x, facing.y], "action": action_state, "escaped": escaped, "selected": selected,"confined":confined}
