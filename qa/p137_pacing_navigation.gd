extends "res://scripts/world/world_navigation.gd"
var frame_records: Array=[]
var current_trace: Dictionary={}
func find_path(from: Vector2,to: Vector2,ignore_actor=null,avoid_actors: bool=false,ignore_crate: bool=false) -> PackedVector2Array:
	current_trace={"from":str(from),"to":str(to),"actor":ignore_actor.get_script().resource_path if ignore_actor!=null else "none","state":str(ignore_actor.get("state")) if ignore_actor!=null else "none","subsearches":[]}
	var mark:=Time.get_ticks_usec()
	var result:=super.find_path(from,to,ignore_actor,avoid_actors,ignore_crate)
	current_trace["total_ms"]=(Time.get_ticks_usec()-mark)/1000.0
	current_trace["path_points"]=result.size()
	frame_records.append(current_trace)
	return result
func _path_on_grid(from: Vector2, to: Vector2, ignore_actor, avoid_actors: bool, ignore_crate: bool, navigation: AStarGrid2D) -> PackedVector2Array:
	connectivity.warm(navigation)
	var nav_mark:=Time.get_ticks_usec()
	var subtrace: Dictionary={"grid": "inspection" if navigation==world.inspection_grid else "portal_inspection" if navigation==world.portal_inspection_grid else "other"}
	current_trace.subsearches.append(subtrace)
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
	subtrace["overlay_endpoints_ms"]=(Time.get_ticks_usec()-nav_mark)/1000.0
	var raw := PackedVector2Array()
	if start.x >= 0 and finish.x >= 0 and connectivity.connected(navigation,start,finish):
		var astar_mark:=Time.get_ticks_usec()
		raw = navigation.get_point_path(start,finish)
		subtrace["astar_ms"]=(Time.get_ticks_usec()-astar_mark)/1000.0
		subtrace["astar_raw_points"]=raw.size()
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
			subtrace["total_ms"]=(Time.get_ticks_usec()-nav_mark)/1000.0
			return PackedVector2Array()
		cursor = raw[reachable]
		result.append(cursor)
		next = reachable + 1
	subtrace["total_ms"]=(Time.get_ticks_usec()-nav_mark)/1000.0
	return result
