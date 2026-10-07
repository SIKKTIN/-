extends Node2D

const RADIUS := 17.0
const GRID_SIZE := 20.0
var room_id: String = "r01"
var bounds := Rect2(74,114,922,560)
var walls: Array[Rect2] = []
var fixtures: Array = []
var wall_surfaces: Dictionary = {}
var roofed_cells: Array = []
var dorm_doors: Array = []
var access_doors: Array = []
var inspection_grid := AStarGrid2D.new()
var inspection_solids: Array[Rect2] = []
var planning_guard_doors := false
var admission_filter: Callable
const SolidIndex = preload("res://scripts/core/solid_spatial_index.gd")
var solid_index = SolidIndex.new()
var inspection_index = SolidIndex.new()
var fixtures_revision: int = 0
var door := Rect2(486,335,22,120)
var crate := Rect2(467,572,94,92)
var original_crate := crate
var exit_area := Rect2(986,355,194,180)
var door_open: bool = false
var gate_guarded := false
var lock_progress: float = 0.0
var push_distance: float = 0.0
var obstacle_revision: int = 0
var actors: Array = []
var patrol: Array[Vector2] = []
var guard_start := Vector2(735,280)
var guard_zone := bounds
var grid := AStarGrid2D.new()
var guard_grid := AStarGrid2D.new()
var nav_dirty: bool = true
var static_nav_dirty: bool = true
var static_solids: Array[Rect2] = []
var cached_solids: Array[Rect2] = []
var cached_sight: Array[Rect2] = []
var cached_crate: Rect2
var navigation_builds: int = 0
var last_overlay_cells: int = 0
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
	dorm_doors.clear()
	access_doors.clear()
	for entry in config.get("access_doors",[]):
		var gate: Dictionary = entry.duplicate(true)
		gate.rect = _rect(entry.rect)
		gate.closed = bool(entry.get("initial_closed",true))
		gate.progress = 0.0
		access_doors.append(gate)
	for entry in config.get("dorm_doors",[]):
		dorm_doors.append({"actor_id":int(entry.actor_id),"rect":_rect(entry.rect),"closed":false})
	bounds = _rect(config.get("bounds", [74,114,922,560]))
	walls.clear()
	for value in config.get("walls", []):
		walls.append(_rect(value))
	wall_surfaces.clear()
	for surface in config.get("architecture",{}).get("wall_surfaces",[]):
		wall_surfaces[int(surface.wall_index)] = surface.duplicate(true)
	roofed_cells.clear()
	for cell in config.get("confinement",{}).get("cells",[]):
		if cell.get("building",{}).get("roofed",false):
			var building: Dictionary = cell.building.duplicate(true)
			building.rect = _rect(cell.rect)
			building.cell_id = str(cell.id)
			building.door_id = str(cell.door_id)
			roofed_cells.append(building)
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

func is_under_roof(point: Vector2) -> bool:
	return roofed_cells.any(func(cell): return cell.rect.has_point(point))

func wall_is_roofed(index: int) -> bool:
	return roofed_cells.any(func(cell): return cell.rect.grow(1).encloses(walls[index]))

func _rect(value: Array) -> Rect2:
	return Rect2(value[0],value[1],value[2],value[3])

func reset_world() -> void:
	door_open = false
	gate_guarded = false
	lock_progress = 0.0
	crate = original_crate
	push_distance = 0.0
	for gate in dorm_doors:
		gate.closed = false
	for gate in access_doors:
		gate.closed = bool(gate.get("initial_closed",true))
		gate.progress = 0.0
	_changed(true)

func access_by_id(id: String) -> Dictionary:
	for gate in access_doors:
		if str(gate.id) == id: return gate
	return {}

func set_access_closed(id: String, closed: bool, reset_progress := false) -> void:
	var gate := access_by_id(id)
	if gate.is_empty(): return
	if reset_progress: gate.progress = 0.0
	if bool(gate.closed) == closed: return
	gate.closed = closed
	_changed(true)

func update_dorm_doors(locked: bool, keyholders: Variant) -> void:
	var points: Array = keyholders if keyholders is Array else [keyholders]
	var changed := false
	for gate in dorm_doors:
		# The guard uses a key and opens the gate before crossing its collider.
		var closed: bool = locked and not points.any(func(point): return gate.rect.get_center().distance_to(point) <= 85)
		if bool(gate.closed) != closed:
			gate.closed = closed
			changed = true
	if changed:
		_changed(true)

func solid_rects(include_crate: bool = true) -> Array[Rect2]:
	_refresh_box_cache()
	if planning_guard_doors:
		var result: Array[Rect2] = inspection_solids.duplicate()
		if include_crate:
			result.append(crate)
		return result
	return cached_solids if include_crate else static_solids

func sight_rects() -> Array[Rect2]:
	_refresh_box_cache()
	return cached_sight

func _refresh_box_cache() -> void:
	if cached_crate != crate:
		cached_crate = crate
		cached_solids = static_solids.duplicate()
		cached_solids.append(crate)
		if not cached_sight.is_empty():
			cached_sight[cached_sight.size()-1] = crate

func _circle_hits_rect(point: Vector2, radius: float, rect: Rect2) -> bool:
	var closest := point.clamp(rect.position, rect.end)
	return point.distance_squared_to(closest) < radius * radius - 0.001

func inside_room(point: Vector2, radius: float = RADIUS, allow_exit: bool = true) -> bool:
	if point.y < bounds.position.y + radius or point.y > bounds.end.y - radius or point.x < bounds.position.x + radius:
		return false
	if point.x <= bounds.end.x - radius:
		return true
	return allow_exit and point.y >= exit_area.position.y + radius and point.y <= exit_area.end.y - radius and point.x <= exit_area.end.x - radius

func _staff_exterior(actor, point: Vector2, radius: float = RADIUS) -> bool:
	return actor != null and actor.has_method("staff_exterior_allowed") and actor.staff_exterior_allowed(point,radius)

func can_place_circle(point: Vector2, radius: float = RADIUS, ignore_actor = null, check_actors: bool = true, include_crate: bool = true) -> bool:
	if ignore_actor in actors and admission_filter.is_valid() and not admission_filter.call(ignore_actor,point,radius): return false
	if ignore_actor != null and ignore_actor.has_method("movement_allowed") and not ignore_actor.movement_allowed(point,radius):
		return false
	if not inside_room(point, radius) and not _staff_exterior(ignore_actor,point,radius):
		return false
	var index = inspection_index if planning_guard_doors else solid_index
	if index.revision != obstacle_revision: index.rebuild(solid_rects(false),obstacle_revision)
	for rect in index.nearby(point,radius):
		if _circle_hits_rect(point, radius, rect): return false
	if include_crate and _circle_hits_rect(point,radius,crate): return false
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
	_changed(true)

func set_gate_guarded(value: bool) -> void:
	if gate_guarded == value:
		return
	gate_guarded = value
	_changed(true)

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
	for navigation in [grid,guard_grid,inspection_grid]:
		navigation.region = Rect2i(low,high-low)
		navigation.cell_size = Vector2(GRID_SIZE,GRID_SIZE)
		navigation.offset = Vector2(GRID_SIZE,GRID_SIZE) * 0.5
		navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		navigation.update()
	for y in range(grid.region.position.y,grid.region.end.y):
		for x in range(grid.region.position.x,grid.region.end.x):
			var point := Vector2(x + 0.5,y + 0.5) * GRID_SIZE
			var blocked := not inside_room(point)
			inspection_grid.set_point_solid(Vector2i(x,y),blocked)
			grid.set_point_solid(Vector2i(x,y),blocked)
			guard_grid.set_point_solid(Vector2i(x,y),blocked or not guard_zone.grow(-RADIUS).has_point(point))
	for rect in static_solids:
		var inflated := rect.grow(RADIUS)
		var start := Vector2i(floori(inflated.position.x/GRID_SIZE),floori(inflated.position.y/GRID_SIZE))
		var end := Vector2i(ceili(inflated.end.x/GRID_SIZE),ceili(inflated.end.y/GRID_SIZE))
		for y in range(maxi(start.y,low.y),mini(end.y,high.y)):
			for x in range(maxi(start.x,low.x),mini(end.x,high.x)):
				var cell := Vector2i(x,y)
				if _circle_hits_rect(grid.get_point_position(cell),RADIUS,rect):
					grid.set_point_solid(cell,true)
					guard_grid.set_point_solid(cell,true)
					if inspection_solids.has(rect):
						inspection_grid.set_point_solid(cell,true)
	navigation_builds += 1
	static_nav_dirty = false
	nav_dirty = false

func _segment_hits_circle(from: Vector2, to: Vector2, center: Vector2, radius: float) -> bool:
	return Geometry2D.get_closest_point_to_segment(center,from,to).distance_squared_to(center) < radius*radius-0.001

func _segment_hits_rect(from: Vector2, to: Vector2, rect: Rect2) -> bool:
	# Swept circle against a rectangle, retaining rounded corners rather than
	# treating the entire grown AABB as solid. No repeated four-unit samples.
	if ray_rect_fraction(from,to,rect.grow(RADIUS)) < 0:
		return false
	if ray_rect_fraction(from,to,rect) >= 0:
		return true
	if _circle_hits_rect(from,RADIUS,rect) or _circle_hits_rect(to,RADIUS,rect):
		return true
	for corner in [rect.position,rect.end,Vector2(rect.position.x,rect.end.y),Vector2(rect.end.x,rect.position.y)]:
		if _segment_hits_circle(from,to,corner,RADIUS):
			return true
	return false

func motion_clear(from: Vector2, to: Vector2, ignore_actor = null, avoid_actors: bool = false, ignore_crate: bool = false) -> bool:
	if (not inside_room(from) and not _staff_exterior(ignore_actor,from)) or (not inside_room(to) and not _staff_exterior(ignore_actor,to)):
		return false
	if ignore_actor != null and ignore_actor.has_method("movement_allowed"):
		if not ignore_actor.movement_allowed(from,RADIUS) or not ignore_actor.movement_allowed(to,RADIUS):
			return false
	# The room interior is convex. Only the legacy external exit needs a seam check.
	if maxf(from.x,to.x) > bounds.end.x-RADIUS and absf(to.x-from.x) > 0.001:
		var crossing := from.lerp(to,clampf((bounds.end.x-RADIUS-from.x)/(to.x-from.x),0,1))
		if crossing.y < exit_area.position.y+RADIUS or crossing.y > exit_area.end.y-RADIUS:
			return false
	for rect in solid_rects(not ignore_crate):
		if _segment_hits_rect(from,to,rect):
			return false
	if avoid_actors:
		for actor in actors:
			if actor == ignore_actor or actor.escaped:
				continue
			if ignore_actor != null and from.distance_to(actor.position) < RADIUS*2 and (to-from).dot(from-actor.position) >= 0 and to.distance_to(actor.position) > from.distance_to(actor.position):
				continue # Allow an occupied capture home to separate monotonically.
			if _segment_hits_circle(from,to,actor.position,RADIUS*2):
				return false
	return true

func _nearest_nav_point(point: Vector2, ignore_actor = null, avoid_actors: bool = false, ignore_crate: bool = false, navigation: AStarGrid2D = null) -> Vector2i:
	if navigation == null:
		navigation = grid
	var cell := Vector2i(floor(point.x / GRID_SIZE), floor(point.y / GRID_SIZE))
	var best := Vector2i(-1,-1)
	var best_distance: float = INF
	for y in range(maxi(grid.region.position.y,cell.y-5),mini(grid.region.end.y,cell.y+6)):
		for x in range(maxi(grid.region.position.x,cell.x-5),mini(grid.region.end.x,cell.x+6)):
			var candidate := Vector2i(x,y)
			if not navigation.is_point_solid(candidate):
				var distance := navigation.get_point_position(candidate).distance_squared_to(point)
				if distance < best_distance and motion_clear(point,navigation.get_point_position(candidate),ignore_actor,avoid_actors,ignore_crate):
					best = candidate
					best_distance = distance
	return best

func find_path(from: Vector2, to: Vector2, ignore_actor = null, avoid_actors: bool = false, ignore_crate: bool = false) -> PackedVector2Array:
	planning_guard_doors = ignore_actor != null and ignore_actor.has_method("inspection_allowed") and ignore_actor.inspection_allowed()
	var result := _find_path(from,to,ignore_actor,avoid_actors,ignore_crate)
	planning_guard_doors = false
	return result

func _find_path(from: Vector2, to: Vector2, ignore_actor = null, avoid_actors: bool = false, ignore_crate: bool = false) -> PackedVector2Array:
	if not can_place_circle(to,RADIUS,ignore_actor,avoid_actors,not ignore_crate):
		return PackedVector2Array()
	if motion_clear(from,to,ignore_actor,avoid_actors,ignore_crate):
		return PackedVector2Array([to])
	if static_nav_dirty:
		_rebuild_navigation()
	var navigation: AStarGrid2D = inspection_grid if planning_guard_doors else guard_grid if ignore_actor != null and ignore_actor.has_method("inspection_allowed") else grid
	# Overlay just the small footprints of moving bodies and the box. The
	# cached grids contain static walls/furniture (and the guard's boundary).
	var changed: Array[Vector2i] = []
	if not ignore_crate:
		_overlay_rect(navigation,crate.grow(RADIUS),changed,ignore_actor,avoid_actors,ignore_crate)
	if avoid_actors:
		for actor in actors:
			if actor != ignore_actor and not actor.escaped:
				_overlay_rect(navigation,Rect2(actor.position-Vector2.ONE*RADIUS*2,Vector2.ONE*RADIUS*4),changed,ignore_actor,avoid_actors,ignore_crate)
	last_overlay_cells = changed.size()
	nav_dirty = false
	var start := _nearest_nav_point(from,ignore_actor,avoid_actors,ignore_crate,navigation)
	var finish := _nearest_nav_point(to,ignore_actor,avoid_actors,ignore_crate,navigation)
	var raw := PackedVector2Array()
	if start.x >= 0 and finish.x >= 0:
		raw = navigation.get_point_path(start,finish)
		if not raw.is_empty():
			raw.append(to)
	for change in changed:
		navigation.set_point_solid(change,false)
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

func _overlay_rect(navigation: AStarGrid2D, area: Rect2, changed: Array[Vector2i], ignore_actor, avoid_actors: bool, ignore_crate: bool) -> void:
	var low := Vector2i(floori(area.position.x/GRID_SIZE),floori(area.position.y/GRID_SIZE))
	var high := Vector2i(ceili(area.end.x/GRID_SIZE),ceili(area.end.y/GRID_SIZE))
	for y in range(maxi(low.y,navigation.region.position.y),mini(high.y,navigation.region.end.y)):
		for x in range(maxi(low.x,navigation.region.position.x),mini(high.x,navigation.region.end.x)):
			var cell := Vector2i(x,y)
			if not navigation.is_point_solid(cell) and not can_place_circle(navigation.get_point_position(cell),RADIUS,ignore_actor,avoid_actors,not ignore_crate):
				changed.append(cell)
				navigation.set_point_solid(cell,true)

func _changed(static_changed: bool = false) -> void:
	obstacle_revision += 1
	nav_dirty = true
	static_nav_dirty = static_nav_dirty or static_changed
	static_solids = walls.duplicate()
	cached_sight = walls.duplicate()
	if not door_open or gate_guarded:
		static_solids.append(door)
	if not door_open:
		cached_sight.append(door)
	for fixture in fixtures:
		if fixture.get("blocks_movement",true):
			static_solids.append(fixture.rect)
		if fixture.get("blocks_sight",false):
			cached_sight.append(fixture.rect)
	for gate in access_doors:
		if gate.closed:
			static_solids.append(gate.rect)
			if gate.get("blocks_sight",false): cached_sight.append(gate.rect)
	inspection_solids = static_solids.duplicate()
	for gate in dorm_doors:
		if gate.closed:
			static_solids.append(gate.rect)
	cached_solids = static_solids.duplicate()
	cached_solids.append(crate)
	cached_sight.append(crate)
	cached_crate = crate
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
	return {"dorm_doors":dorm_doors.map(func(g): return {"actor_id":g.actor_id,"closed":g.closed}),"room_id":room_id,"door_open":door_open,"lock_progress":lock_progress,"crate":[crate.position.x,crate.position.y,crate.size.x,crate.size.y],"push_distance":push_distance,"obstacle_revision":obstacle_revision}
