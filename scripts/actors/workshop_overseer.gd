extends "res://scripts/actors/guard.gd"

var rules
var route: Array[Vector2] = []

func is_workshop_overseer() -> bool:
	return true

func search_zone() -> Rect2:
	return world.bounds

func allowed_zone() -> Rect2:
	return world.bounds

func inspection_allowed() -> bool:
	return true

func view_radius() -> float:
	return 330.0

func half_fov() -> float:
	return PI

func curfew_alert() -> bool:
	return state == "chasing"

func tick(delta: float) -> void:
	moved_this_frame = false
	if game.phase != "playing" or game.get_tree().paused or rules == null: return
	if not rules.on_duty():
		if global_alert(): super.tick(delta)
		return
	if target_id >= 0 and not rules.wanted.has(target_id): release_target()
	if not rules.wanted.is_empty():
		var ids: Array = rules.wanted.keys()
		ids.sort_custom(func(a,b): return position.distance_squared_to(game.actors[a].position) < position.distance_squared_to(game.actors[b].position))
		target_id = int(ids[0])
		state = "chasing"
		chat_partner_id = -1
	elif state == "talking":
		if chat_partner_id >= 0: facing = position.direction_to(game.actors[chat_partner_id].position)
		return
	if route.is_empty(): return
	route_index %= route.size()
	var goal: Vector2 = game.actors[target_id].position if target_id >= 0 else route[route_index]
	if target_id < 0 and position.distance_to(goal) < 12:
		route_index = (route_index+1)%route.size()
		goal = route[route_index]
	path_timer -= delta
	# Repath a moving chase at most four times a second. Static patrols
	# keep their paths until a real obstacle change or stall.
	var invalid: bool = path_revision != world.obstacle_revision
	if path_timer <= 0 and (path.is_empty() or invalid or path_goal.distance_to(goal) > 35 or stalled_time > 0.4):
		path = world.find_path(position,goal,self,target_id < 0)
		path_goal = goal
		path_revision = world.obstacle_revision
		path_timer = 0.3
	while not path.is_empty() and position.distance_to(path[0]) < 4: path.remove_at(0)
	if not path.is_empty():
		var offset: Vector2 = path[0]-position
		facing = offset.normalized()
		moved_this_frame = world.move_actor(self,facing*minf((165.0 if target_id >= 0 else 75.0)*delta,offset.length())).length_squared() > 0.001
	stalled_time = 0.0 if moved_this_frame else stalled_time+delta
	if target_id < 0 and stalled_time > 1:
		route_index = (route_index+1)%route.size()
		path.clear()
		stalled_time = 0
	if target_id >= 0:
		var actor = game.actors[target_id]
		if not actor.confined and not actor.escaped and position.distance_to(actor.position) <= 38 and world.line_clear(position,actor.position):
			var caught := target_id
			game.capture_actor(caught)
			rules.wanted.erase(caught)
			rules.warnings.erase(caught)
			release_target()
	queue_redraw()
