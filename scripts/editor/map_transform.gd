@tool
extends RefCounted

# Building authoring owns selection snapshots, spatial dependencies and undo.
const Geometry = preload("res://scripts/core/spatial_transform.gd")
static func point(p: Vector2, pivot: Vector2, turns: int, offset := Vector2.ZERO) -> Vector2:
	return Geometry.point(p,pivot,turns,offset)
static func rectangle(r: Rect2, pivot: Vector2, turns: int, offset := Vector2.ZERO) -> Rect2:
	return Geometry.rectangle(r,pivot,turns,offset)
static func coords(values: Array, pivot: Vector2, turns: int, offset: Vector2) -> Array:
	return Geometry.coords(values,pivot,turns,offset)

static func bounds(document, refs: Array) -> Rect2:
	var area := Rect2()
	var first := true
	for ref in refs:
		var r: Rect2 = document.geometry(ref)
		if first: area = r; first = false
		else: area = area.expand(r.position).expand(r.end)
	return area

static func capture(document, refs: Array, include_environment := true) -> Dictionary:
	var result := {"objects":[],"extras":[],"bounds":bounds(document,refs)}
	var adapter
	var doors = load("res://scripts/presentation/doorway_geometry.gd")
	for ref in refs:
		var item = document.value(ref)
		var entry := {"ref":ref.duplicate(),"value":item.duplicate(true),"rect":document.is_rect(ref)}
		if ref.group=="walls": entry.surface = document.wall_surface(int(ref.index)).duplicate(true)
		if ref.group in ["fixtures","access_doors","dorm_doors"] and (ref.group!="fixtures" or doors.managed_fixture(item)):
			if adapter==null:
				adapter = load("res://scripts/editor/preview_geometry.gd").new()
				adapter.update(document.data,false)
			var gate: Dictionary = item.duplicate(true)
			gate.rect = document.geometry(ref)
			var visual: Rect2 = doors.projected_rect(adapter,gate)
			entry.door_visual_rect = [visual.position.x,visual.position.y,visual.size.x,visual.size.y]
			var presentation: Dictionary = doors.art_spec(gate)
			if presentation.get("piece_depth",false): entry.door_base_quarters = int(presentation.get("rotation_quarters",0))
		result.objects.append(entry)
	if include_environment:
		var selected_rooms: Array[String] = []
		var has_shell := false
		for entry in result.objects:
			if entry.ref.group=="visibility_rooms": selected_rooms.append(str(entry.value.id))
			if entry.ref.group=="walls": has_shell = true
		for key in ["floor_regions","terrain_patches","ground_details"]:
			for index in range(document.data.get(key,[]).size()):
				var item: Dictionary = document.data[key][index]
				var follows := contained(item,result.bounds)
				if key=="floor_regions" and not item.get("natural_ground",false):
					# Floors include a narrow apron under door jambs and wall faces.
					# A tight shell selection must retain that apron rather than leave
					# an invisible floor behind when moving/copying the building.
					follows = follows or str(item.get("room_id","")) in selected_rooms
					if not follows and has_shell:
						var r: Array = item.rect
						var floor_area := Rect2(r[0],r[1],r[2],r[3])
						follows = result.bounds.grow(40).encloses(floor_area) and floor_area.grow(40).encloses(result.bounds)
				if follows: result.extras.append({"path":[key,index],"value":item.duplicate(true)})
		for index in range(document.data.get("architecture",{}).get("boundary_solids",[]).size()):
			var values: Array = document.data.architecture.boundary_solids[index]
			if result.bounds.grow(1).encloses(Rect2(values[0],values[1],values[2],values[3])):
				result.extras.append({"path":["architecture","boundary_solids",index],"value":values.duplicate()})
		for key in ["workshop","cafeteria"]:
			var item: Dictionary = document.data.get(key,{})
			if item.has("room_rect") and result.bounds.grow(1).encloses(Rect2(item.room_rect[0],item.room_rect[1],item.room_rect[2],item.room_rect[3])):
				result.extras.append({"path":[key],"value":item.duplicate(true)})
	return result

static func contained(item: Dictionary, area: Rect2) -> bool:
	if item.has("rect"):
		var r: Array = item.rect
		return area.grow(1).encloses(Rect2(r[0],r[1],r[2],r[3]))
	for key in ["position","from","to"]:
		if item.has(key) and not area.has_point(Vector2(item[key][0],item[key][1])): return false
	return item.has("position") or item.has("from")

static func transform_item(original: Dictionary, pivot: Vector2, turns: int, offset: Vector2) -> Dictionary:
	var item: Dictionary = original.duplicate(true)
	for key in ["rect","position","room_rect","roof_rect","entrance","evacuation","spawn","release","overseer_start","from","to","clip_rect","rotation_door_visual_rect"]:
		if item.get(key) is Array and item[key].size() in [2,4]: item[key] = coords(item[key],pivot,turns,offset)
	for key in ["patrol","routine"]:
		for index in range(item.get(key,[]).size()):
			var entry = item[key][index]
			if entry is Array and entry.size()==2: item[key][index] = coords(entry,pivot,turns,offset)
			elif entry is Dictionary and entry.has("position"): entry.position = coords(entry.position,pivot,turns,offset)
	if turns!=0:
		for key in ["room_parts","roof_cutouts"]:
			for i in range(item.get(key,[]).size()):
				item[key][i] = coords(item[key][i],Vector2(.5,.5),turns,Vector2.ZERO)
		for key in ["polygon","roof_outline"]:
			for i in range(item.get(key,[]).size()):
				item[key][i] = coords(item[key][i],Vector2(.5,.5),turns,Vector2.ZERO)
		for section: Dictionary in item.get("roof_sections",[]):
			section.rect = coords(section.rect,Vector2(.5,.5),turns,Vector2.ZERO)
		for detail: Dictionary in item.get("roof_details",[]):
			detail.position = coords(detail.position,Vector2(.5,.5),turns,Vector2.ZERO)
	if original.has("draw_depth") and original.has("rect"):
		var r: Array = original.rect
		var anchor: Array = original.get("rotation_draw_anchor",[float(r[0])+float(r[2])/2,float(original.draw_depth)])
		var transformed: Array = coords(anchor,pivot,turns,offset)
		item.draw_depth = transformed[1]
		if turns!=0 or original.has("rotation_draw_anchor"): item.rotation_draw_anchor = transformed
	if turns!=0 and (item.has("asset_id") or item.has("rotation_quarters")):
		var quarters := posmod(int(item.get("rotation_quarters",0))+turns,4)
		if quarters:
			if original.has("rotation_quarters") and int(original.rotation_quarters)==0: item.rotation_zero_explicit = original.rotation_quarters
			item.rotation_quarters = quarters
		else:
			if item.has("rotation_zero_explicit"): item.rotation_quarters = item.rotation_zero_explicit
			else: item.erase("rotation_quarters")
			item.erase("rotation_zero_explicit")
			item.erase("rotation_draw_anchor")
	return item

static func apply(document, snapshot: Dictionary, turns: int, offset := Vector2.ZERO) -> void:
	var pivot: Vector2 = snapshot.get("pivot",snapshot.bounds.get_center())
	for entry in snapshot.objects:
		var ref: Dictionary = entry.ref
		var item = transform_item(entry.value,pivot,turns,offset) if entry.value is Dictionary else coords(entry.value,pivot,turns,offset)
		if turns!=0 and entry.has("door_visual_rect"):
			var q := posmod(int(entry.get("door_base_quarters",entry.value.get("rotation_quarters",0)))+turns,4)
			if q:
				item.rotation_quarters = q
				item.rotation_door_visual_rect = coords(entry.door_visual_rect,pivot,turns,offset)
			else: item.erase("rotation_door_visual_rect")
		if int(ref.index)<0: document.data[ref.group] = item
		else: document.collection(ref.group)[int(ref.index)] = item
		if ref.group=="walls" and not entry.surface.is_empty():
			var surface: Dictionary = entry.surface.duplicate(true)
			var q := posmod(int(surface.get("rotation_quarters",0))+turns,4)
			if q: surface.rotation_quarters = q
			else: surface.erase("rotation_quarters")
			var r: Array = entry.value
			var dimensions := Vector2(r[2],r[3])
			var new_dimensions := Vector2(dimensions.y,dimensions.x) if posmod(turns,2) else dimensions
			for index in range(surface.get("collision_parts",[]).size()):
				var p: Array = entry.surface.collision_parts[index]
				var area := rectangle(Rect2(p[0],p[1],p[2],p[3]),dimensions/2,turns,new_dimensions/2-dimensions/2)
				surface.collision_parts[index] = [area.position.x,area.position.y,area.size.x,area.size.y]
			var target: Dictionary = document.wall_surface(int(ref.index))
			target.clear()
			target.merge(surface)
	for entry in snapshot.extras:
		var parent = document.data
		for index in range(entry.path.size()-1): parent = parent[entry.path[index]]
		parent[entry.path[-1]] = transform_item(entry.value,pivot,turns,offset) if entry.value is Dictionary else coords(entry.value,pivot,turns,offset)
	document.changed.emit()
