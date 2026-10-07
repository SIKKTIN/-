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
	return global_alert() or (game.schedule != null and not game.schedule.is_curfew())

func blocking_gate() -> bool:
	return not escaped and not game.staff_traffic.transiting(self) and on_duty() and not global_alert() and state not in ["talking","chasing"] and position.distance_to(post) < 100

func patrol_route() -> Array[Vector2]:
	if global_alert(): return super.patrol_route()
	var result: Array[Vector2] = [post]
	return result

func tick(delta: float) -> void:
	if game.staff_traffic and game.staff_traffic.tick_guard(self,delta): return
	if global_alert() or labor_enforcement() or state == "chasing" or position.distance_to(post) > 4:
		super.tick(delta)
		return
	moved_this_frame = false
	if game.phase != "playing" or game.get_tree().paused: return
	if state == "talking" and chat_partner_id >= 0:
		facing = position.direction_to(game.actors[chat_partner_id].position)
	else:
		state = "patrol"
		facing = Vector2.LEFT
	target_id = -1
