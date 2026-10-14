extends RefCounted

# Shared visible apertures. Ground movement still uses feet; door passage
# additionally tests the independent projected body against jambs/leaves.
# Architecture keeps the calibrated aperture when character scale changes.
const SIDE_SPAN := 166.4
static var art_definitions: Dictionary = {}
static func primary_spec(world) -> Dictionary:
	# The map fixture supplies artwork; the world's primary gate keeps its rules.
	var result: Dictionary = {}
	for fixture in world.fixtures:
		if fixture.get("primary_gate",false):
			result = art_spec(fixture).duplicate(true)
			break
	result.merge({"id":"primary","kind":"primary","rect":world.door},true)
	return result

static func art_spec(gate: Dictionary) -> Dictionary:
	var id := str(gate.get("asset_id",""))
	# Existing logical dorm gates and the two extra dorm entrances share the
	# approved side-door assembly without rewriting an editor's saved draft.
	if id.is_empty() and gate.has("actor_id"):
		var r = gate.get("rect",Rect2())
		var size: Vector2 = r.size if r is Rect2 else Vector2(r[2],r[3])
		if size.y>size.x or gate.has("rotation_door_visual_rect"): id = "doorway_dorm_side_open_v1"
	elif str(gate.get("id","")).begins_with("campus-dorm-extra-") and id == "doorway_free_v48":
		id = "doorway_dorm_side_open_v1"
	if not id.begins_with("doorway_"): return gate
	if art_definitions.is_empty(): art_definitions = preload("res://scripts/presentation/prop_catalog.gd").assets()
	var result: Dictionary = art_definitions.get(id,{}).get("door_presentation",{}).duplicate(true)
	result.merge(gate,true)
	if id.begins_with("doorway_dorm_side_") and not gate.has("rotation_quarters"):
		# Side-door patches use the same canonical coordinates as front doors.
		# Collision and painting must agree on the inferred quarter turn.
		var r = gate.get("rect",Rect2())
		var size: Vector2 = r.size if r is Rect2 else Vector2(r[2],r[3])
		result.rotation_quarters = 1 if size.y>size.x else 0
	return result
static func managed_fixture(fixture: Dictionary) -> bool:
	return controlled_fixture(fixture) or str(fixture.get("asset_id","")).begins_with("prison_gate_") or str(fixture.get("asset_id","")).begins_with("doorway_")

static func controlled_fixture(fixture: Dictionary) -> bool:
	return fixture.has("access_id") or fixture.has("dorm_actor_id") or fixture.get("primary_gate",false)

static func style_for(gate: Dictionary) -> String:
	if str(gate.get("kind","")) == "open" and not gate.get("manual_door",false): return "free"
	return "locked" if str(gate.get("kind","")) in ["locked","confinement","primary"] else "grille"

static func projected_rect(world, gate: Dictionary) -> Rect2:
	gate = art_spec(gate)
	if gate.has("rotation_door_visual_rect"):
		var values: Array = gate.rotation_door_visual_rect
		return Rect2(values[0],values[1],values[2],values[3])
	var rect: Rect2 = gate.rect
	if rect.size.y > rect.size.x:
		var bottom := rect.end.y
		# A horizontal wall's painted elevation can overlap the foot-line
		# collider. Stop the side-door drawing at its stone header, not below
		# it in the next room. Short apertures extend upward for body clearance.
		for index in world.wall_surfaces:
			var surface: Dictionary = world.wall_surfaces[index]
			if not surface.has("grid_tile_asset") or not surface.get("render_enabled",true): continue
			var wall: Rect2 = world.walls[int(index)]
			if wall.position.y<=rect.position.y or wall.position.y>=bottom or wall.size.y<40: continue
			if wall.end.x<=rect.position.x or wall.position.x>=rect.end.x: continue
			if surface.get("collision_parts",[]).any(func(p):return float(p[2])>float(p[3])):
				bottom = wall.position.y
		var span := maxf(float(gate.get("side_aperture_span",SIDE_SPAN)),bottom-rect.position.y)
		return Rect2(rect.position.x,bottom-span,rect.size.x,span)
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
	if gate.has("door_art_size"):
		var dims: Array = gate.door_art_size
		return Rect2(rect.get_center().x-float(dims[0])/2,top,float(dims[0]),float(dims[1]))
	return Rect2(rect.position.x,top,rect.size.x,24)

static func opening(world, gate: Dictionary) -> Rect2:
	var rect := projected_rect(world,gate)
	if art_spec(gate).get("expose_closed_frame",false):
		# Frame bounds may end one pixel inside the aperture. Always remove
		# the entire doorway from retained walls, not just its visible steel.
		return closed_art_bounds(world,gate).merge(rect)
	if art_spec(gate).get("clear_wall_facade",false):
		# Raised modular doors own the complete facade opening in both states.
		# Shallow roof-only cuts leave obsolete lintels behind transparent jambs.
		return rect
	if rect.size.x > rect.size.y:
		# A shallow roof nick, not the old 100-high gate facade cutout.
		return Rect2(rect.position.x-2,rect.position.y-12,rect.size.x+4,52)
	# Side thresholds already cover the entire visible aperture. Expanding
	# the cut exposes a floor sliver on either side of the steel jambs.
	return rect

static func closed_art_bounds(world, gate: Dictionary) -> Rect2:
	gate = art_spec(gate)
	var rect := projected_rect(world,gate)
	var result := Rect2()
	var first := true
	var dims: Array = gate.get("door_art_size",[rect.size.x,rect.size.y])
	for values in gate.get("closed_visual_solid_parts",[]):
		var part := Rect2(values[0],values[1],values[2],values[3])
		match posmod(int(gate.get("rotation_quarters",0)),4):
			1: part = Rect2(float(dims[1])-part.end.y,part.position.x,part.size.y,part.size.x)
			2: part.position = Vector2(dims[0],dims[1])-part.end
			3: part = Rect2(part.position.y,float(dims[0])-part.end.x,part.size.y,part.size.x)
		part.position += rect.position
		result = part if first else result.merge(part)
		first = false
	return rect if first else result

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
		# Floor regions paint in order; later overlapping room floors win.
		if gap <= distance:
			distance = gap
			var tile: Array = region.get("tile_size",[640,640])
			result = {"asset_id":str(region.asset_id),"origin":Vector2(region.get("tile_origin",[area.position.x,area.position.y])[0],region.get("tile_origin",[area.position.x,area.position.y])[1]),"tile":Vector2(tile[0],tile[1]),"tint":Color(region.get("tint","#ffffff")),"manifest":region.get("manifest",config.get("terrain_manifest","res://art/environment/factory_v45/manifest.json"))}
	# Older maps use the ordinary global floor and need no terrain bridge.
	return result if distance<=1600 else {}

static func fixture_cuts(world) -> Array[Rect2]:
	var cuts: Array[Rect2] = []
	for fixture in world.fixtures:
		if managed_fixture(fixture) and not controlled_fixture(fixture):
			cuts.append(opening(world,fixture))
		elif fixture.get("primary_gate",false) and art_spec(fixture).get("clear_wall_facade",false):
			cuts.append(opening(world,primary_spec(world)))
	return cuts
