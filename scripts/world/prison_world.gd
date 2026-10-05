extends Node2D

const RADIUS := 17.0
const GRID_SIZE := 20.0
var room_id: String = "r01"
var bounds := Rect2(74,114,922,560)
var walls: Array[Rect2] = []
var fixtures: Array = []
var fixtures_revision: int = 0
var door := Rect2(486,335,22,120)
var crate := Rect2(467,572,94,92)
var original_crate := crate
var exit_area := Rect2(986,355,194,180)
var door_open: bool = false
var lock_progress: float = 0.0
var push_distance: float = 0.0
var obstacle_revision: int = 0
var actors: Array = []
var patrol: Array[Vector2] = []
var guard_start := Vector2(735,280)
var guard_zone := bounds
var grid := AStarGrid2D.new()
var nav_dirty: bool = true
var art_textures: Dictionary = {}
var presentation_layers: bool = false

func configure(config: Dictionary, friendlies: Array) -> void:
	room_id = str(config.get("id", "r01"))
	fixtures.clear()
	fixtures_revision += 1
	for entry in config.get("fixtures", []):
		var fixture: Dictionary = entry.duplicate(true)
		fixture.rect = _rect(entry.rect)
		fixtures.append(fixture)
	bounds = _rect(config.get("bounds", [74,114,922,560]))
	walls.clear()
	for value in config.get("walls", []):
		walls.append(_rect(value))
	door = _rect(config.get("door", [486,335,22,120]))
	crate = _rect(config.get("crate", [467,572,94,92]))
	original_crate = crate
	exit_area = _rect(config.get("exit", [986,355,194,180]))
	actors = friendlies
	patrol.clear()
	for value in config.get("patrol", []):
		patrol.append(Vector2(value[0], value[1]))
	var start: Array = config.get("guard_start", [735,280])
	guard_start = Vector2(start[0], start[1])
	guard_zone = _rect(config.get("guard_zone",config.get("bounds",[74,114,922,560])))
	reset_world()

func _rect(value: Array) -> Rect2:
	return Rect2(value[0],value[1],value[2],value[3])

func reset_world() -> void:
	door_open = false
	lock_progress = 0.0
	crate = original_crate
	push_distance = 0.0
	_changed()

func solid_rects(include_crate: bool = true) -> Array[Rect2]:
	var result: Array[Rect2] = walls.duplicate()
	for fixture in fixtures:
		if fixture.get("blocks_movement",true):
			result.append(fixture.rect)
	if not door_open:
		result.append(door)
	if include_crate:
		result.append(crate)
	return result

func sight_rects() -> Array[Rect2]:
	var result: Array[Rect2] = walls.duplicate()
	if not door_open:
		result.append(door)
	result.append(crate)
	for fixture in fixtures:
		if fixture.get("blocks_sight",false):
			result.append(fixture.rect)
	return result

func _circle_hits_rect(point: Vector2, radius: float, rect: Rect2) -> bool:
	var closest := point.clamp(rect.position, rect.end)
	return point.distance_squared_to(closest) < radius * radius - 0.001

func inside_room(point: Vector2, radius: float = RADIUS, allow_exit: bool = true) -> bool:
	if point.y < bounds.position.y + radius or point.y > bounds.end.y - radius or point.x < bounds.position.x + radius:
		return false
	if point.x <= bounds.end.x - radius:
		return true
	return allow_exit and point.y >= exit_area.position.y + radius and point.y <= exit_area.end.y - radius and point.x <= exit_area.end.x - radius

func can_place_circle(point: Vector2, radius: float = RADIUS, ignore_actor = null, check_actors: bool = true, include_crate: bool = true) -> bool:
	if ignore_actor != null and ignore_actor.has_method("movement_allowed") and not ignore_actor.movement_allowed(point,radius):
		return false
	if not inside_room(point, radius):
		return false
	for rect in solid_rects(include_crate):
		if _circle_hits_rect(point, radius, rect):
			return false
	if check_actors:
		for actor in actors:
			if actor != ignore_actor and not actor.escaped and point.distance_to(actor.position) < radius + RADIUS - 0.01:
				# A capture can restore an occupied home; allow separation without pushing another person.
				if ignore_actor != null and ignore_actor.position.distance_to(actor.position) < radius + RADIUS and point.distance_to(actor.position) > ignore_actor.position.distance_to(actor.position):
					continue
				return false
	return true

func move_actor(actor, displacement: Vector2, can_push: bool = false, push_budget: float = 0.0) -> Vector2:
	var position_before: Vector2 = actor.position
	var steps := maxi(1, int(ceil(displacement.length() / 3.0)))
	var step := displacement / steps
	for index in range(steps):
		for component in [Vector2(step.x,0), Vector2(0,step.y)]:
			if component.length_squared() < 0.000001:
				continue
			var proposed: Vector2 = actor.position + component
			if can_push and push_budget > 0 and _circle_hits_rect(proposed, RADIUS, crate):
				var push_step: Vector2 = component.normalized() * minf(component.length(), push_budget)
				if _move_crate(push_step, actor):
					push_budget -= push_step.length()
			if can_place_circle(proposed, RADIUS, actor):
				actor.position = proposed
	return actor.position - position_before

func _move_crate(displacement: Vector2, pusher = null) -> bool:
	var proposed := Rect2(crate.position + displacement, crate.size)
	if not bounds.encloses(proposed):
		return false
	for rect in solid_rects(false):
		if proposed.intersects(rect):
			return false
	for actor in actors:
		if actor != pusher and not actor.escaped and _circle_hits_rect(actor.position, RADIUS, proposed):
			return false
	crate = proposed
	push_distance += displacement.length()
	_changed()
	return true

func open_door() -> void:
	door_open = true
	lock_progress = 1.0
	_changed()

func check_exit(actor) -> bool:
	var reached: bool = actor.position.x >= bounds.end.x + 1 if not bounds.encloses(exit_area) else exit_area.grow(-RADIUS).has_point(actor.position)
	if not actor.escaped and reached and actor.position.y >= exit_area.position.y + RADIUS and actor.position.y <= exit_area.end.y - RADIUS:
		actor.escaped = true
		actor.action_state = "idle"
		actor.queue_redraw()
		return true
	return false

func ray_rect_fraction(from: Vector2, to: Vector2, rect: Rect2) -> float:
	var delta := to - from
	var near: float = 0.0
	var far: float = 1.0
	for axis in range(2):
		var origin: float = from[axis]
		var velocity: float = delta[axis]
		var low: float = rect.position[axis]
		var high: float = rect.end[axis]
		if absf(velocity) < 0.00001:
			if origin < low or origin > high:
				return -1.0
		else:
			var one := (low - origin) / velocity
			var two := (high - origin) / velocity
			near = maxf(near, minf(one,two))
			far = minf(far, maxf(one,two))
			if near > far:
				return -1.0
	return near

func line_clear(from: Vector2, to: Vector2, inflate: float = 0.0) -> bool:
	for rect in sight_rects():
		var fraction := ray_rect_fraction(from, to, rect.grow(inflate))
		if fraction >= 0 and fraction <= 1:
			return false
	return true

func clip_ray(from: Vector2, direction: Vector2, length: float) -> Vector2:
	var endpoint := from + direction * length
	var fraction: float = 1.0
	for rect in sight_rects():
		var hit := ray_rect_fraction(from, endpoint, rect)
		if hit >= 0:
			fraction = minf(fraction, hit)
	return from.lerp(endpoint, fraction)

func _rebuild_navigation() -> void:
	var area := bounds.merge(exit_area)
	var low := Vector2i(floori(area.position.x/GRID_SIZE),floori(area.position.y/GRID_SIZE))
	var high := Vector2i(ceili(area.end.x/GRID_SIZE),ceili(area.end.y/GRID_SIZE))
	grid.region = Rect2i(low,high-low)
	grid.cell_size = Vector2(GRID_SIZE,GRID_SIZE)
	grid.offset = Vector2(GRID_SIZE,GRID_SIZE) * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in range(grid.region.position.y,grid.region.end.y):
		for x in range(grid.region.position.x,grid.region.end.x):
			var point := Vector2(x + 0.5,y + 0.5) * GRID_SIZE
			grid.set_point_solid(Vector2i(x,y), not can_place_circle(point,RADIUS,null,false))
	nav_dirty = false

func motion_clear(from: Vector2, to: Vector2, ignore_actor = null, avoid_actors: bool = false, ignore_crate: bool = false) -> bool:
	var steps := maxi(1,ceili(from.distance_to(to)/4.0))
	for index in range(1,steps+1):
		if not can_place_circle(from.lerp(to,float(index)/steps),RADIUS,ignore_actor,avoid_actors,not ignore_crate):
			return false
	return true

func _nearest_nav_point(point: Vector2, ignore_actor = null, avoid_actors: bool = false, ignore_crate: bool = false) -> Vector2i:
	var cell := Vector2i(floor(point.x / GRID_SIZE), floor(point.y / GRID_SIZE))
	var best := Vector2i(-1,-1)
	var best_distance: float = INF
	for y in range(maxi(grid.region.position.y,cell.y-5),mini(grid.region.end.y,cell.y+6)):
		for x in range(maxi(grid.region.position.x,cell.x-5),mini(grid.region.end.x,cell.x+6)):
			var candidate := Vector2i(x,y)
			if not grid.is_point_solid(candidate) and motion_clear(point,grid.get_point_position(candidate),ignore_actor,avoid_actors,ignore_crate):
				var distance := grid.get_point_position(candidate).distance_squared_to(point)
				if distance < best_distance:
					best = candidate
					best_distance = distance
	return best

func find_path(from: Vector2, to: Vector2, ignore_actor = null, avoid_actors: bool = false, ignore_crate: bool = false) -> PackedVector2Array:
	if not can_place_circle(to,RADIUS,ignore_actor,avoid_actors,not ignore_crate):
		return PackedVector2Array()
	if motion_clear(from,to,ignore_actor,avoid_actors,ignore_crate):
		return PackedVector2Array([to])
	if nav_dirty:
		_rebuild_navigation()
	# Overlay only this query's body/box constraints, then restore the shared grid.
	var changed: Array = []
	if avoid_actors or ignore_crate or (ignore_actor != null and ignore_actor.has_method("movement_allowed")):
		for y in range(grid.region.position.y,grid.region.end.y):
			for x in range(grid.region.position.x,grid.region.end.x):
				var cell := Vector2i(x,y)
				var old: bool = grid.is_point_solid(cell)
				var blocked: bool = not can_place_circle(grid.get_point_position(cell),RADIUS,ignore_actor,avoid_actors,not ignore_crate)
				if blocked != old:
					changed.append([cell,old])
					grid.set_point_solid(cell,blocked)
	var start := _nearest_nav_point(from,ignore_actor,avoid_actors,ignore_crate)
	var finish := _nearest_nav_point(to,ignore_actor,avoid_actors,ignore_crate)
	var raw := PackedVector2Array()
	if start.x >= 0 and finish.x >= 0:
		raw = grid.get_point_path(start,finish)
		if not raw.is_empty():
			raw.append(to)
	for change in changed:
		grid.set_point_solid(change[0],change[1])
	# Start at the furthest safely reachable waypoint, rather than walking back
	# to the nearest cell center each time a path is recalculated.
	var result := PackedVector2Array()
	var cursor := from
	var next: int = 0
	while next < raw.size():
		var reachable: int = -1
		for index in range(raw.size()-1,next-1,-1):
			if motion_clear(cursor,raw[index],ignore_actor,avoid_actors,ignore_crate):
				reachable = index
				break
		if reachable < 0:
			return PackedVector2Array()
		cursor = raw[reachable]
		result.append(cursor)
		next = reachable + 1
	return result

func _changed() -> void:
	obstacle_revision += 1
	nav_dirty = true
	queue_redraw()

func exit_icon_rect() -> Rect2:
	return Rect2(exit_area.position.x-59 if not bounds.encloses(exit_area) else exit_area.get_center().x-27,exit_area.get_center().y-35,54,54)

func exit_strip_rect() -> Rect2:
	return Rect2(exit_area.position.x,exit_area.position.y,10,exit_area.size.y)

func _draw() -> void:
	if presentation_layers:
		return
	if not art_textures.is_empty():
		_draw_art()
		return
	for rect in walls:
		_draw_wall(rect,Color("536052"))
	if door_open:
		draw_rect(door,Color(0.2,0.5,0.4,0.17))
		draw_rect(Rect2(door.position,Vector2(7,door.size.y)),Color("328b82"))
	else:
		_draw_wall(door,Color("9a8fb9"))
		draw_circle(door.get_center(),8,Color("f2ebdd"))
		draw_line(door.get_center(),door.get_center()+Vector2(0,6),Color("303b46"),3)
	var point := door.position + Vector2(-27,door.size.y * 0.5)
	draw_arc(point,10,0,TAU,20,Color("9a8fb9"),2,true)
	if lock_progress > 0 and not door_open:
		draw_rect(Rect2(point+Vector2(-28,-23),Vector2(56,5)),Color("536052"))
		draw_rect(Rect2(point+Vector2(-28,-23),Vector2(56*lock_progress,5)),Color("9a8fb9"))
	_draw_wall(crate,Color("bc965a"))
	draw_line(crate.position+Vector2(10,10),crate.end-Vector2(10,10),Color("806441"),3,true)
	draw_line(crate.position+Vector2(10,crate.size.y-10),crate.position+Vector2(crate.size.x-10,10),Color("806441"),3,true)
	draw_rect(exit_strip_rect(),Color("328b82"))
	var arrow := exit_icon_rect().get_center()
	draw_line(arrow-Vector2(14,0),arrow+Vector2(14,0),Color("328b82"),4,true)
	draw_line(arrow+Vector2(14,0),arrow+Vector2(2,-10),Color("328b82"),4,true)
	draw_line(arrow+Vector2(14,0),arrow+Vector2(2,10),Color("328b82"),4,true)

func _draw_art() -> void:
	for rect in walls:
		draw_texture_rect(art_textures.low_wall_v01,rect,false)
	var door_id := "locked_door_open_v01" if door_open else "locked_door_closed_v01"
	draw_texture_rect(art_textures[door_id],door,false)
	var point := door.position + Vector2(-27,door.size.y*0.5)
	draw_arc(point,10,0,TAU,24,Color("9a8fb9"),2,true)
	if lock_progress > 0 and not door_open:
		draw_rect(Rect2(point+Vector2(-28,-23),Vector2(56,6)),Color("536052"))
		draw_rect(Rect2(point+Vector2(-28,-23),Vector2(56*lock_progress,6)),Color("9a8fb9"))
	draw_texture_rect(art_textures.heavy_crate_v01,crate,false)
	draw_rect(exit_strip_rect(),Color("328b82"))
	draw_texture_rect(art_textures.exit_v01,exit_icon_rect(),false)

func _draw_wall(rect: Rect2, fill: Color) -> void:
	draw_rect(rect,fill)
	draw_rect(rect,Color("303b46"),false,2)
	draw_line(rect.position+Vector2(1,3),rect.position+Vector2(rect.size.x-1,3),fill.lightened(0.25),3)

func snapshot() -> Dictionary:
	return {"room_id":room_id,"door_open":door_open,"lock_progress":lock_progress,"crate":[crate.position.x,crate.position.y,crate.size.x,crate.size.y],"push_distance":push_distance,"obstacle_revision":obstacle_revision}
