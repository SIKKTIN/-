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
	if pending: return
	pending = true
	call_deferred("refresh")

func refresh() -> void:
	pending = false
	if canvas.document.data.is_empty(): return
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

func visual_hit(ref: Dictionary, point: Vector2) -> bool:
	if ref.group=="fixtures" and Doorways.Geometry.managed_fixture(world.fixtures[int(ref.index)]):
		var fixture: Dictionary = world.fixtures[int(ref.index)]
		var id := str(fixture.get("access_id","primary" if fixture.get("primary_gate",false) else "dorm-%d" % int(fixture.dorm_actor_id) if fixture.has("dorm_actor_id") else "fixture:"+str(fixture.get("id",fixture.rect))))
		var door = doorways.by_id(id)
		return doorways.visible and door != null and door.visual_rect.grow(7).has_point(point)
	var kind: String = "wall" if ref.group == "walls" else "fixture" if ref.group == "fixtures" else str(ref.group)
	var key: String = "%s:%d" % [kind,maxi(0,int(ref.index))]
	if not nodes.has(key) or not nodes[key].visible: return false
	var node = nodes[key]
	var area: Rect2 = node.display_rect
	if kind == "wall" and node.profile.has("return_wall"):
		var start := float(node.profile.get("render_top_start",area.position.y))
		area = Rect2(area.position.x,start,area.size.x,maxf(0,area.end.y-start))
	if not area.grow(3/canvas.zoom).has_point(point): return false
	if kind == "fixture" and asset_definitions.get(node.prop_id(),{}).has("assembly_patches"):
		var definition: Dictionary = asset_definitions[node.prop_id()]
		var dims: Array = definition.render_size
		var scale := area.size/Vector2(dims[0],dims[1])
		for patch in definition.assembly_patches:
			var values: Array = patch.destination
			var part := Rect2(area.position+Vector2(values[0],values[1])*scale,Vector2(values[2],values[3])*scale)
			if part.grow(2/canvas.zoom).has_point(point): return true
		return false
	return true
