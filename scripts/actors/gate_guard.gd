extends "res://scripts/actors/guard.gd"

var guard_id := ""
var post := Vector2.ZERO

func is_gate_guard() -> bool:
	return true

func reset_guard() -> void:
	super.reset_guard()
	position = post
	facing = Vector2.LEFT
	escaped = false

func on_duty() -> bool:
	return game.schedule != null and not game.schedule.is_curfew()

func blocking_gate() -> bool:
	return on_duty() and state != "talking"

func tick(_delta: float) -> void:
	moved_this_frame = false
	escaped = not on_duty()
	visible = not escaped
	if game.phase != "playing" or game.get_tree().paused:
		return
	if state == "talking" and chat_partner_id >= 0:
		facing = position.direction_to(game.actors[chat_partner_id].position)
	else:
		state = "patrol"
		facing = Vector2.LEFT
	# Door guards never arrest during their daytime shift.
	target_id = -1
