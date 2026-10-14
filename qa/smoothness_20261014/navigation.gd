extends "res://scripts/world/world_navigation.gd"
var audit_records: Array=[]
var parts: Dictionary={}
func span(key: String, mark: int):parts[key]=parts.get(key,0.0)+(Time.get_ticks_usec()-mark)/1000.0
func find_path(from: Vector2,to: Vector2,ignore_actor=null,avoid_actors: bool=false,ignore_crate: bool=false) -> PackedVector2Array:
 parts.clear()
 connectivity.audit_parts.clear()
 var mark:=Time.get_ticks_usec()
 var result:=super.find_path(from,to,ignore_actor,avoid_actors,ignore_crate)
 audit_records.append({"ms":(Time.get_ticks_usec()-mark)/1000.0,"from":[from.x,from.y],"to":[to.x,to.y],"points":result.size(),"parts":parts.duplicate(),"connectivity_parts":connectivity.audit_parts.duplicate(),"deferred":world.ai_paths_deferred,"builds":world.navigation_builds})
 return result
func _rebuild_navigation():
 var mark:=Time.get_ticks_usec()
 super._rebuild_navigation()
 span("grid_update",mark)
func _path_on_grid(from: Vector2, to: Vector2, ignore_actor, avoid_actors: bool, ignore_crate: bool, navigation: AStarGrid2D) -> PackedVector2Array:
 var audit_mark: int=Time.get_ticks_usec()
 connectivity.warm(navigation)
 span("connectivity",audit_mark)
 audit_mark=Time.get_ticks_usec()
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
 span("overlay",audit_mark)
 audit_mark=Time.get_ticks_usec()
 var start := _nearest_nav_point(from,ignore_actor,avoid_actors,ignore_crate,navigation)
 var finish := _nearest_nav_point(to,ignore_actor,avoid_actors,ignore_crate,navigation)
 span("endpoints",audit_mark)
 audit_mark=Time.get_ticks_usec()
 var raw := PackedVector2Array()
 if start.x >= 0 and finish.x >= 0 and connectivity.connected(navigation,start,finish):
  var jps_mark:=Time.get_ticks_usec()
  raw = navigation.get_point_path(start,finish)
  span("jps",jps_mark)
  if not raw.is_empty():
   raw.append(to)
 span("search_and_connect",audit_mark)
 audit_mark=Time.get_ticks_usec()
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
 span("restore_compress",audit_mark)
 audit_mark=Time.get_ticks_usec()
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
   span("smooth",audit_mark)
   return PackedVector2Array()
  cursor = raw[reachable]
  result.append(cursor)
  next = reachable + 1
 span("smooth",audit_mark)
 return result

func _refresh_navigation_cells(changed_rects: Array[Rect2]) -> void:
 var audit_mark:=Time.get_ticks_usec()
 if world.solid_index.revision != world.obstacle_revision: world.solid_index.rebuild(world.static_solids,world.obstacle_revision)
 if world.body_index.revision != world.obstacle_revision: world.body_index.rebuild(world.body_solids,world.obstacle_revision)
 if world.inspection_body_index.revision != world.obstacle_revision: world.inspection_body_index.rebuild(world.inspection_body_solids,world.obstacle_revision)
 # Inspection omits closed dorm leaves, but keeps their OPEN leaf bodies.
 # Those bodies need their own query: they are not a subset of closed ones.
 span("grid_indexes",audit_mark)
 audit_mark=Time.get_ticks_usec()
 var inspection_members: Dictionary = {}
 for rect in world.inspection_solids: inspection_members[rect]=true
 var sets := _navigation_sets()
 var guard_area := Footprint.inset(world.guard_zone)
 var cells: Dictionary = {}
 for rect in changed_rects:
  var inflated := rect.grow(RADIUS)
  for y in range(maxi(world.grid.region.position.y,floori(inflated.position.y/GRID_SIZE)),mini(world.grid.region.end.y,ceili(inflated.end.y/GRID_SIZE))):
   for x in range(maxi(world.grid.region.position.x,floori(inflated.position.x/GRID_SIZE)),mini(world.grid.region.end.x,ceili(inflated.end.x/GRID_SIZE))): cells[Vector2i(x,y)]=true
 span("grid_collect",audit_mark)
 audit_mark=Time.get_ticks_usec()
 for cell in cells:
  for triple in sets:
   var point: Vector2 = triple[0].get_point_position(cell)
   var blocked = not world.inside_room(point)
   var inspection_blocked = blocked
   for rect in world.body_index.nearby(point,0):
    if not rect.has_point(point): continue
    blocked=true
    break
   for rect in world.inspection_body_index.nearby(point,0):
    if rect.has_point(point): inspection_blocked=true;break
   for rect in world.solid_index.nearby(point,RADIUS):
    if not world._circle_hits_rect(point,RADIUS,rect): continue
    blocked=true
    if inspection_members.has(rect): inspection_blocked=true
    if inspection_blocked: break
   _set_solid(triple[0],cell,blocked)
   _set_solid(triple[1],cell,blocked or not guard_area.has_point(point))
   _set_solid(triple[2],cell,inspection_blocked)

 span("grid_cells",audit_mark)

func _finish_navigation(layout: Array):
 var mark:=Time.get_ticks_usec()
 super._finish_navigation(layout)
 span("grid_finish",mark)
func _init(owner_world):
 super(owner_world)
 connectivity=preload("res://qa/smoothness_20261014/connectivity.gd").new()
