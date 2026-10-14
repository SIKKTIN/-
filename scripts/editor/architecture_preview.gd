extends Node2D

const Volume = preload("res://scripts/presentation/world_volume.gd")
const Building = preload("res://scripts/presentation/roof_building.gd")
const Doorways = preload("res://scripts/presentation/doorway_view.gd")
const RoofGeometry = preload("res://scripts/presentation/roof_geometry.gd")
const RoomRules = preload("res://scripts/core/room_visibility.gd")
var world = preload("res://scripts/editor/preview_geometry.gd").new()
var canvas
var profile := {}
var asset_definitions := {}
var font: Font
var room_access = null
var nodes := {}
var signatures := {}
var pending := false
var doorways
var boundary_clips: Dictionary = {}
var full_refreshes := 0
var moving_fixture_refreshes := 0
var group_preview_offset := Vector2.ZERO

func preview_group_offset(refs: Array, offset: Vector2) -> void:
	# Retained selected painters move during drag. Map serialization, floor,
	# room plans and collision rebuild happen once on release, never per motion.
	var delta := offset-group_preview_offset
	if delta==Vector2.ZERO: return
	var moved := {}
	for ref in refs:
		var key := "%s:%d" % ["wall" if ref.group=="walls" else "fixture" if ref.group=="fixtures" else "door" if ref.group=="door" else "none",maxi(0,int(ref.index))]
		if nodes.has(key) and not moved.has(key): nodes[key].position += delta; moved[key] = true
		var id := ""
		if ref.group=="access_doors": id = str(canvas.document.value(ref).id)
		elif ref.group=="dorm_doors": id = "dorm-%d" % int(ref.index)
		elif ref.group=="fixtures":
			var fixture: Dictionary = canvas.document.value(ref)
			if Doorways.Geometry.managed_fixture(fixture):
				id = str(fixture.get("access_id","primary" if fixture.get("primary_gate",false) else "dorm-%d" % int(fixture.dorm_actor_id) if fixture.has("dorm_actor_id") else "fixture:"+str(fixture.get("id",fixture.rect))))
		if not id.is_empty() and not moved.has("door:"+id):
			var door = doorways.by_id(id)
			if door!=null: door.position += delta
			moved["door:"+id] = true
	group_preview_offset = offset

func setup(owner_canvas, render_profile: Dictionary) -> void:
	canvas = owner_canvas
	profile = render_profile
	asset_definitions = canvas.definitions
	font = canvas.font
	world.art_textures = canvas.textures
	canvas.document.changed.connect(schedule_refresh)
	canvas.layers.changed.connect(schedule_refresh)
	refresh()

func schedule_refresh() -> void:
	# Terrain paints during the gesture; rebuild doorway thresholds on release.
	if canvas.painting_floor or canvas.drag_ref.get("group","") == "floor_regions": return
	if pending: return
	pending = true
	call_deferred("refresh")

func refresh() -> void:
	pending = false
	if canvas.document.data.is_empty(): return
	if refresh_moving_fixture(): return
	full_refreshes += 1
	canvas.load_map_textures()
	world.update(canvas.document.data,canvas.layers.is_visible("architecture"))
	var rooms: Array = []
	world.portal_cuts.clear()
	for spec in RoomRules.rooms_for(canvas.document.data):
		var room: Dictionary = spec.duplicate(true)
		room.area = world.rect(room.rect)
		room.roof_plan = RoofGeometry.plan(world,room)
		rooms.append(room)
		for port in room.roof_plan.ports:
			if port.has("opening") and port.opening not in world.portal_cuts: world.portal_cuts.append(port.opening)
	world.portal_cuts.append_array(Doorways.Geometry.fixture_cuts(world))
	boundary_clips = RoofGeometry.wall_edge_clips(world,rooms,world.portal_cuts)
	if not is_instance_valid(doorways):
		doorways = Doorways.new()
		add_child(doorways)
	doorways.configure(world,rooms,canvas.document.data)
	doorways.visible = canvas.layers.is_visible("walls") or canvas.layers.is_visible("fixtures")
	var live := {}
	for kind in ["wall","fixture","door","crate"]:
		var count: int = world.walls.size() if kind == "wall" else world.fixtures.size() if kind == "fixture" else 1
		for index in range(count):
			var key: String = "%s:%d" % [kind,index]
			live[key] = true
			var signature: String = JSON.stringify(world.wall_surfaces.get(index,{})) if kind == "wall" else JSON.stringify(world.fixtures[index].duplicate()) if kind == "fixture" else kind
			# Geometry moves retain the same draw nodes and mipmapped textures.
			if kind == "fixture":
				var spec: Dictionary = world.fixtures[index].duplicate()
				spec.erase("rect")
				signature = JSON.stringify(spec)
			var node
			if nodes.has(key): node = nodes[key]
			else:
				node = Volume.new()
				add_child(node)
				nodes[key] = node
			if signatures.get(key,"") != signature:
				node.configure(world,kind,index,profile,asset_definitions)
				signatures[key] = signature
			else: node.tick_visual()
			var layer: String = "fixtures" if kind == "fixture" else "walls" if kind == "wall" else kind
			node.visible = canvas.layers.is_visible(layer)
			if kind == "wall": node.visible = node.visible and not world.wall_is_roofed(index) and node.profile.get("render_enabled",true)
			if kind == "fixture": node.visible = node.visible and not world.fixtures[index].get("hidden",false)
			if kind == "fixture" and canvas.beneath_roof(world.fixtures[index].rect.get_center()): node.visible = false
			if kind=="door" or kind=="fixture" and Doorways.Geometry.managed_fixture(world.fixtures[index]): node.visible = false
			if kind=="wall" and world.portal_cuts.any(func(c):return c.intersects(node.display_rect)): node.queue_redraw()
	for index in range(world.roofed_cells.size()):
		var key: String = "roof:%d" % index
		live[key] = true
		var signature: String = JSON.stringify(world.roofed_cells[index])
		if signatures.get(key,"") == signature: continue
		if nodes.has(key): nodes[key].hide(); nodes[key].queue_free()
		var node = Building.new()
		add_child(node)
		node.configure(self,self,index)
		node.status_label.hide()
		nodes[key] = node
		signatures[key] = signature
	for key in nodes.keys():
		if live.has(key): continue
		nodes[key].hide()
		nodes[key].queue_free()
		nodes.erase(key)
		signatures.erase(key)

func refresh_moving_fixture() -> bool:
	# Ordinary furniture has no role in doorway or roof geometry. Move its
	# retained painter without rebuilding every room and wall during a drag.
	var ref: Dictionary = canvas.drag_ref
	if ref.is_empty() or ref.group != "fixtures": return false
	var index := int(ref.index)
	if index >= world.fixtures.size(): return false
	var fixture: Dictionary = canvas.document.value(ref)
	var definition: Dictionary = asset_definitions.get(str(fixture.asset_id),{})
	if Doorways.Geometry.managed_fixture(fixture) or definition.has("grid_tile") or definition.has("grid_door") or str(definition.get("render_mode","")).begins_with("architecture_"): return false
	var key := "fixture:%d" % index
	if not nodes.has(key): return false
	var updated: Dictionary = fixture.duplicate(true)
	updated.rect = world.rect(fixture.rect)
	world.fixtures[index] = updated
	world.fixtures_revision += 1
	var node = nodes[key]
	node.tick_visual()
	node.visible = canvas.layers.is_visible("fixtures") and not fixture.get("hidden",false) and not canvas.beneath_roof(updated.rect.get_center())
	moving_fixture_refreshes += 1
	return true

func visual_hit(ref: Dictionary, point: Vector2) -> bool:
	for area in visual_hit_areas(ref):
		if area.has_point(point): return true
	return false

func visual_hit_areas(ref: Dictionary) -> Array[Rect2]:
	# Keep every branch typed. A plain array literal returned through the
	# dynamically held preview can lose its element type in Godot.
	var areas: Array[Rect2] = []
	if ref.group in ["access_doors","dorm_doors","door"]:
		var id := str(canvas.document.value(ref).id) if ref.group == "access_doors" else "dorm-%d" % int(ref.index) if ref.group == "dorm_doors" else "primary"
		var door = doorways.by_id(id)
		if doorways.visible and door != null: areas.append_array(door.rendered_areas())
		return areas
	if ref.group=="fixtures" and Doorways.Geometry.managed_fixture(world.fixtures[int(ref.index)]):
		var fixture: Dictionary = world.fixtures[int(ref.index)]
		var id := str(fixture.get("access_id","primary" if fixture.get("primary_gate",false) else "dorm-%d" % int(fixture.dorm_actor_id) if fixture.has("dorm_actor_id") else "fixture:"+str(fixture.get("id",fixture.rect))))
		var door = doorways.by_id(id)
		if doorways.visible and door != null: areas.append_array(door.rendered_areas())
		return areas
	var kind: String = "wall" if ref.group == "walls" else "fixture" if ref.group == "fixtures" else str(ref.group)
	var key: String = "%s:%d" % [kind,maxi(0,int(ref.index))]
	if not nodes.has(key) or not nodes[key].visible: return areas
	var node = nodes[key]
	var area: Rect2 = node.display_rect
	if kind == "wall" and node.profile.has("return_wall"):
		var start := float(node.profile.get("render_top_start",area.position.y))
		area = Rect2(area.position.x,start,area.size.x,maxf(0,area.end.y-start))
	if kind == "fixture" and asset_definitions.get(node.prop_id(),{}).has("assembly_patches"):
		var definition: Dictionary = asset_definitions[node.prop_id()]
		var dims: Array = definition.render_size
		var scale := area.size/Vector2(dims[0],dims[1])
		for patch in definition.assembly_patches:
			var values: Array = patch.destination
			var part := Rect2(area.position+Vector2(values[0],values[1])*scale,Vector2(values[2],values[3])*scale)
			areas.append(part.grow(2/canvas.zoom).intersection(area.grow(3/canvas.zoom)))
		return areas
	areas.append(area.grow(3/canvas.zoom))
	return areas
