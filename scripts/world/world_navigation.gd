extends RefCounted

# Cached grid planning and AI search budget. Collision/admission rules remain
# in PrisonWorld; all grids and counters retain their existing world API.
const Footprint = preload("res://scripts/core/actor_footprint.gd")
const RADIUS := Footprint.RADIUS
const GRID_SIZE := 20.0
var world

func _init(owner_world) -> void:
	world = owner_world

func _rebuild_navigation() -> void:
	var area = world.bounds.merge(world.exit_area)
	var layout = [area,world.guard_zone,not world.boundary_solids.is_empty()]
	var old_solids: Dictionary = {}
	var new_solids: Dictionary = {}
	for rect in world.navigation_solids: old_solids[rect]=true
	for rect in world.static_solids: new_solids[rect]=true
	var changed_rects: Array[Rect2] = []
	for pair in [[world.navigation_body_solids,world.body_solids],[world.navigation_inspection_body_solids,world.inspection_body_solids]]:
		for rect in pair[0]:
			if rect not in pair[1] and rect not in changed_rects: changed_rects.append(rect)
		for rect in pair[1]:
			if rect not in pair[0] and rect not in changed_rects: changed_rects.append(rect)
	for rect in old_solids:
		if not new_solids.has(rect): changed_rects.append(rect)
	for rect in new_solids:
		if not old_solids.has(rect): changed_rects.append(rect)
	var old_inspection: Dictionary = {}
	var new_inspection: Dictionary = {}
	for rect in world.navigation_inspection_solids: old_inspection[rect]=true
	for rect in world.inspection_solids: new_inspection[rect]=true
	for rect in old_inspection:
		if not new_inspection.has(rect) and not changed_rects.has(rect): changed_rects.append(rect)
	for rect in new_inspection:
		if not old_inspection.has(rect) and not changed_rects.has(rect): changed_rects.append(rect)
	if layout == world.navigation_layout and changed_rects.size() < 96:
		_refresh_navigation_cells(changed_rects)
		_finish_navigation(layout)
		return
	var low := Vector2i(floori(area.position.x/GRID_SIZE),floori(area.position.y/GRID_SIZE))
	var high := Vector2i(ceili(area.end.x/GRID_SIZE),ceili(area.end.y/GRID_SIZE))
	var sets := _navigation_sets()
	for triple in sets:
		for navigation in triple:
			navigation.region = Rect2i(low,high-low)
			navigation.cell_size = Vector2(GRID_SIZE,GRID_SIZE)
			# Ordinary furniture lanes retain half-cell samples. Narrow wall
			# portals use a separately cached grid with centres on wall joins.
			navigation.offset = Vector2.ZERO if navigation in [world.portal_grid,world.portal_guard_grid,world.portal_inspection_grid] else Vector2.ONE*GRID_SIZE*0.5
			navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
			navigation.jumping_enabled = true
			navigation.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
			navigation.update()
		for y in range(low.y,high.y):
			for x in range(low.x,high.x):
				var cell := Vector2i(x,y)
				var point: Vector2 = triple[0].get_point_position(cell)
				var blocked = not world.inside_room(point)
				triple[0].set_point_solid(cell,blocked)
				triple[1].set_point_solid(cell,blocked or not Footprint.inset(world.guard_zone).has_point(point))
				triple[2].set_point_solid(cell,blocked)
	var inspection_members: Dictionary = {}
	for rect in world.inspection_solids: inspection_members[rect]=true
	for rect in world.static_solids:
		var inflated: Rect2 = rect.grow(RADIUS)
		var start := Vector2i(floori(inflated.position.x/GRID_SIZE),floori(inflated.position.y/GRID_SIZE))
		var end := Vector2i(ceili(inflated.end.x/GRID_SIZE),ceili(inflated.end.y/GRID_SIZE))
		for y in range(maxi(start.y,low.y),mini(end.y,high.y)):
			for x in range(maxi(start.x,low.x),mini(end.x,high.x)):
				var cell := Vector2i(x,y)
				for triple in sets:
					if world._circle_hits_rect(triple[0].get_point_position(cell),RADIUS,rect):
						triple[0].set_point_solid(cell,true)
						triple[1].set_point_solid(cell,true)
						if inspection_members.has(rect):triple[2].set_point_solid(cell,true)
	for pair in [[world.body_solids,false],[world.inspection_body_solids,true]]:
		for rect in pair[0]:
			var start := Vector2i(floori(rect.position.x/GRID_SIZE),floori(rect.position.y/GRID_SIZE))
			var end := Vector2i(ceili(rect.end.x/GRID_SIZE),ceili(rect.end.y/GRID_SIZE))
			for y in range(maxi(start.y,low.y),mini(end.y,high.y)):
				for x in range(maxi(start.x,low.x),mini(end.x,high.x)):
					var cell := Vector2i(x,y)
					for triple in sets:
						if not rect.has_point(triple[0].get_point_position(cell)): continue
						if pair[1]: triple[2].set_point_solid(cell,true)
						else:
							triple[0].set_point_solid(cell,true)
							triple[1].set_point_solid(cell,true)
	_finish_navigation(layout)

func _finish_navigation(layout: Array) -> void:
	world.navigation_body_solids = world.body_solids.duplicate()
	world.navigation_inspection_body_solids = world.inspection_body_solids.duplicate()
	world.navigation_layout = layout
	world.navigation_solids = world.static_solids.duplicate()
	world.navigation_inspection_solids = world.inspection_solids.duplicate()
	world.navigation_builds += 1
	world.static_nav_dirty = false
	world.nav_dirty = false

func _refresh_navigation_cells(changed_rects: Array[Rect2]) -> void:
	if world.solid_index.revision != world.obstacle_revision: world.solid_index.rebuild(world.static_solids,world.obstacle_revision)
	if world.inspection_index.revision != world.obstacle_revision: world.inspection_index.rebuild(world.inspection_solids,world.obstacle_revision)
	var cells: Dictionary = {}
	for rect in changed_rects:
		var inflated := rect.grow(RADIUS)
		for y in range(maxi(world.grid.region.position.y,floori(inflated.position.y/GRID_SIZE)),mini(world.grid.region.end.y,ceili(inflated.end.y/GRID_SIZE))):
			for x in range(maxi(world.grid.region.position.x,floori(inflated.position.x/GRID_SIZE)),mini(world.grid.region.end.x,ceili(inflated.end.x/GRID_SIZE))): cells[Vector2i(x,y)]=true
	for cell in cells:
		for triple in _navigation_sets():
			var point: Vector2 = triple[0].get_point_position(cell)
			var blocked = not world.inside_room(point) or world.body_solids.any(func(rect):return rect.has_point(point))
			for rect in world.solid_index.nearby(point,RADIUS):
				if world._circle_hits_rect(point,RADIUS,rect): blocked=true;break
			var inspection_blocked = not world.inside_room(point) or world.inspection_body_solids.any(func(rect):return rect.has_point(point))
			for rect in world.inspection_index.nearby(point,RADIUS):
				if world._circle_hits_rect(point,RADIUS,rect): inspection_blocked=true;break
			triple[0].set_point_solid(cell,blocked)
			triple[1].set_point_solid(cell,blocked or not Footprint.inset(world.guard_zone).has_point(point))
			triple[2].set_point_solid(cell,inspection_blocked)

func _navigation_sets() -> Array:
	return [[world.grid,world.guard_grid,world.inspection_grid]] if world.boundary_solids.is_empty() else [[world.grid,world.guard_grid,world.inspection_grid],[world.portal_grid,world.portal_guard_grid,world.portal_inspection_grid]]

func _prefer_portal_grid(from: Vector2, to: Vector2) -> bool:
	for rect in world.boundary_doors.values():
		if rect.size.y<=rect.size.x: continue
		for point in [from,to]:
			if point.x<rect.position.x and absf(point.y-rect.get_center().y)<320:return true
	return false

func _nearest_nav_point(point: Vector2, ignore_actor = null, avoid_actors: bool = false, ignore_crate: bool = false, navigation: AStarGrid2D = null) -> Vector2i:
	if navigation == null:
		navigation = world.grid
	# The closest lattice point is usually already free. Validate it once
	# before scanning the whole neighbourhood through repeated collision rays.
	# Closed doors, moving bodies and blocked cells still use the exact fallback.
	var relative: Vector2 = (point-navigation.offset)/navigation.cell_size
	var nearest := Vector2i(ceili(relative.x-0.5),ceili(relative.y-0.5))
	if navigation.region.has_point(nearest) and not navigation.is_point_solid(nearest) and world.motion_clear(point,navigation.get_point_position(nearest),ignore_actor,avoid_actors,ignore_crate):
		return nearest
	var cell := Vector2i(floor(point.x / GRID_SIZE), floor(point.y / GRID_SIZE))
	var best := Vector2i(-1,-1)
	var best_distance: float = INF
	for y in range(maxi(world.grid.region.position.y,cell.y-5),mini(world.grid.region.end.y,cell.y+6)):
		for x in range(maxi(world.grid.region.position.x,cell.x-5),mini(world.grid.region.end.x,cell.x+6)):
			var candidate := Vector2i(x,y)
			if not navigation.is_point_solid(candidate):
				var distance := navigation.get_point_position(candidate).distance_squared_to(point)
				if distance < best_distance and world.motion_clear(point,navigation.get_point_position(candidate),ignore_actor,avoid_actors,ignore_crate):
					best = candidate
					best_distance = distance
	return best

func find_path(from: Vector2, to: Vector2, ignore_actor = null, avoid_actors: bool = false, ignore_crate: bool = false) -> PackedVector2Array:
	world.planning_guard_doors = ignore_actor != null and ignore_actor.has_method("inspection_allowed") and ignore_actor.inspection_allowed()
	var officer: bool=ignore_actor!=null and ignore_actor.has_method("_capture_if_touching")
	if officer:ignore_actor.path_deferred=false
	# Spend at most one expensive officer search after the frame's allowance.
	# A clear direct route remains immediate; deferred officers retain their
	# existing safe path and retry next frame. Detection/capture never defer.
	if world.ai_path_budget_active and officer and world.ai_path_spent_usec>=1000:
		if world.can_place_circle(to,RADIUS,ignore_actor,avoid_actors,not ignore_crate) and world.motion_clear(from,to,ignore_actor,avoid_actors,ignore_crate):
			world.planning_guard_doors=false
			return PackedVector2Array([to])
		ignore_actor.path_deferred=true
		world.ai_paths_deferred+=1
		world.planning_guard_doors=false
		return ignore_actor.path.duplicate()
	var start:=Time.get_ticks_usec() if world.ai_path_budget_active and officer else 0
	var result := _find_path(from,to,ignore_actor,avoid_actors,ignore_crate)
	if start>0:world.ai_path_spent_usec+=Time.get_ticks_usec()-start
	world.planning_guard_doors = false
	return result

func _find_path(from: Vector2, to: Vector2, ignore_actor = null, avoid_actors: bool = false, ignore_crate: bool = false) -> PackedVector2Array:
	if not world.can_place_circle(to,RADIUS,ignore_actor,avoid_actors,not ignore_crate):
		return PackedVector2Array()
	if world.motion_clear(from,to,ignore_actor,avoid_actors,ignore_crate):
		return PackedVector2Array([to])
	# A failed JPS search can traverse the entire factory. Reject only when
	# fixed solids prove a complete closed perimeter separates the endpoints.
	if not world.planning_guard_doors and _sealed_room_separates(from,to):
		return PackedVector2Array()
	if world.static_nav_dirty:
		_rebuild_navigation()
	var index = 2 if world.planning_guard_doors else 1 if ignore_actor!=null and ignore_actor.has_method("inspection_allowed") else 0
	var sets := _navigation_sets()
	if sets.size()>1 and _prefer_portal_grid(from,to):sets.reverse()
	for triple in sets:
		var result := _path_on_grid(from,to,ignore_actor,avoid_actors,ignore_crate,triple[index])
		if not result.is_empty():return result
	return PackedVector2Array()

func _sealed_room_separates(from: Vector2, to: Vector2) -> bool:
	if world.room_visibility == null: return false
	if world.sealed_room_revision != world.obstacle_revision:
		world.sealed_rooms.clear()
		world.sealed_room_revision = world.obstacle_revision
	for room in world.room_visibility.rooms:
		var area: Rect2 = room.roof_plan.roof
		if area.has_point(from) == area.has_point(to): continue
		if not world.sealed_rooms.has(area): world.sealed_rooms[area] = _closed_perimeter(area)
		if world.sealed_rooms[area]: return true
	return false

func _closed_perimeter(area: Rect2) -> bool:
	# Use all actual static solids, including every projected gate. A free
	# passage or either of two entrances breaks coverage and preserves A*.
	var solids: Array[Rect2] = world.solid_rects(false)
	for edge in [0,1,2,3]:
		var vertical: bool = edge < 2
		var line: float = area.position.x if edge==0 else area.end.x if edge==1 else area.position.y if edge==2 else area.end.y
		var low: float = area.position.y if vertical else area.position.x
		var high: float = area.end.y if vertical else area.end.x
		var spans: Array[Vector2] = []
		for solid in solids:
			# The expansion stays strictly inside the swept foot ellipse.
			var rect: Rect2 = Footprint.expand(solid,RADIUS*0.70)
			var near: float = rect.position.x if vertical else rect.position.y
			var far: float = rect.end.x if vertical else rect.end.y
			if near>line or far<line: continue
			var start: float = rect.position.y if vertical else rect.position.x
			var end: float = rect.end.y if vertical else rect.end.x
			if end>=low and start<=high: spans.append(Vector2(maxf(low,start),minf(high,end)))
		spans.sort_custom(func(a,b):return a.x<b.x)
		var cursor := low
		for span in spans:
			if span.x>cursor+0.001: return false
			cursor = maxf(cursor,span.y)
		if cursor<high-0.001: return false
	return true

func _path_on_grid(from: Vector2, to: Vector2, ignore_actor, avoid_actors: bool, ignore_crate: bool, navigation: AStarGrid2D) -> PackedVector2Array:
	# Overlay just the small footprints of moving bodies and the box. The
	# cached grids contain static walls/furniture (and the guard's boundary).
	var changed: Array[Vector2i] = []
	if not ignore_crate:
		_overlay_rect(navigation,world.crate.grow(RADIUS),changed,ignore_actor,avoid_actors,ignore_crate)
	if avoid_actors:
		for actor in world.actors:
			if actor != ignore_actor and not actor.escaped:
				_overlay_rect(navigation,Rect2(actor.position-Vector2.ONE*RADIUS*2,Vector2.ONE*RADIUS*4),changed,ignore_actor,avoid_actors,ignore_crate)
	world.last_overlay_cells = changed.size()
	world.nav_dirty = false
	var start := _nearest_nav_point(from,ignore_actor,avoid_actors,ignore_crate,navigation)
	var finish := _nearest_nav_point(to,ignore_actor,avoid_actors,ignore_crate,navigation)
	var raw := PackedVector2Array()
	if start.x >= 0 and finish.x >= 0:
		raw = navigation.get_point_path(start,finish)
		if not raw.is_empty():
			raw.append(to)
	for change in changed:
		navigation.set_point_solid(change,false)
	# Grid paths repeat every cell in long straight runs. Retain their turns
	# before exact smoothing, avoiding hundreds of redundant long ray tests.
	if raw.size()>2:
		var turns:=PackedVector2Array([raw[0]])
		for index in range(1,raw.size()-1):
			var incoming: Vector2=raw[index]-raw[index-1]
			var outgoing: Vector2=raw[index+1]-raw[index]
			if absf(incoming.cross(outgoing))>0.001 or incoming.dot(outgoing)<=0:turns.append(raw[index])
		turns.append(raw[-1])
		raw=turns
	# Start at the furthest safely reachable waypoint, rather than walking back
	# to the nearest cell center each time a path is recalculated.
	var result := PackedVector2Array()
	var cursor := from
	var next: int = 0
	while next < raw.size():
		var reachable: int = -1
		# Advance through visible consecutive turns. Testing the distant
		# end of a maze at every corner repeats costly map-wide ray casts.
		for index in range(next,raw.size()):
			if world.motion_clear(cursor,raw[index],ignore_actor,avoid_actors,ignore_crate):
				reachable = index
			else: break
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
			if not navigation.is_point_solid(cell) and not world.can_place_circle(navigation.get_point_position(cell),RADIUS,ignore_actor,avoid_actors,not ignore_crate):
				changed.append(cell)
				navigation.set_point_solid(cell,true)

