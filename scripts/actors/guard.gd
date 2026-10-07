extends Node2D

const VIEW_RADIUS := 210.0
const DAY_VIEW_RADIUS := 210.0
const NIGHT_VIEW_RADIUS := 155.0
const HALF_FOV := PI / 3.0
const VisibilityGeometry = preload("res://scripts/presentation/visibility_geometry.gd")
var _view_key: Array = []
var _view_polygon := PackedVector2Array()
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
var investigate_until: float = 0
var returning_from_inspection := false
var inspection_route: Array[Vector2] = []

func configure(prison_world, escape_game) -> void:
	world = prison_world
	game = escape_game
	reset_guard()

func reset_guard() -> void:
	_view_key.clear()
	position = world.guard_start
	facing = Vector2.UP
	state = "patrol"
	returning_from_inspection = false
	inspection_route.clear()
	route_index = 0
	target_id = -1
	chat_partner_id = -1
	lost_time = 0.0
	path.clear()
	path_timer = 0.0
	stalled_time = 0
	path_state = ""
	skipped_waypoints = 0
	investigate_until = 0
	queue_redraw()

func view_radius() -> float:
	var night: bool = game.presentation != null and game.presentation.lighting != null and game.presentation.lighting.period == "night"
	return NIGHT_VIEW_RADIUS if night else DAY_VIEW_RADIUS

func inspection_allowed() -> bool:
	return global_alert() or returning_from_inspection or (game.schedule != null and game.schedule.is_sleep_time())

func global_alert() -> bool:
	return game.prison_alert != null and game.prison_alert.active

func allowed_zone() -> Rect2:
	return world.bounds if inspection_allowed() else world.guard_zone

func search_zone() -> Rect2:
	return world.bounds if global_alert() or (game.schedule != null and game.schedule.is_sleep_time()) else world.guard_zone

func movement_allowed(point: Vector2, radius: float = 17.0) -> bool:
	return allowed_zone().grow(-radius).has_point(point)

func schedule_changed(sleep_time: bool) -> void:
	if global_alert():
		return
	release_target()
	chat_partner_id = -1
	route_index = 0
	inspection_route.clear()
	if sleep_time:
		returning_from_inspection = false
		for actor in game.actors:
			# Inspect from beside the bed rather than stepping onto a sleeping body.
			inspection_route.append(game.schedule.inspection_point(actor.actor_id))
	else:
		returning_from_inspection = not world.guard_zone.grow(-17).has_point(position)

func patrol_route() -> Array[Vector2]:
	if global_alert():
		return game.prison_alert.search_route(self)
	if returning_from_inspection:
		return [world.guard_start]
	return inspection_route if game.schedule != null and game.schedule.is_sleep_time() and not inspection_route.is_empty() else world.patrol

func curfew_alert() -> bool:
	return global_alert() or (game.schedule != null and game.schedule.is_curfew())

func half_fov() -> float:
	return PI if curfew_alert() else HALF_FOV

func release_target() -> void:
	state = "patrol"
	target_id = -1
	lost_time = 0.0
	path.clear()
	stalled_time = 0

func investigate(point: Vector2) -> bool:
	if not curfew_alert() or game.phase != "playing" or state == "chasing" or not search_zone().grow(-17).has_point(point):
		return false
	var goal := point
	if not world.can_place_circle(goal,17,self,true):
		var found := false
		for offset in [Vector2(45,0),Vector2(-45,0),Vector2(0,45),Vector2(0,-45)]:
			if world.can_place_circle(point+offset,17,self,true):
				goal = point+offset
				found = true
				break
		if not found:
			return false
	if chat_partner_id >= 0:
		game.cancel_guard_chat("看门犬示警，看守结束交谈并去调查。")
	chat_partner_id = -1
	target_id = -1
	state = "searching"
	last_seen = goal
	investigate_until = game.elapsed+6
	path.clear()
	return true

func sees(point: Vector2) -> bool:
	if not search_zone().has_point(point):
		return false
	var offset := point - position
	if offset.length() > view_radius():
		return false
	if offset.length_squared() > 0.001 and facing.dot(offset.normalized()) < cos(half_fov()):
		return false
	return world.line_clear(position,point)

func tick(delta: float) -> void:
	moved_this_frame = false
	if game.phase != "playing":
		return
	if not curfew_alert() and state in ["chasing", "searching"]:
		release_target()
	world.update_dorm_doors(game.schedule != null and game.schedule.is_sleep_time(),game.inspection_positions())
	if returning_from_inspection and world.guard_zone.grow(-17).has_point(position):
		returning_from_inspection = false
		path.clear()
		route_index = 0
	if state == "chasing" and (target_id < 0 or (game.routines != null and game.routines.is_lawful(target_id)) or not search_zone().has_point(game.actors[target_id].position)):
		release_target()
	var nearest_id: int = -1
	var nearest_distance: float = INF
	for actor in game.actors:
		if not curfew_alert():
			break
		if actor.escaped or actor.confined or (game.routines != null and game.routines.is_lawful(actor.actor_id)) or game.elapsed < actor.immune_until or actor.actor_id == chat_partner_id or (game.schedule != null and game.schedule.is_sleeping(actor.actor_id)):
			continue
		var distance: float = position.distance_to(actor.position)
		if distance < nearest_distance and sees(actor.position):
			nearest_id = actor.actor_id
			nearest_distance = distance
	if nearest_id >= 0:
		if chat_partner_id >= 0 and game.has_method("cancel_guard_chat"):
			game.cancel_guard_chat("看守发现了其他人，聊天中断！")
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
	elif state == "searching" and (game.elapsed >= investigate_until or position.distance_to(last_seen) < 10):
		release_target()
	var route := patrol_route()
	route_index %= route.size()
	var goal: Vector2 = last_seen if state in ["chasing","searching"] else route[route_index]
	if state == "patrol" and position.distance_to(goal) < 12:
		route_index = (route_index+1) % route.size()
		goal = route[route_index]
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
			var speed: float = 155.0 if state == "chasing" else 100.0 if state == "searching" or curfew_alert() else 65.0
			var move: Vector2 = facing * minf(speed*delta,offset.length())
			moved_this_frame = world.move_actor(self,move).length_squared() > 0.001
	stalled_time = 0 if moved_this_frame else stalled_time + delta
	if state == "patrol" and stalled_time > 0.8:
		# A moved box or parked unit can make a patrol point unreachable.
		# Resume toward the next point using the same collision rules.
		route_index = (route_index+1) % route.size()
		skipped_waypoints += 1
		path.clear()
		stalled_time = 0
	_capture_if_touching()
	queue_redraw()

func _capture_if_touching() -> void:
	if not curfew_alert() or state != "chasing" or target_id < 0:
		return
	var target = game.actors[target_id]
	if target.escaped or target.confined or (game.routines != null and game.routines.is_lawful(target_id)) or (game.schedule != null and game.schedule.is_sleeping(target_id)) or not search_zone().has_point(target.position) or game.elapsed < target.immune_until or position.distance_to(target.position) > 38 or not world.line_clear(position,target.position):
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
	var radius := view_radius()
	var zone := search_zone()
	var half := half_fov()
	var key := [position,facing,radius,half,zone,world.obstacle_revision,world.crate]
	if key == _view_key: return _view_polygon
	_view_key = key
	# Distant obstacles cannot intersect these rays. Keep every original angle
	# and its exact clipping, while testing only the nearby sight blockers.
	var blockers: Array[Rect2] = []
	for rect in world.sight_rects():
		if position.distance_squared_to(position.clamp(rect.position,rect.end)) <= (radius+0.001)*(radius+0.001):
			blockers.append(rect)
	var angles: Array[float] = []
	var base_angle := facing.angle()
	for index in range(40 if curfew_alert() else 41):
		angles.append(base_angle-half+2*half*index/40.0)
	for rect in world.solid_rects():
		for corner in [rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)]:
			var relative := wrapf((corner-position).angle()-base_angle,-PI,PI)
			if absf(relative) < half:
				for epsilon in [-0.0001,0.0,0.0001]:
					angles.append(base_angle+relative+epsilon)
	angles.sort()
	var polygon := PackedVector2Array() if curfew_alert() else PackedVector2Array([Vector2.ZERO])
	for angle in angles:
		var direction := Vector2.from_angle(angle)
		var distance := radius
		if absf(direction.x) > 0.00001:
			distance = minf(distance,((zone.end.x if direction.x > 0 else zone.position.x)-position.x)/direction.x)
		if absf(direction.y) > 0.00001:
			distance = minf(distance,((zone.end.y if direction.y > 0 else zone.position.y)-position.y)/direction.y)
		# Match the world-space float rounding used by line-of-sight rays,
		# including nearly parallel rays originating on a wall edge.
		var endpoint := position+direction*maxf(0,distance)
		var delta := endpoint-position
		var nearest := 1.0
		for rect in blockers:
			var hit := VisibilityGeometry.fraction(position,delta,rect)
			if hit >= 0: nearest = minf(nearest,hit)
		polygon.append(position.lerp(endpoint,nearest)-position)
	_view_polygon = polygon
	return _view_polygon

func _draw() -> void:
	if not world:
		return
	if presentation_layers:
		return
	var dangerous: bool = state == "chasing"
	var tint := Color("c9534b") if dangerous or curfew_alert() else Color("d9ac54")
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
	var label := "追击！" if dangerous else "宵禁警戒" if curfew_alert() else ("交谈中" if state == "talking" else "巡逻")
	draw_string(ThemeDB.fallback_font,Vector2(-22,-52),label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("c9534b") if dangerous else Color("303b46"))

func snapshot() -> Dictionary:
	return {"position":[position.x,position.y],"facing":[facing.x,facing.y],"state":state,"target_id":target_id,"chat_partner_id":chat_partner_id,"lost_time":lost_time,"route_index":route_index,"view_radius":view_radius(),"guard_zone":[world.guard_zone.position.x,world.guard_zone.position.y,world.guard_zone.size.x,world.guard_zone.size.y],"fov_degrees":360 if curfew_alert() else 120,"curfew_alert":curfew_alert(),"path_size":path.size(),"stalled_time":stalled_time,"skipped_waypoints":skipped_waypoints}
