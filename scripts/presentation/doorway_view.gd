extends Node2D

const Geometry = preload("res://scripts/presentation/doorway_geometry.gd")
const TextureLoader = preload("res://scripts/presentation/world_texture.gd")
const MANIFEST := "res://art/architecture/doorways_v49/manifest.json"
const LOCKED_MANIFEST := "res://art/architecture/doorways_v48/manifest.json"
static var textures: Dictionary = {}
static var floor_definitions: Dictionary = {}
var world
var room_config: Dictionary = {}
var doors: Array = []
var door_by_id: Dictionary = {}
var revision := -1
var geometry_builds := 0

class Door extends Node2D:
	var owner_world
	var id := ""
	var style := "free"
	var gate: Dictionary = {}
	var visual_rect := Rect2()
	var length := 0.0
	var depth := 24.0
	var closed := false
	var primary := false
	var texture: Texture2D
	var draw_builds := 0
	var floor_texture: Texture2D
	var floor_asset := ""
	var floor_origin := Vector2.ZERO
	var floor_tile := Vector2(640,640)
	var floor_tint := Color.WHITE
	var vertical := false
	var end_cap := 7.0

	func configure(source_world, spec: Dictionary, rect: Rect2, art: Texture2D, floor_spec: Dictionary, ground: Texture2D) -> void:
		owner_world = source_world
		gate = spec
		id = str(spec.get("id",""))
		style = Geometry.style_for(spec)
		primary = str(spec.get("kind","")) == "primary"
		visual_rect = rect
		texture = art
		vertical = rect.size.y > rect.size.x
		length = rect.size.y if vertical else rect.size.x
		depth = rect.size.x if vertical else rect.size.y
		position = rect.position+Vector2(rect.size.x,0) if vertical else rect.position
		rotation = PI/2 if vertical else 0.0
		end_cap = minf(7,length*0.07) if vertical else 7.0
		floor_texture = ground
		if floor_texture != null:
			floor_asset = str(floor_spec.asset_id)
			floor_origin = floor_spec.origin
			floor_tile = floor_spec.tile
			floor_tint = floor_spec.tint
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		refresh(true)

	func refresh(force := false) -> void:
		var next: bool = not owner_world.door_open if primary else bool(gate.get("closed",false))
		if style == "free": next = false
		if not force and next == closed: return
		closed = next
		queue_redraw()

	func hardware_end() -> float:
		return length if vertical else length+end_cap

	func _paint_threshold() -> void:
		if floor_texture == null: return
		var corners := PackedVector2Array([Vector2.ZERO,Vector2(length,0),Vector2(length,depth),Vector2(0,depth)])
		var uvs := PackedVector2Array()
		for corner in corners:
			# The steel rotates for side doors; the floor keeps the corridor's
			# world registration and orientation, including its partial tile.
			uvs.append((position+corner.rotated(rotation)-floor_origin)/floor_tile)
		draw_polygon(corners,PackedColorArray([floor_tint,floor_tint,floor_tint,floor_tint]),uvs,floor_texture)

	func _draw() -> void:
		draw_builds += 1
		_paint_threshold()
		if style != "locked":
			_paint_flush_door()
			return
		var size := texture.get_size()
		var cap := size.x*0.057
		# Keep the leading cap in the stone; a side-door trailing cap stays
		# inside its shortened span, before the neighbouring wall header.
		draw_texture_rect_region(texture,Rect2(-7,0,7,depth),Rect2(0,0,cap,size.y))
		var trailing := length-end_cap if vertical else length
		draw_texture_rect_region(texture,Rect2(trailing,0,end_cap,depth),Rect2(size.x-cap,0,cap,size.y))
		if closed:
			draw_texture_rect_region(texture,Rect2(0,2,trailing,depth-4),Rect2(cap,0,size.x-cap*2,size.y))
		elif style == "locked":
			# The exposed latch remains at the jamb after the leaf retracts.
			draw_texture_rect_region(texture,Rect2(trailing,depth*0.23,minf(6,end_cap),depth*0.54),Rect2(size.x*0.87,size.y*0.2,size.x*0.047,size.y*0.6))
	func hardware_rects() -> Array[Rect2]:
		# End hardware stays in the original aperture, never the neighbour's wall.
		# Three-pixel side caps flattened the source's round bolts into subpixels.
		var cap := minf(8.0,length*0.20) if vertical else minf(9.0,length*0.10)
		return [Rect2(0,0,cap,depth),Rect2(length-cap,0,cap,depth)]

	func _paint_end_cap(rect: Rect2, source: Rect2) -> void:
		draw_texture_rect_region(texture,rect,source,Color(1.08,1.08,1.06))
		# Readable at gameplay scale, within the cached doorway drawing commands.
		draw_rect(rect.grow(-0.5),Color("25353d"),false,1.0)
		draw_line(rect.position+Vector2(1,1),rect.position+Vector2(rect.size.x-1,1),Color("a7b5b9"),1.0,true)
		var radius := minf(1.6,rect.size.x*0.18)
		for offset in [0.23,0.77]:
			var bolt := rect.position+Vector2(rect.size.x*0.5,rect.size.y*offset)
			draw_circle(bolt,radius+0.5,Color("283035"))
			draw_circle(bolt,radius,Color("c3a16a"))
			draw_circle(bolt-Vector2(0.4,0.4),0.45,Color("eee0b4"))

	func _paint_flush_door() -> void:
		var size := texture.get_size()
		var source_cap := size.x*0.105
		var caps := hardware_rects()
		_paint_end_cap(caps[0],Rect2(0,0,source_cap,size.y))
		_paint_end_cap(caps[1],Rect2(size.x-source_cap,0,source_cap,size.y))
		var middle := Rect2(caps[0].end.x,0,length-caps[0].size.x*2,depth)
		var source := Rect2(source_cap,0,size.x-source_cap*2,size.y)
		if style == "free" or closed:
			draw_texture_rect_region(texture,middle,source)
		else:
			# Keep a visible compact leaf at one end, with a clear crossing path.
			middle.size.x = minf(5.0,middle.size.x*0.15)
			draw_texture_rect_region(texture,middle,source)

static func load_textures() -> Dictionary:
	if textures.is_empty():
		var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LOCKED_MANIFEST))
		for asset in legacy.assets:
			if str(asset.id)=="door_locked_v48": textures.locked = TextureLoader.load_asset(asset)
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		for asset in manifest.assets:
			textures[str(asset.style)] = TextureLoader.load_asset(asset)
	return textures

func configure(source_world, rooms: Array, config: Dictionary = {}) -> void:
	world = source_world
	room_config = config
	name = "RetainedDoorways"
	# Roof openings already cut out this footprint. Door hardware is ground
	# decoration and must never cover a body's feet or head while crossing.
	z_index = 12
	geometry_builds += 1
	for child in get_children(): child.free()
	doors.clear()
	door_by_id.clear()
	var art := load_textures()
	var projected := {}
	var free_ports := {}
	for room in rooms:
		for port in room.roof_plan.ports:
			if port.id == "open-passage":
				free_ports[str(port.rect)] = port.rect
			else: projected[str(port.id)] = port.visual_rect
	for gate in world.access_doors:
		_add(gate,projected.get(str(gate.id),Geometry.projected_rect(world,gate)),art)
	for index in range(world.dorm_doors.size()):
		var gate: Dictionary = world.dorm_doors[index]
		# Own dictionary reference for state, stable for the current map lifetime.
		gate.id = "dorm-%d" % index
		gate.kind = str(gate.get("kind","dorm"))
		_add(gate,projected.get(str(gate.id),Geometry.projected_rect(world,gate)),art)
	_add({"id":"primary","kind":"primary","rect":world.door},Geometry.projected_rect(world,{"rect":world.door}),art)
	# Earlier maps painted ungated entrances with a permanently open gate
	# sprite. Replace those too; they are now clear passage ends, not bars.
	for fixture in world.fixtures:
		if not Geometry.managed_fixture(fixture) or Geometry.controlled_fixture(fixture): continue
		var asset := str(fixture.asset_id)
		var free := asset.contains("open") or asset=="doorway_free_v48"
		var spec := {"id":"fixture:"+str(fixture.get("id",fixture.rect)),"kind":"open" if free else "locked" if asset.contains("locked") else "static","rect":fixture.rect,"closed":not free}
		_add(spec,Geometry.projected_rect(world,spec),art)
	for key in free_ports:
		var rect: Rect2 = free_ports[key]
		if not doors.any(func(d):return d.visual_rect.grow(4).intersects(rect)):
			_add({"id":"free:"+key,"kind":"open"},rect,art)
	tick(true)

func _add(gate: Dictionary, rect: Rect2, art: Dictionary) -> void:
	var door := Door.new()
	add_child(door)
	var floor_spec := Geometry.floor_for(room_config,rect)
	door.configure(world,gate,rect,art.get(Geometry.style_for(gate),art.grille),floor_spec,_floor_texture(floor_spec))
	doors.append(door)
	door_by_id[door.id] = door

func _floor_texture(spec: Dictionary) -> Texture2D:
	if spec.is_empty(): return null
	var file := str(room_config.get("terrain_manifest","res://art/environment/factory_v45/manifest.json"))
	if not floor_definitions.has(file):
		if not FileAccess.file_exists(file): return null
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(file))
		var definitions := {}
		for asset in manifest.get("assets",[]): definitions[str(asset.id)] = asset
		floor_definitions[file] = definitions
	var asset: Dictionary = floor_definitions[file].get(str(spec.asset_id),{})
	return null if asset.is_empty() else TextureLoader.load_asset(asset)

func tick(force := false) -> void:
	# Guard movement and room transitions do not rebuild door art or meshes.
	var next: int = world.get("obstacle_revision") if world.get("obstacle_revision") != null else world.fixtures_revision
	if not force and revision == next: return
	revision = next
	for door in doors: door.refresh(force)

func by_id(id: String):
	return door_by_id.get(id)
