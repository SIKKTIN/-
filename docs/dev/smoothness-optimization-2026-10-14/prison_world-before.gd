extends Node2D

const Footprint = preload("res://scripts/core/actor_footprint.gd")
const RADIUS := Footprint.RADIUS
const DoorPassage = preload("res://scripts/core/door_passage.gd")
var door_passage = DoorPassage.new()
var body_solids: Array[Rect2] = []
var inspection_body_solids: Array[Rect2] = []
var navigation_body_solids: Array[Rect2] = []
var navigation_inspection_body_solids: Array[Rect2] = []
const GRID_SIZE := 20.0
var pathfinding = preload("res://scripts/world/world_navigation.gd").new(self)
var room_id: String = "r01"
var bounds := Rect2(74,114,922,560)
var walls: Array[Rect2] = []
var fixtures: Array = []
var wall_surfaces: Dictionary = {}
var boundary_solids: Array[Rect2] = []
var boundary_doors: Dictionary = {}
var boundary_interactions: Dictionary = {}
var boundary_destinations: Dictionary = {}
var boundary_builds := 0
var wall_collision_cache: Array[Rect2] = []
var wall_collision_dirty := true
var wall_collision_signature: Array = []
var roofed_cells: Array = []
var room_visibility
var dorm_doors: Array = []
var dorms_locked := false
var dorm_geometry_cache: Dictionary = {}
var dorm_geometry_builds := 0
var dorm_sync_count := 0
var access_doors: Array = []
var inspection_grid := AStarGrid2D.new()
var inspection_solids: Array[Rect2] = []
var planning_guard_doors := false
var admission_filter: Callable
const SolidIndex = preload("res://scripts/core/solid_spatial_index.gd")
var solid_index = SolidIndex.new()
var inspection_index = SolidIndex.new()
var sight_index = SolidIndex.new()
var body_index = SolidIndex.new()
var inspection_body_index = SolidIndex.new()
var navigation_solids: Array[Rect2] = []
var navigation_inspection_solids: Array[Rect2] = []
var navigation_layout: Array = []
var ai_path_budget_active := false
var ai_path_spent_usec := 0
var ai_paths_deferred := 0
var sealed_room_revision := -1
var sealed_rooms: Dictionary = {}

func begin_ai_paths() -> void:
	ai_path_budget_active=true
	ai_path_spent_usec=0

func end_ai_paths() -> void:
	ai_path_budget_active=false
var fixtures_revision: int = 0
var door := Rect2(486,335,22,120)
var crate := Rect2(467,572,94,92)
var original_crate := crate
var exit_area := Rect2(986,355,194,180)
var escape_routes: Array = []
var escape_clock_minutes := 0.0
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
var portal_grid := AStarGrid2D.new()
var portal_guard_grid := AStarGrid2D.new()
var portal_inspection_grid := AStarGrid2D.new()
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
	dorm_geometry_cache.clear()
	preload("res://scripts/presentation/doorway_geometry.gd").art_definitions.clear()
	preload("res://scripts/presentation/prop_catalog.gd").invalidate()
	wall_collision_dirty = true
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
		var gate: Dictionary = entry.duplicate(true)
		gate.actor_id = int(entry.actor_id)
		gate.rect = _rect(entry.rect)
		gate.closed = false
		dorm_doors.append(gate)
	bounds = _rect(config.get("bounds", [74,114,922,560]))
	boundary_solids.clear()
	boundary_doors.clear()
	door_passage.portals.clear()
	boundary_interactions.clear()
	boundary_destinations.clear()
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
	escape_routes.clear()
	for spec in config.get("escape_routes",[]):
		var route: Dictionary = spec.duplicate(true)
		route.rect = _rect(spec.rect)
		escape_routes.append(route)
	escape_clock_minutes = 0.0
	actors = friendlies
	patrol.clear()
	for value in config.get("patrol", []):
		patrol.append(Vector2(value[0], value[1]))
	var start: Array = config.get("guard_start", [735,280])
	guard_start = Vector2(start[0], start[1])
	guard_zone = _rect(config.get("guard_zone",config.get("bounds",[74,114,922,560])))
	reset_world()

func is_under_roof(point: Vector2) -> bool:
	if room_visibility != null: return not room_visibility.visible_at(point)
	return roofed_cells.any(func(cell): return cell.rect.has_point(point))

func wall_is_roofed(index: int) -> bool:
	if room_visibility != null: return false # Modular roofs keep real perimeter walls.
	return roofed_cells.any(func(cell): return cell.rect.grow(1).encloses(walls[index]) and (room_visibility == null or not room_visibility.visible_at(cell.rect.get_center())))

func _rect(value: Array) -> Rect2:
	return Rect2(value[0],value[1],value[2],value[3])

func reset_world() -> void:
	door_open = false
	gate_guarded = false
	lock_progress = 0.0
	crate = original_crate
	push_distance = 0.0
	dorms_locked = false
	for gate in dorm_gates():
		gate.closed = false
		gate.erase("manual_closed")
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
	if gate.has("linked_to"):
		set_access_closed(str(gate.linked_to),closed,reset_progress)
		return
	# Timed/manual closure waits for the complete body to clear the leaf.
	# Forced confinement still closes immediately before its landing move.
	if closed and not reset_progress and actors.any(func(a):return not a.escaped and door_closure_overlap(a,gate)): closed=false
	if reset_progress: gate.progress = 0.0
	var changed: bool = bool(gate.closed)!=closed
	gate.closed = closed
	for companion in access_doors:
		if str(companion.get("linked_to",""))!=id:continue
		changed=changed or bool(companion.closed)!=closed
		companion.closed=closed
		if reset_progress:companion.progress=0.0
	if changed:_changed(true)

func dorm_gates() -> Array:
	var result := dorm_doors.duplicate()
	for port in door_passage.portals:
		if port.gate.get("manual_door",false) and port.gate not in result: result.append(port.gate)
	return result

func dorm_closure_rect(gate: Dictionary) -> Rect2:
	# A leaf state never changes its static closing envelope. Hash only the
	# authored geometry, including nested arrays, so moving/rotating a gate
	# directly also invalidates it without hashing every wall each frame.
	var key: int = [fixtures_revision,gate.get("id",""),gate.rect,gate.get("asset_id",""),gate.get("actor_id",-1),gate.get("rotation_quarters",0),gate.get("rotation_door_visual_rect",[]),gate.get("door_art_size",[]),gate.get("closed_visual_solid_parts",[]),gate.get("expose_closed_frame",false),gate.get("closure_padding",[])].hash()
	if dorm_geometry_cache.has(key): return dorm_geometry_cache[key]
	dorm_geometry_builds += 1
	var geometry = preload("res://scripts/presentation/doorway_geometry.gd")
	var rect: Rect2
	if gate.get("expose_closed_frame",false): rect = geometry.closed_art_bounds(self,gate)
	else: rect = geometry.projected_rect(self,gate)
	var padding: Array = gate.get("closure_padding",[0,0,0,0])
	if not gate.get("expose_closed_frame",false): rect = rect.grow_individual(padding[0],padding[1],padding[2],padding[3])
	dorm_geometry_cache[key] = rect
	return rect

func update_dorm_doors(locked: bool, keyholders: Variant, occupants: Array = []) -> void:
	dorm_sync_count += 1
	var points: Array = keyholders if keyholders is Array else [keyholders]
	var changed := false
	var gates := dorm_gates()
	if locked != dorms_locked:
		# A new day/night boundary resets the daytime manual choice.
		for gate in gates: gate.erase("manual_closed")
	dorms_locked = locked
	for gate in gates:
		# The guard uses a key and opens the gate before crossing its collider.
		var closure := dorm_closure_rect(gate)
		var key_near: bool = points.any(func(point): return point.distance_to(point.clamp(closure.position,closure.end)) <= 65)
		var closed: bool = (gate.get("manual_door",false) or str(gate.get("kind","dorm")) != "open") and locked and not key_near
		if not locked: closed = bool(gate.get("manual_closed",false))
		if closed and (actors+occupants).any(func(a):return is_instance_valid(a) and a.get("escaped")!=true and Footprint.body_at(a.position).intersects(closure)): closed=false
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

func nearby_sight(point: Vector2, radius: float) -> Array[Rect2]:
	if sight_index.revision != obstacle_revision:
		sight_index.rebuild(sight_rects().slice(0,-1),obstacle_revision)
	var result: Array[Rect2] = sight_index.nearby(point,radius)
	result.append(crate)
	return result

func _refresh_box_cache() -> void:
	if cached_crate != crate:
		cached_crate = crate
		cached_solids = static_solids.duplicate()
		cached_solids.append(crate)
		if not cached_sight.is_empty():
			cached_sight[cached_sight.size()-1] = crate

func _circle_hits_rect(point: Vector2, radius: float, rect: Rect2) -> bool:
	# Compatibility name for callers; radius is the horizontal foot half-width.
	return Footprint.hits_rect(point,radius,rect)

func inside_room(point: Vector2, radius: float = RADIUS, allow_exit: bool = true) -> bool:
	var depth := radius*Footprint.ASPECT.y
	if not escape_routes.is_empty(): return Footprint.inset(bounds,radius).has_point(point)
	if point.y < bounds.position.y + depth or point.y > bounds.end.y - depth or point.x < bounds.position.x + radius:
		return false
	if point.x <= bounds.end.x - radius:
		return true
	return allow_exit and point.y >= exit_area.position.y + depth and point.y <= exit_area.end.y - depth and point.x <= exit_area.end.x - radius

func _staff_exterior(actor, point: Vector2, radius: float = RADIUS) -> bool:
	return actor != null and actor.has_method("staff_exterior_allowed") and actor.staff_exterior_allowed(point,radius)

func door_body_clear(point: Vector2) -> bool:
	var index = inspection_body_index if planning_guard_doors else body_index
	if index.revision != obstacle_revision: index.rebuild(inspection_body_solids if planning_guard_doors else body_solids,obstacle_revision)
	return not index.nearby(point,0).any(func(rect):return rect.has_point(point))

func body_overlaps_door(actor, rect: Rect2) -> bool:
	return Footprint.body_at(actor.position).intersects(door_collision_rect(rect))

func door_closure_overlap(actor, gate: Dictionary) -> bool:
	if _gate_closure_overlap(actor,gate): return true
	for companion in access_doors:
		if str(companion.get("linked_to",""))==str(gate.get("id","")) and _gate_closure_overlap(actor,companion): return true
	return false

func _gate_closure_overlap(actor, gate: Dictionary) -> bool:
	if gate.get("body_depth_limited",false) and actor.position.y>=Footprint.front_contact_y(gate.rect):
		return false
	return body_overlaps_door(actor,gate.rect)

func can_place_circle(point: Vector2, radius: float = RADIUS, ignore_actor = null, check_actors: bool = true, include_crate: bool = true) -> bool:
	if not door_body_clear(point): return false
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
			if actor != ignore_actor and not actor.escaped and ((point-actor.position)/Footprint.ASPECT).length() < radius + RADIUS - 0.01:
				# A capture can restore an occupied home; allow separation without pushing another person.
				if ignore_actor != null and ((ignore_actor.position-actor.position)/Footprint.ASPECT).length() < radius + RADIUS and ((point-actor.position)/Footprint.ASPECT).length_squared() > ((ignore_actor.position-actor.position)/Footprint.ASPECT).length_squared():
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
	if not escape_routes.is_empty():
		for route in escape_routes:
			if not Footprint.inset(route.rect).has_point(actor.position) or not escape_route_open(route): continue
			if actor.escaped: return false
			actor.escaped = true
			actor.action_state = "idle"
			actor.queue_redraw()
			return true
		return false
	var reached: bool = actor.position.x >= bounds.end.x + 1 if not bounds.encloses(exit_area) else Footprint.inset(exit_area).has_point(actor.position)
	if not actor.escaped and reached and actor.position.y >= exit_area.position.y + RADIUS*Footprint.ASPECT.y and actor.position.y <= exit_area.end.y - RADIUS*Footprint.ASPECT.y:
		actor.escaped = true
		actor.action_state = "idle"
		actor.queue_redraw()
		return true
	return false

func escape_route_open(route: Dictionary) -> bool:
	var id := str(route.get("gate_id",""))
	if not id.is_empty() and access_by_id(id).get("closed",true): return false
	if route.has("hours"):
		return escape_clock_minutes >= float(route.hours[0]) and escape_clock_minutes < float(route.hours[1])
	return true

func escape_target(point: Vector2) -> Variant:
	for route in escape_routes:
		var marker := Rect2(route.rect.get_center()-Vector2(27,35),Vector2(54,54))
		if route.rect.has_point(point) or marker.has_point(point): return route.rect.get_center()
	return null

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
	if sight_index.revision != obstacle_revision:
		sight_index.rebuild(sight_rects().slice(0,-1),obstacle_revision)
	var candidates: Array[Rect2] = sight_index.along_segment(from,to,maxf(0,inflate))
	candidates.append(crate)
	for rect in candidates:
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
	pathfinding._rebuild_navigation()

func _closed_perimeter(area: Rect2) -> bool:
	return pathfinding._closed_perimeter(area)

func _sealed_room_separates(from: Vector2, to: Vector2) -> bool:
	return pathfinding._sealed_room_separates(from,to)

func _segment_hits_circle(from: Vector2, to: Vector2, center: Vector2, radius: float) -> bool:
	return Geometry2D.get_closest_point_to_segment(center,from,to).distance_squared_to(center) < radius*radius-0.001

func _segment_hits_rect(from: Vector2, to: Vector2, rect: Rect2) -> bool:
	# Scale the ellipse to a circle for exact swept contact, including corners.
	# This is the same ground footprint as manual movement and the path grid.
	from /= Footprint.ASPECT
	to /= Footprint.ASPECT
	rect = Rect2(rect.position/Footprint.ASPECT,rect.size/Footprint.ASPECT)
	if ray_rect_fraction(from,to,rect.grow(RADIUS)) < 0:
		return false
	if ray_rect_fraction(from,to,rect) >= 0:
		return true
	if from.distance_squared_to(from.clamp(rect.position,rect.end)) < RADIUS*RADIUS-0.001 or to.distance_squared_to(to.clamp(rect.position,rect.end)) < RADIUS*RADIUS-0.001:
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
	var body = inspection_body_index if planning_guard_doors else body_index
	if body.revision != obstacle_revision: body.rebuild(inspection_body_solids if planning_guard_doors else body_solids,obstacle_revision)
	for rect in body.along_segment(from,to,0):
		if ray_rect_fraction(from,to,rect) >= 0: return false
	# The room interior is convex. Only the legacy external exit needs a seam check.
	if maxf(from.x,to.x) > bounds.end.x-RADIUS and absf(to.x-from.x) > 0.001:
		var crossing := from.lerp(to,clampf((bounds.end.x-RADIUS-from.x)/(to.x-from.x),0,1))
		if crossing.y < exit_area.position.y+RADIUS*Footprint.ASPECT.y or crossing.y > exit_area.end.y-RADIUS*Footprint.ASPECT.y:
			return false
	var index = inspection_index if planning_guard_doors else solid_index
	if index.revision != obstacle_revision: index.rebuild(solid_rects(false),obstacle_revision)
	var candidates: Array[Rect2] = index.along_segment(from,to,RADIUS)
	if not ignore_crate: candidates.append(crate)
	for rect in candidates:
		if _segment_hits_rect(from,to,rect):
			return false
	if avoid_actors:
		for actor in actors:
			if actor == ignore_actor or actor.escaped:
				continue
			if ignore_actor != null and ((from-actor.position)/Footprint.ASPECT).length() < RADIUS*2 and ((to-from)/Footprint.ASPECT).dot((from-actor.position)/Footprint.ASPECT) >= 0 and ((to-actor.position)/Footprint.ASPECT).length_squared() > ((from-actor.position)/Footprint.ASPECT).length_squared():
				continue # Allow an occupied capture home to separate monotonically.
			if _segment_hits_circle(from/Footprint.ASPECT,to/Footprint.ASPECT,actor.position/Footprint.ASPECT,RADIUS*2):
				return false
	return true

func find_path(from: Vector2, to: Vector2, ignore_actor = null, avoid_actors: bool = false, ignore_crate: bool = false) -> PackedVector2Array:
	return pathfinding.find_path(from,to,ignore_actor,avoid_actors,ignore_crate)

func set_wall_boundaries(clips: Dictionary, doors: Dictionary) -> void:
	# Door apertures and projected boundaries are rebuilt together at map load.
	# Opening a leaf later cannot change the fixed wall geometry.
	wall_collision_dirty = true
	var next: Array[Rect2] = []
	for pieces in clips.values(): next.append_array(pieces)
	if next == boundary_solids and doors == boundary_doors:
		_changed(true)
		_rebuild_navigation()
		return
	boundary_solids = next
	boundary_doors = doors
	boundary_builds += 1
	_changed(true)
	_rebuild_navigation() # Warm both cached lattices before interactive play.
	boundary_interactions.clear()
	boundary_destinations.clear()
	for gate in access_doors:
		var point := _door_operation_origin(gate)
		var best := point
		var distance := INF
		for y in range(-4,5):
			for x in range(-4,5):
				var candidate := point+Vector2(x,y)*10
				var gap := candidate.distance_squared_to(point)
				if gap>=distance or not can_place_circle(candidate,RADIUS,null,false,false): continue
				distance = gap
				best = candidate
		boundary_interactions[gate.rect] = best

func routine_destination(point: Vector2) -> Vector2:
	if boundary_destinations.has(point): return boundary_destinations[point]
	var result := _resolve_routine_destination(point)
	boundary_destinations[point] = result
	return result

func _resolve_routine_destination(point: Vector2) -> Vector2:
	# Legacy activity markers sometimes sat in the decorative north coping.
	# Keep outdoor activities on the corridor side of the new physical wall.
	for rect in boundary_solids:
		if not _circle_hits_rect(point,RADIUS,rect): continue
		var candidate := Vector2(point.x,rect.position.y-RADIUS*Footprint.ASPECT.y-1) if rect.size.x>=rect.size.y else Vector2(rect.position.x-RADIUS-1,point.y)
		if can_place_circle(candidate,RADIUS,null,false,false): return candidate
	return point

func door_collision_rect(rect: Rect2) -> Rect2:
	return boundary_doors.get(rect,rect)

func door_interaction_point(gate: Dictionary) -> Vector2:
	return boundary_interactions.get(gate.rect,_door_operation_origin(gate))

func _door_operation_origin(gate: Dictionary) -> Vector2:
	var rect := door_collision_rect(gate.rect)
	if gate.has("interaction_point"):
		var p: Array = gate.interaction_point
		return Vector2(p[0],p[1])+rect.position-gate.rect.position
	return rect.get_center()+Vector2(37,0) if rect.size.y>rect.size.x else rect.get_center()+Vector2(0,45)

func wall_collision_rects() -> Array[Rect2]:
	# Native array hashes also catch callers inserting/moving walls directly.
	# Gate states are excluded: the fixed apertures do not change with a leaf.
	var signature: Array = [walls.hash(),wall_surfaces.hash(),boundary_solids.hash(),door_passage.portals.size()]
	if not wall_collision_dirty and signature == wall_collision_signature: return wall_collision_cache.duplicate()
	dorm_geometry_cache.clear()
	var result: Array[Rect2] = []
	var cuts: Array[Rect2] = []
	for port in door_passage.portals:
		cuts.append(port.rect)
	var geometry = preload("res://scripts/presentation/roof_geometry.gd")
	for index in range(walls.size()):
		var surface: Dictionary = wall_surfaces.get(index,{})
		if surface.has("grid_tile_asset") and surface.get("render_enabled",true) and not surface.get("collision_parts",[]).is_empty():
			# A painted modular wall occupies its complete visible footprint.
			# Subtract the same aperture used by the door art and body clearance,
			# including where the taller opening cuts an older side-wall tile.
			result.append_array(geometry.subtract_all(walls[index],cuts))
			continue
		if not surface.has("collision_parts"):
			result.append(walls[index])
			continue
		for part in surface.collision_parts:
			result.append(Rect2(walls[index].position+Vector2(part[0],part[1]),Vector2(part[2],part[3])))
	result.append_array(boundary_solids)
	wall_collision_cache = result.duplicate()
	wall_collision_signature = signature
	wall_collision_dirty = false
	return result

func _changed(static_changed: bool = false) -> void:
	obstacle_revision += 1
	body_solids = door_passage.solids()
	inspection_body_solids = door_passage.solids(true)
	nav_dirty = true
	static_nav_dirty = static_nav_dirty or static_changed
	static_solids = wall_collision_rects()
	cached_sight = static_solids.duplicate()
	if not door_open or gate_guarded:
		static_solids.append(door_collision_rect(door))
	if not door_open:
		cached_sight.append(door_collision_rect(door))
	for fixture in fixtures:
		if fixture.get("blocks_movement",true):
			static_solids.append_array(fixture_collision_rects(fixture))
		if fixture.get("blocks_sight",false):
			cached_sight.append_array(fixture_collision_rects(fixture))
	for gate in access_doors:
		if gate.has("sliding_door"):
			if gate.get("blocks_sight",false):
				cached_sight.append_array(preload("res://scripts/presentation/sliding_door_geometry.gd").world_solids(gate,door_collision_rect(gate.rect),float(gate.get("slide_fraction",0))))
			continue
		if gate.closed:
			static_solids.append(door_collision_rect(gate.rect))
			if gate.get("blocks_sight",false): cached_sight.append(door_collision_rect(gate.rect))
	inspection_solids = static_solids.duplicate()
	for gate in dorm_gates():
		if gate.closed:
			static_solids.append(dorm_closure_rect(gate) if gate.get("manual_door",false) else door_collision_rect(gate.rect))
	cached_solids = static_solids.duplicate()
	cached_solids.append(crate)
	cached_sight.append(crate)
	cached_crate = crate
	queue_redraw()

func fixture_collision_rects(fixture: Dictionary) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var rect: Rect2 = fixture.rect
	if not fixture.has("solid_parts"):
		result.append(rect)
		return result
	# Fractions of the ground footprint keep open frames walkable when moved
	# or resized in the editor. Canopies and pull-up bars only block at posts.
	for part: Array in fixture.solid_parts:
		result.append(Rect2(rect.position+Vector2(part[0],part[1])*rect.size,Vector2(part[2],part[3])*rect.size))
	return result

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
