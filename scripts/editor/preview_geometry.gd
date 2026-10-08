extends RefCounted

# Geometry-only adapter for the runtime painters. No actors, clock or navigation.
var walls: Array[Rect2] = []
var fixtures: Array = []
var fixtures_revision: int = 0
var wall_surfaces := {}
var roofed_cells: Array = []
var room_visibility = null
var access_doors: Array = []
var dorm_doors: Array = []
var art_textures := {}
var bounds := Rect2()
var door := Rect2()
var crate := Rect2()
var door_open := false
var portal_cuts: Array[Rect2] = []

func rect(values: Array) -> Rect2: return Rect2(values[0],values[1],values[2],values[3])

func update(data: Dictionary, show_roofs: bool) -> void:
	fixtures_revision += 1
	bounds = rect(data.get("bounds",[0,0,100,100]))
	walls.clear()
	for values in data.get("walls",[]): walls.append(rect(values))
	fixtures.clear()
	for entry in data.get("fixtures",[]):
		var copy: Dictionary = entry.duplicate(true)
		copy.rect = rect(entry.rect)
		fixtures.append(copy)
	wall_surfaces.clear()
	for surface in data.get("architecture",{}).get("wall_surfaces",[]): wall_surfaces[int(surface.wall_index)] = surface
	access_doors.clear()
	dorm_doors.clear()
	for gate in data.get("dorm_doors",[]):
		var copy: Dictionary = gate.duplicate(true)
		copy.rect = rect(gate.rect)
		copy.closed = false
		dorm_doors.append(copy)
	for gate in data.get("access_doors",[]):
		var copy: Dictionary = gate.duplicate(true)
		copy.rect = rect(gate.rect)
		copy.closed = bool(gate.get("initial_closed",true))
		access_doors.append(copy)
	roofed_cells.clear()
	if show_roofs:
		for cell in data.get("confinement",{}).get("cells",[]):
			if not cell.get("building",{}).get("roofed",false): continue
			var copy: Dictionary = cell.building.duplicate(true)
			copy.rect = rect(cell.rect)
			copy.door_id = str(cell.door_id)
			roofed_cells.append(copy)
	door = rect(data.get("door",[0,0,20,20]))
	crate = rect(data.get("crate",[0,0,20,20]))

func is_under_roof(point: Vector2) -> bool:
	return roofed_cells.any(func(cell): return cell.rect.has_point(point))

func wall_is_roofed(index: int) -> bool:
	return roofed_cells.any(func(cell): return cell.rect.grow(1).encloses(walls[index]))

func access_by_id(id: String) -> Dictionary:
	for gate in access_doors:
		if str(gate.id) == id: return gate
	return {}
