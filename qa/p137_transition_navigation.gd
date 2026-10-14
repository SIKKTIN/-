extends "res://qa/p137_pacing_navigation.gd"
var rebuild_ms: Array=[]
var refresh_details: Array=[]
var finish_ms: Array=[]
var cells_ms: Array=[]
var sealed_ms: Array=[]
func _rebuild_navigation() -> void:
	var mark:=Time.get_ticks_usec()
	super._rebuild_navigation()
	rebuild_ms.append((Time.get_ticks_usec()-mark)/1000.0)
func _refresh_navigation_cells(changed_rects: Array[Rect2]) -> void:
	var checkpoint:=Time.get_ticks_usec()
	if world.solid_index.revision != world.obstacle_revision: world.solid_index.rebuild(world.static_solids,world.obstacle_revision)
	if world.body_index.revision != world.obstacle_revision: world.body_index.rebuild(world.body_solids,world.obstacle_revision)
	# Inspection obstacles are a subset: only dorm leaves are omitted. One
	# spatial query can calculate both masks without rebuilding both indexes.
	var inspection_members: Dictionary = {}
	var inspection_bodies: Dictionary = {}
	for rect in world.inspection_solids: inspection_members[rect]=true
	for rect in world.inspection_body_solids: inspection_bodies[rect]=true
	var sets := _navigation_sets()
	var guard_area := Footprint.inset(world.guard_zone)
	var index_ms: float=(Time.get_ticks_usec()-checkpoint)/1000.0
	checkpoint=Time.get_ticks_usec()
	var cells: Dictionary = {}
	for rect in changed_rects:
		var inflated := rect.grow(RADIUS)
		for y in range(maxi(world.grid.region.position.y,floori(inflated.position.y/GRID_SIZE)),mini(world.grid.region.end.y,ceili(inflated.end.y/GRID_SIZE))):
			for x in range(maxi(world.grid.region.position.x,floori(inflated.position.x/GRID_SIZE)),mini(world.grid.region.end.x,ceili(inflated.end.x/GRID_SIZE))): cells[Vector2i(x,y)]=true
	for cell in cells:
		for triple in sets:
			var point: Vector2 = triple[0].get_point_position(cell)
			var blocked = not world.inside_room(point)
			var inspection_blocked = blocked
			for rect in world.body_index.nearby(point,0):
				if not rect.has_point(point): continue
				blocked=true
				if inspection_bodies.has(rect): inspection_blocked=true
				if inspection_blocked: break
			for rect in world.solid_index.nearby(point,RADIUS):
				if not world._circle_hits_rect(point,RADIUS,rect): continue
				blocked=true
				if inspection_members.has(rect): inspection_blocked=true
				if inspection_blocked: break
			_set_solid(triple[0],cell,blocked)
			_set_solid(triple[1],cell,blocked or not guard_area.has_point(point))
			_set_solid(triple[2],cell,inspection_blocked)

	refresh_details.append({"index_ms":index_ms,"cells_ms":(Time.get_ticks_usec()-checkpoint)/1000.0,"cells":cells.size()})

func _sealed_room_separates(a: Vector2,b: Vector2) -> bool:
	var mark:=Time.get_ticks_usec()
	var result:=super._sealed_room_separates(a,b)
	sealed_ms.append((Time.get_ticks_usec()-mark)/1000.0)
	return result

func _finish_navigation(layout: Array) -> void:
	var mark:=Time.get_ticks_usec()
	super._finish_navigation(layout)
	finish_ms.append((Time.get_ticks_usec()-mark)/1000.0)
