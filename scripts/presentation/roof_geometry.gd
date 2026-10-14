extends RefCounted

const DoorGeometry = preload("res://scripts/presentation/doorway_geometry.gd")

# Roofs follow the existing wall envelope; the walkable region and every
# collision/door remain owned by the map. No south-facing building prefab.
static func plan(world, room: Dictionary) -> Dictionary:
	# Standalone prefabs can declare a roof independently of their ground body.
	if room.get("roof_rect") is Array and room.roof_rect.size()==4:
		var r: Array = room.roof_rect
		var authored := Rect2(r[0],r[1],r[2],r[3])
		var openings: Array[Rect2] = []
		for cut: Array in room.get("roof_cutouts",[]):
			openings.append(Rect2(authored.position+Vector2(cut[0],cut[1])*authored.size,Vector2(cut[2],cut[3])*authored.size))
		var ports: Array = []
		# Compound rooms author the roof outline separately from their foot
		# bounds, but keep the same real doorway silhouettes as rectangular rooms.
		if room.has("room_parts"):
			for gate in world.access_doors:
				if str(gate.id) not in room.door_ids: continue
				var aperture := DoorGeometry.opening(world,gate)
				ports.append({"id":str(gate.id),"rect":gate.rect,"opening":aperture,"visual_rect":DoorGeometry.projected_rect(world,gate)})
				var clipped := aperture.intersection(authored)
				if clipped.has_area(): openings.append(clipped)
		return {"roof":authored,"cutouts":openings,"ports":ports,"membrane_cutouts":openings,"panels":subtract_all(authored,openings)}
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
					# Rounded lower corners have a 20px upward arc. The actual
					# horizontal coping begins 100px above the solid foot line.
					var coping_y:=wall.position.y
					if surface.has("grid_tile_asset") and wall.size.y>=100:
						coping_y=solid.position.y-float(surface.get("coping_elevation",100.0))
					bottom = minf(bottom,coping_y)
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
	var membrane_cuts: Array[Rect2] = []
	var ports: Array = []
	var gates: Array = world.access_doors.duplicate()
	gates.append_array(world.dorm_doors)
	# Ungated authored doors need the same projected aperture as their art.
	# Cutting only the missing collision span let roofs cover the upper half
	# of side doors and left a mismatched strip beside the threshold.
	for fixture in world.fixtures:
		if not DoorGeometry.managed_fixture(fixture) or DoorGeometry.controlled_fixture(fixture):continue
		var authored: Dictionary = fixture.duplicate(true)
		authored.id = "fixture:"+str(fixture.get("id",fixture.rect))
		gates.append(authored)
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
		# Wall trims need a small clearance margin, but a horizontal roof
		# ends flush at the threshold: that margin must not expose floor.
		var aperture: Rect2 = (opening if DoorGeometry.art_spec(gate).get("expose_closed_frame",false) else DoorGeometry.projected_rect(world,gate)).intersection(roof)
		if DoorGeometry.art_spec(gate).get("roof_occludes_door",false):
			# The roof masks the inward half of the thick frame. Wall trims
			# still use the full art opening; only the membrane cut is narrower.
			aperture = DoorGeometry.projected_rect(world,gate).intersection(roof)
		if aperture.has_area():membrane_cuts.append(aperture)
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
					if clipped.has_area(): cutouts.append(clipped);membrane_cuts.append(clipped)
			cursor = maxf(cursor,span.y)
	var membrane := roof
	if room.get("roof_sealed",false):
		# A north-entry building may keep its complete exterior roof while
		# retaining the exact door ports/cuts used by movement and wall trims.
		# Inset the membrane under the original 20-unit north/side coping;
		# keep the south edge flush with its existing front facade.
		membrane = Rect2(roof.position+Vector2(20,20),roof.size-Vector2(40,20))
		membrane_cuts.clear()
	return {"roof":roof,"cutouts":cutouts,"ports":ports,"membrane_cutouts":membrane_cuts,"panels":subtract_all(membrane,membrane_cuts)}

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
		if room.has("roof_outline"):
			boundaries.clear()
			var outline: Array = room.roof_outline
			for i in range(outline.size()):
				var a := r.position+Vector2(outline[i][0],outline[i][1])*r.size
				var b := r.position+Vector2(outline[(i+1)%outline.size()][0],outline[(i+1)%outline.size()][1])*r.size
				if is_equal_approx(a.y,b.y): boundaries.append(Rect2(minf(a.x,b.x),a.y,absf(b.x-a.x),28))
				else: boundaries.append(Rect2(a.x-20 if b.y>a.y else a.x,minf(a.y,b.y),20,absf(b.y-a.y)))
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
