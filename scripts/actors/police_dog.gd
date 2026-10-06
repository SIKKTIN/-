extends Node2D

const SCENT_RADIUS := 180.0
const CONFIRM_RADIUS := 90.0
const TRAIL_SECONDS := 10.0
const BARK_COOLDOWN := 4.0
var game
var world
var state := "resting"
var facing := Vector2.RIGHT
var moved_this_frame := false
var escaped := false
var route_index := 0
var target_id := -1
var trails: Array = []
var sample_timer := 0.0
var path := PackedVector2Array()
var path_goal := Vector2.ZERO
var path_revision := -1
var path_timer := 0.0
var stalled_time := 0.0
var bark_until := 0.0
var next_bark := 0.0
var bark_count := 0
var tracking_until := 0.0
var last_scent_time := -1.0
var skipped_waypoints := 0

func configure(owner_game) -> void:
	game = owner_game
	world = game.world
	reset_dog()

func reset_dog() -> void:
	position = world.guard_start
	# Use an existing navigable patrol point, with no new hidden spawn geometry.
	for index in range(world.patrol.size()-1,-1,-1):
		if world.can_place_circle(world.patrol[index],17,self,false):
			position = world.patrol[index]
			break
	state = "resting"
	facing = Vector2.RIGHT
	route_index = maxi(0,world.patrol.size()-1)
	target_id = -1
	trails.clear()
	path.clear()
	path_revision = -1
	path_timer = 0
	stalled_time = 0
	sample_timer = 0
	next_bark = 0
	bark_until = 0
	bark_count = 0
	tracking_until = 0
	last_scent_time = -1
	skipped_waypoints = 0
	moved_this_frame = false

func movement_allowed(point: Vector2, radius: float = 17) -> bool:
	return search_zone().grow(-radius).has_point(point)

func inspection_allowed() -> bool:
	return game.prison_alert != null and game.prison_alert.active

func search_zone() -> Rect2:
	return world.bounds if inspection_allowed() else world.guard_zone

func _valid_actor(id: int) -> bool:
	return game.schedule != null and (inspection_allowed() or game.schedule.is_curfew()) and id >= 0 and id < game.actors.size() and not game.actors[id].escaped and not game.schedule.is_sleeping(id) and not (game.routines != null and game.routines.is_lawful(id)) and game.elapsed >= game.actors[id].immune_until and search_zone().has_point(game.actors[id].position)

func _sample_trails(delta: float) -> void:
	trails = trails.filter(func(t): return game.elapsed-float(t.time) <= TRAIL_SECONDS and _valid_actor(int(t.actor_id)))
	sample_timer -= delta
	if sample_timer > 0:
		return
	sample_timer = 0.4
	for actor in game.actors:
		if actor.moved_this_frame and _valid_actor(actor.actor_id):
			trails.append({"actor_id":actor.actor_id,"point":actor.position,"time":game.elapsed})

func _release() -> void:
	target_id = -1
	state = "patrol"
	last_scent_time = -1
	path.clear()
	path_timer = 0

func tick(delta: float) -> void:
	moved_this_frame = false
	if game.phase != "playing":
		return
	_sample_trails(delta)
	if not game.schedule or not game.schedule.dog_active():
		_release()
		trails.clear()
		state = "resting"
		return
	if state == "resting":
		state = "patrol"
	if target_id >= 0 and (not _valid_actor(target_id) or game.elapsed > tracking_until):
		_release()
	var direct_id := -1
	var direct_distance := CONFIRM_RADIUS
	for actor in game.actors:
		var distance: float = position.distance_to(actor.position)
		if _valid_actor(actor.actor_id) and distance <= direct_distance and world.line_clear(position,actor.position):
			direct_id = actor.actor_id
			direct_distance = distance
	if direct_id >= 0:
		target_id = direct_id
		tracking_until = game.elapsed+TRAIL_SECONDS
		var target: Vector2 = game.actors[target_id].position
		path_goal = target+target.direction_to(position)*50
		state = "tracking"
		if game.elapsed >= next_bark:
			next_bark = game.elapsed+BARK_COOLDOWN
			bark_until = game.elapsed+1
			bark_count += 1
			var alerted: bool = game.guard.investigate(target)
			game.show_status("看门犬犬吠示警！看守前往调查。" if alerted else "看门犬发现附近伙伴并犬吠！",2)
	else:
		# Smell a reachable patch of floor, not the hidden actor's current position.
		var newest: Dictionary = {}
		for trail in trails:
			if target_id >= 0 and int(trail.actor_id) != target_id:
				continue
			if float(trail.time) <= last_scent_time or position.distance_to(trail.point) > SCENT_RADIUS or not world.line_clear(position,trail.point):
				continue
			if newest.is_empty() or float(trail.time) > float(newest.time):
				newest = trail
		if not newest.is_empty():
			target_id = int(newest.actor_id)
			last_scent_time = float(newest.time)
			path_goal = newest.point
			tracking_until = last_scent_time+TRAIL_SECONDS
			state = "tracking"
	if state == "patrol":
		path_goal = world.patrol[route_index]
		if position.distance_to(path_goal) < 12:
			route_index = (route_index+world.patrol.size()-1)%world.patrol.size()
			path_goal = world.patrol[route_index]
	_move(delta)
	queue_redraw()

func _move(delta: float) -> void:
	path_timer -= delta
	var invalid: bool = not path.is_empty() and path_revision != world.obstacle_revision and not world.motion_clear(position,path[0],self)
	var changed: bool = not path.is_empty() and path[-1].distance_to(path_goal) > 16
	if path_timer <= 0 and (path.is_empty() or invalid or changed or stalled_time >= 0.4):
		path = world.find_path(position,path_goal,self,true)
		path_revision = world.obstacle_revision
		path_timer = 0.45
	while not path.is_empty() and position.distance_to(path[0]) < 4:
		path.remove_at(0)
	if not path.is_empty():
		var offset: Vector2 = path[0]-position
		facing = offset.normalized()
		var speed := 125.0 if state == "tracking" else 82.0
		moved_this_frame = world.move_actor(self,facing*minf(speed*delta,offset.length())).length_squared() > 0.001
	stalled_time = 0 if moved_this_frame else stalled_time+delta
	if stalled_time > 1 and state == "patrol":
		route_index = (route_index+world.patrol.size()-1)%world.patrol.size()
		skipped_waypoints += 1
		path.clear()
		stalled_time = 0

func snapshot() -> Dictionary:
	return {"position":[position.x,position.y],"state":state,"target_id":target_id,"trails":trails.size(),"barks":bark_count,"scent_radius":SCENT_RADIUS,"confirm_radius":CONFIRM_RADIUS,"trail_seconds":TRAIL_SECONDS,"path_size":path.size(),"skipped_waypoints":skipped_waypoints}
