extends RefCounted

const DoorGeometry = preload("res://scripts/presentation/doorway_geometry.gd")

# Roofs follow the existing wall envelope; the walkable region and every
# collision/door remain owned by the map. No south-facing building prefab.
static func plan(world, room: Dictionary) -> Dictionary:
	var area: Rect2 = room.area
	var left := area.position.x
	var right := area.end.x
	var top := area.position.y
	var bottom := area.end.y
	var front_found := false
	var side_solids := {"west":[],"east":[]}
	for index in range(world.walls.size()):
		var wall: Rect2 = world.walls[index]
		var surface: Dictionary = world.wall_surfaces.get(index,{})
		var pieces: Array = surface.get("collision_parts",[[0,0,wall.size.x,wall.size.y]])
		for piece in pieces:
			var solid := Rect2(wall.position+Vector2(piece[0],piece[1]),Vector2(piece[2],piece[3]))
			if not solid.has_area(): continue
			if solid.size.x > solid.size.y:
				if solid.end.x <= area.position.x or solid.position.x >= area.end.x: continue
				if absf(solid.end.y-area.position.y) <= 24:
					top = minf(top,wall.position.y)
				if solid.position.y >= area.end.y-40 and solid.position.y <= area.end.y+80:
					bottom = minf(bottom,wall.position.y)
					front_found = true
			else:
				if solid.end.y <= area.position.y or solid.position.y >= area.end.y: continue
				if absf(solid.end.x-area.position.x) <= 4:
					left = minf(left,solid.position.x)
					side_solids.west.append(Vector2(maxf(area.position.y,solid.position.y),minf(area.end.y,solid.end.y)))
				if absf(solid.position.x-area.end.x) <= 4:
					right = maxf(right,solid.end.x)
					side_solids.east.append(Vector2(maxf(area.position.y,solid.position.y),minf(area.end.y,solid.end.y)))
	# Narrow legacy wall profiles need only their cap/elevation, not a new facade.
	if not front_found: bottom = area.end.y
	var roof := Rect2(left,top,maxf(1,right-left),maxf(1,bottom-top))
	var cutouts: Array[Rect2] = []
	var ports: Array = []
	var gates: Array = world.access_doors.duplicate()
	gates.append_array(world.dorm_doors)
	for gate in gates:
		var rect: Rect2 = gate.rect
		var point := rect.get_center()
		var side := ""
		# A side entrance belongs to the room containing its physical foot
		# line. The old header margin also assigned it to the next room.
		if rect.size.y > rect.size.x and point.y >= area.position.y and point.y <= area.end.y:
			if absf(point.x-area.position.x) <= 44: side = "west"
			elif absf(point.x-area.end.x) <= 44: side = "east"
		if point.x >= area.position.x and point.x <= area.end.x:
			if absf(point.y-area.position.y) <= 44: side = "north"
			elif absf(point.y-area.end.y) <= 44: side = "south"
		if side.is_empty(): continue
		var opening := DoorGeometry.opening(world,gate)
		ports.append({"side":side,"rect":rect,"visual_rect":DoorGeometry.projected_rect(world,gate),"opening":opening,"id":str(gate.get("id","dorm-%d" % int(gate.get("actor_id",0))))})
		var clipped := opening.intersection(roof)
		if clipped.has_area(): cutouts.append(clipped)
	# Ungated connecting passages also remain open: a shared wall's missing
	# span is a portal, even when the map has no access-door object there.
	for side in ["west","east"]:
		var occupied: Array = side_solids[side]
		if occupied.is_empty(): continue
		occupied.sort_custom(func(a,b): return a.x<b.x)
		var cursor := area.position.y
		occupied.append(Vector2(area.end.y,area.end.y))
		for span in occupied:
			if span.x-cursor >= 36:
				var opening := Rect2(roof.position.x,cursor,maxf(3,area.position.x-roof.position.x+3),span.x-cursor) if side=="west" else Rect2(area.end.x-3,cursor,maxf(3,roof.end.x-area.end.x+3),span.x-cursor)
				if not ports.any(func(p): return p.side==side and opening.grow(4).has_point(p.rect.get_center())):
					ports.append({"id":"open-passage","side":side,"rect":opening})
					var clipped := opening.intersection(roof)
					if clipped.has_area(): cutouts.append(clipped)
			cursor = maxf(cursor,span.y)
	return {"roof":roof,"cutouts":cutouts,"ports":ports,"panels":subtract_all(roof,cutouts)}

static func subtract_all(area: Rect2, cutouts: Array) -> Array[Rect2]:
	var parts: Array[Rect2] = [area]
	for cutout in cutouts:
		var next: Array[Rect2] = []
		for part in parts:
			var hit := part.intersection(cutout)
			if not hit.has_area():
				next.append(part)
				continue
			for piece in [Rect2(part.position,Vector2(part.size.x,hit.position.y-part.position.y)),Rect2(part.position.x,hit.end.y,part.size.x,part.end.y-hit.end.y),Rect2(part.position.x,hit.position.y,hit.position.x-part.position.x,hit.size.y),Rect2(hit.end.x,hit.position.y,part.end.x-hit.end.x,hit.size.y)]:
				if piece.size.x > 0.01 and piece.size.y > 0.01: next.append(piece)
		parts = next
	return parts

# Shared, permanent edge geometry for rendering, movement and editor overlays.
# Derive once per map; a roof visibility change never changes these pieces.
static func wall_edge_clips(world, rooms: Array, portal_cuts: Array) -> Dictionary:
	var strips: Array[Rect2] = []
	for room in rooms:
		var r: Rect2 = room.roof_plan.roof
		var boundaries: Array[Rect2] = [Rect2(r.position,Vector2(r.size.x,28)),Rect2(r.position,Vector2(20,r.size.y)),Rect2(r.end.x-20,r.position.y,20,r.size.y),Rect2(r.position.x,r.end.y,r.size.x,28)]
		for boundary in boundaries: strips.append_array(subtract_all(boundary,room.roof_plan.cutouts))
	var result := {}
	for index in world.wall_surfaces:
		var surface: Dictionary = world.wall_surfaces[index]
		if not surface.has("grid_tile_asset") or not surface.get("render_enabled",true): continue
		var clips: Array[Rect2] = []
		for strip in strips:
			var hit: Rect2 = world.walls[int(index)].intersection(strip)
			if hit.has_area(): clips.append_array(subtract_all(hit,clips))
		var trimmed: Array[Rect2] = []
		for clip in clips: trimmed.append_array(subtract_all(clip,portal_cuts))
		if not trimmed.is_empty(): result[int(index)] = trimmed
	return result
