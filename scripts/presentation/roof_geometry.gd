extends RefCounted

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
		if point.y >= area.position.y-140 and point.y <= area.end.y+40:
			if absf(point.x-area.position.x) <= 44: side = "west"
			elif absf(point.x-area.end.x) <= 44: side = "east"
		if point.x >= area.position.x and point.x <= area.end.x:
			if absf(point.y-area.position.y) <= 44: side = "north"
			elif absf(point.y-area.end.y) <= 44: side = "south"
		if side.is_empty(): continue
		ports.append({"side":side,"rect":rect,"id":str(gate.get("id","dorm"))})
		var opening := rect
		if side in ["north","south"]:
			opening = Rect2(rect.position.x-2,rect.end.y-100,rect.size.x+4,100)
		else:
			opening = rect.grow(3)
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
