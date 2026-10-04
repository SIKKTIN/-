extends Node2D

const VIEW_RADIUS := 110.0
const HALF_FOV := PI / 3.0
var world
var game
var state: String = "patrol"
var facing := Vector2.UP
var route_index: int = 0
var target_id: int = -1
var chat_partner_id: int = -1
var lost_time: float = 0.0
var last_seen := Vector2.ZERO
var escaped: bool = false
var moved_this_frame: bool = false
var art_body: bool = false
var presentation_layers: bool = false
var path := PackedVector2Array()
var path_timer: float = 0.0
var path_goal := Vector2.ZERO
var path_revision: int = -1
var stalled_time: float = 0
var path_state: String = ""
var skipped_waypoints: int = 0

func configure(prison_world, escape_game) -> void:
	world = prison_world
	game = escape_game
	reset_guard()

func reset_guard() -> void:
	position = world.guard_start
	facing = Vector2.UP
	state = "patrol"
	route_index = 0
	target_id = -1
	chat_partner_id = -1
	lost_time = 0.0
	path.clear()
	path_timer = 0.0
	stalled_time = 0
	path_state = ""
	skipped_waypoints = 0
	queue_redraw()

func sees(point: Vector2) -> bool:
	var offset := point - position
	if offset.length() > VIEW_RADIUS:
		return false
	if offset.length_squared() > 0.001 and facing.dot(offset.normalized()) < cos(HALF_FOV):
		return false
	return world.line_clear(position,point)

func tick(delta: float) -> void:
	moved_this_frame = false
	if game.phase != "playing":
		return
	var nearest_id: int = -1
	var nearest_distance: float = INF
	for actor in game.actors:
		if actor.escaped or game.elapsed < actor.immune_until or actor.actor_id == chat_partner_id:
			continue
		var distance: float = position.distance_to(actor.position)
		if distance < nearest_distance and sees(actor.position):
			nearest_id = actor.actor_id
			nearest_distance = distance
	if nearest_id >= 0:
		if chat_partner_id >= 0 and game.has_method("cancel_guard_chat"):
			game.cancel_guard_chat("狱警发现了其他人，聊天中断！")
		chat_partner_id = -1
		state = "chasing"
		target_id = nearest_id
		last_seen = game.actors[target_id].position
		lost_time = 0.0
	elif state == "chasing":
		lost_time += delta
		if target_id < 0 or game.actors[target_id].escaped or lost_time >= 1.5:
			state = "patrol"
			target_id = -1
			path.clear()
	elif state == "talking":
		if chat_partner_id >= 0 and not game.actors[chat_partner_id].escaped:
			facing = position.direction_to(game.actors[chat_partner_id].position)
			queue_redraw()
			return
		state = "patrol"
	var goal: Vector2 = last_seen if state == "chasing" else world.patrol[route_index]
	if state == "patrol" and position.distance_to(goal) < 12:
		route_index = (route_index+1) % world.patrol.size()
		goal = world.patrol[route_index]
	path_timer -= delta
	var invalid: bool = not path.is_empty() and path_revision != world.obstacle_revision and not world.motion_clear(position,path[0])
	if path.is_empty() or invalid or path_state != state or path_goal.distance_to(goal) > 10 or (stalled_time >= 0.35 and path_timer <= 0):
		path = world.find_path(position,goal,self,state == "patrol")
		path_goal = goal
		path_revision = world.obstacle_revision
		path_state = state
		path_timer = 0.35
	while not path.is_empty() and position.distance_to(path[0]) < 4:
		path.remove_at(0)
	if not path.is_empty():
		var offset := path[0] - position
		if offset.length() > 1:
			facing = offset.normalized()
			var speed: float = 155.0 if state == "chasing" else 65.0
			var move: Vector2 = facing * minf(speed*delta,offset.length())
			moved_this_frame = world.move_actor(self,move).length_squared() > 0.001
	stalled_time = 0 if moved_this_frame else stalled_time + delta
	if state == "patrol" and stalled_time > 0.8:
		# A moved box or parked unit can make a patrol point unreachable.
		# Resume toward the next point using the same collision rules.
		route_index = (route_index+1) % world.patrol.size()
		skipped_waypoints += 1
		path.clear()
		stalled_time = 0
	_capture_if_touching()
	queue_redraw()

func _capture_if_touching() -> void:
	if state != "chasing" or target_id < 0:
		return
	var target = game.actors[target_id]
	if target.escaped or game.elapsed < target.immune_until or position.distance_to(target.position) > 38 or not world.line_clear(position,target.position):
		return
	game.capture_actor(target_id)
	state = "patrol"
	target_id = -1
	chat_partner_id = -1
	lost_time = 0.0
	path.clear()
	stalled_time = 0

func start_chat(actor_id: int) -> void:
	chat_partner_id = actor_id
	target_id = -1
	state = "talking"
	facing = position.direction_to(game.actors[actor_id].position)
	path.clear()
	queue_redraw()

func stop_chat() -> void:
	chat_partner_id = -1
	if state == "talking":
		state = "patrol"
	queue_redraw()

func view_polygon() -> PackedVector2Array:
	var angles: Array[float] = []
	var base_angle := facing.angle()
	for index in range(41):
		angles.append(base_angle-HALF_FOV+2*HALF_FOV*index/40.0)
	for rect in world.solid_rects():
		for corner in [rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)]:
			var relative := wrapf((corner-position).angle()-base_angle,-PI,PI)
			if absf(relative) < HALF_FOV:
				for epsilon in [-0.0001,0.0,0.0001]:
					angles.append(base_angle+relative+epsilon)
	angles.sort()
	var polygon := PackedVector2Array([Vector2.ZERO])
	for angle in angles:
		polygon.append(world.clip_ray(position,Vector2.from_angle(angle),VIEW_RADIUS)-position)
	return polygon

func _draw() -> void:
	if not world:
		return
	if presentation_layers:
		return
	var dangerous: bool = state == "chasing"
	var tint := Color("c9534b") if dangerous else Color("d9ac54")
	tint.a = 0.21
	draw_colored_polygon(view_polygon(),tint)
	if not art_body:
		draw_ellipse(Vector2(0,2),17,5,Color(0,0,0,0.14))
		draw_rect(Rect2(-13,-27,26,23),Color("303b46"))
		draw_circle(Vector2(0,-34),11,Color("d4b497"))
		draw_rect(Rect2(-12,-45,24,8),Color("303b46"))
		draw_line(Vector2(-15,-38),Vector2(15,-38),Color("303b46"),4)
	draw_line(facing*17,facing*30,Color("c9534b") if dangerous else Color("303b46"),3,true)
	draw_line(facing*30,facing*24+facing.orthogonal()*4,Color("303b46"),2,true)
	draw_line(facing*30,facing*24-facing.orthogonal()*4,Color("303b46"),2,true)
	var label := "追击！" if dangerous else ("交谈中" if state == "talking" else "巡逻")
	draw_string(ThemeDB.fallback_font,Vector2(-22,-52),label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("c9534b") if dangerous else Color("303b46"))

func snapshot() -> Dictionary:
	return {"position":[position.x,position.y],"facing":[facing.x,facing.y],"state":state,"target_id":target_id,"chat_partner_id":chat_partner_id,"lost_time":lost_time,"route_index":route_index,"view_radius":VIEW_RADIUS,"fov_degrees":120,"path_size":path.size(),"stalled_time":stalled_time,"skipped_waypoints":skipped_waypoints}
