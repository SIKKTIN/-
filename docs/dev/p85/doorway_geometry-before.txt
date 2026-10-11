extends RefCounted

# Door collision stays on the foot line. The painted horizontal wall cap is
# above that line; every view uses the same projection, in either door state.
static func managed_fixture(fixture: Dictionary) -> bool:
	return controlled_fixture(fixture) or str(fixture.get("asset_id","")).begins_with("prison_gate_") or str(fixture.get("asset_id","")).begins_with("doorway_")

static func controlled_fixture(fixture: Dictionary) -> bool:
	return fixture.has("access_id") or fixture.has("dorm_actor_id") or fixture.get("primary_gate",false)

static func style_for(gate: Dictionary) -> String:
	if str(gate.get("kind","")) == "open": return "free"
	return "locked" if str(gate.get("kind","")) in ["locked","confinement","primary"] else "grille"

static func projected_rect(world, gate: Dictionary) -> Rect2:
	var rect: Rect2 = gate.rect
	if rect.size.y > rect.size.x:
		var bottom := rect.end.y
		# A horizontal wall's painted elevation can overlap the foot-line
		# collider. Stop the side-door drawing at its stone header, not below
		# it in the next room. Real collision remains the original full rect.
		for index in world.wall_surfaces:
			var surface: Dictionary = world.wall_surfaces[index]
			if not surface.has("grid_tile_asset") or not surface.get("render_enabled",true): continue
			var wall: Rect2 = world.walls[int(index)]
			if wall.position.y<=rect.position.y or wall.position.y>=bottom or wall.size.y<40: continue
			if wall.end.x<=rect.position.x or wall.position.x>=rect.end.x: continue
			if surface.get("collision_parts",[]).any(func(p):return float(p[2])>float(p[3])):
				bottom = wall.position.y
		return Rect2(rect.position,Vector2(rect.size.x,bottom-rect.position.y))
	var top := rect.position.y
	var distance := INF
	for index in world.wall_surfaces:
		var surface: Dictionary = world.wall_surfaces[index]
		if not surface.has("grid_tile_asset"): continue
		var wall: Rect2 = world.walls[int(index)]
		if wall.size.y < 40 or absf(wall.end.y-rect.end.y)>4: continue
		var gap := minf(absf(wall.end.x-rect.position.x),absf(wall.position.x-rect.end.x))
		if gap <= 40 and gap < distance:
			distance = gap
			top = wall.position.y
	return Rect2(rect.position.x,top,rect.size.x,24)

static func opening(world, gate: Dictionary) -> Rect2:
	var rect := projected_rect(world,gate)
	if rect.size.x > rect.size.y:
		# A shallow roof nick, not the old 100-high gate facade cutout.
		return Rect2(rect.position.x-2,rect.position.y-12,rect.size.x+4,52)
	# End boundaries are exact: growing vertically would erase neighbour
	# coping again after the visible door had already been shortened.
	return Rect2(rect.position-Vector2(3,0),rect.size+Vector2(6,0))

static func floor_for(config: Dictionary, rect: Rect2) -> Dictionary:
	var point := rect.get_center()
	var distance := INF
	var result := {}
	for region in config.get("floor_regions",[]):
		if region.get("natural_ground",false): continue
		var values: Array = region.rect
		var area := Rect2(values[0],values[1],values[2],values[3])
		var nearest := point.clamp(area.position,area.end)
		var gap := point.distance_squared_to(nearest)
		if gap < distance:
			distance = gap
			var tile: Array = region.get("tile_size",[640,640])
			result = {"asset_id":str(region.asset_id),"origin":area.position,"tile":Vector2(tile[0],tile[1]),"tint":Color(region.get("tint","#ffffff"))}
	# Older maps use the ordinary global floor and need no terrain bridge.
	return result if distance<=1600 else {}

static func fixture_cuts(world) -> Array[Rect2]:
	var cuts: Array[Rect2] = []
	for fixture in world.fixtures:
		if managed_fixture(fixture) and not controlled_fixture(fixture):
			cuts.append(opening(world,{"rect":fixture.rect}))
	return cuts
