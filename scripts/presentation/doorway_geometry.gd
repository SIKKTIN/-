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
	if rect.size.y > rect.size.x: return rect
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
	return rect.grow(3)

static func fixture_cuts(world) -> Array[Rect2]:
	var cuts: Array[Rect2] = []
	for fixture in world.fixtures:
		if managed_fixture(fixture) and not controlled_fixture(fixture):
			cuts.append(opening(world,{"rect":fixture.rect}))
	return cuts
