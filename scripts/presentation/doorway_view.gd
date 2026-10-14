extends Node2D

const Geometry = preload("res://scripts/presentation/doorway_geometry.gd")
const TextureLoader = preload("res://scripts/presentation/world_texture.gd")
const Sliding = preload("res://scripts/presentation/sliding_door_geometry.gd")
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

class Threshold extends Node2D:
	var doorway
	func _draw() -> void:
		doorway._paint_threshold(self)

class PatchPart extends Node2D:
	var patch: Dictionary
	var area := Rect2()
	var turns := 0
	var state_closed := false
	func _draw() -> void:
		var art: Texture2D = patch.texture
		var source: Array = patch.source
		preload("res://scripts/presentation/texture_tiles.gd").paint_region(self,art,area,Rect2(Vector2(source[0],source[1])*art.get_size(),Vector2(source[2],source[3])*art.get_size()),Color.WHITE,false,turns)

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
	var custom_texture: Texture2D
	var closed_custom_texture: Texture2D
	var closed_patches: Array = []
	var open_patches: Array = []
	var leaf_texture: Texture2D
	var painted_fraction := -1.0
	var patch_parts: Array = []

	func configure(source_world, spec: Dictionary, rect: Rect2, art: Texture2D, floor_spec: Dictionary, ground: Texture2D) -> void:
		owner_world = source_world
		spec.merge(Geometry.art_spec(spec),false)
		gate = spec
		id = str(spec.get("id",""))
		style = Geometry.style_for(spec)
		primary = str(spec.get("kind","")) == "primary"
		visual_rect = rect
		texture = art
		if spec.has("door_art"):
			custom_texture = TextureLoader.load_asset(Geometry.art_definitions.get(str(spec.door_art),{}))
		if spec.has("door_art_closed"):
			closed_custom_texture = TextureLoader.load_asset(Geometry.art_definitions.get(str(spec.door_art_closed),{}))
		for patch in spec.get("door_closed_patches",[]):
			var patch_texture := TextureLoader.load_asset(Geometry.art_definitions[str(patch.asset)])
			closed_patches.append({"texture":patch_texture,"source":patch.source,"destination":patch.destination,"rotation_quarters":patch.get("rotation_quarters",0)})
		for patch in spec.get("door_open_patches",[]):
			var patch_texture := TextureLoader.load_asset(Geometry.art_definitions[str(patch.asset)])
			open_patches.append({"texture":patch_texture,"source":patch.source,"destination":patch.destination,"rotation_quarters":patch.get("rotation_quarters",0),"ground_level":patch.get("ground_level",false)})
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
		if gate.has("sliding_door") or gate.get("raised_door",false):
			# The floor must stay below actors even when raised door leaves
			# sort at their feet. Otherwise the empty aperture erases people.
			var threshold := Threshold.new()
			threshold.name = "ThresholdFloor"
			threshold.doorway = self
			threshold.z_as_relative = false
			threshold.z_index = 12
			add_child(threshold)
			z_as_relative = false
			z_index = preload("res://scripts/presentation/world_depth.gd").for_raised_door(gate,owner_world.bounds.end.y)
		if gate.get("piece_depth",false):
			# An inward-open upper leaf must not share the lower leaf's depth.
			# Each piece sorts at its own base; threshold floor stays at Z=12.
			for state in [false,true]:
				for patch in closed_patches if state else open_patches:
					var part := PatchPart.new()
					part.patch = patch
					part.state_closed = state
					var d: Array = patch.destination
					part.area = Rect2(d[0],d[1],d[2],d[3])
					var quarters := posmod(int(gate.get("rotation_quarters",0)),4)
					if quarters>=2: part.area.position = Vector2(length,depth)-part.area.end
					part.turns = int(patch.rotation_quarters)+(2 if quarters>=2 else 0)
					var base := 0.0
					for corner in [part.area.position,part.area.end,Vector2(part.area.end.x,part.area.position.y),Vector2(part.area.position.x,part.area.end.y)]:
						base = maxf(base,(position+corner.rotated(rotation)).y)
					part.z_as_relative = false
					part.z_index = preload("res://scripts/presentation/world_depth.gd").for_y(base+3.01,owner_world.bounds.end.y)-1
					if patch.get("ground_level",false): part.z_index = 12
					add_child(part)
					patch_parts.append(part)
		if gate.has("sliding_door"):
			if not gate.has("slide_fraction"): gate.slide_fraction = 1.0 if gate.get("closed",false) else 0.0
			leaf_texture = TextureLoader.load_asset(Geometry.art_definitions[gate.sliding_door.leaf])
			var values: Array = gate.sliding_door.track_rect
			var track_rect := Rect2(values[0],values[1],values[2],values[3])
			var track := Sprite2D.new()
			track.name = "SlidingTrack"
			track.texture = TextureLoader.load_asset(Geometry.art_definitions[gate.sliding_door.track])
			if posmod(int(gate.get("rotation_quarters",0)),4)>=2:
				track_rect.position = Vector2(length,depth)-track_rect.end
				track.rotation = PI
			track.position = track_rect.get_center()
			track.scale = track_rect.size/track.texture.get_size()
			track.z_as_relative = false
			track.z_index = 4096
			track.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
			add_child(track)
		refresh(true)

	func limit_roof_depth(maximum: int) -> void:
		# Keep both leaves and their frame beneath the owning room's roof,
		# while preserving their independent ordering when the roof fades out.
		z_index = mini(z_index,maximum)
		for part in patch_parts: part.z_index = mini(part.z_index,maximum)

	func refresh(force := false) -> void:
		var next: bool = not owner_world.door_open if primary else bool(gate.get("closed",false))
		if style == "free": next = false
		var fraction := float(gate.get("slide_fraction",-1))
		if not force and next == closed and fraction==painted_fraction: return
		closed = next
		painted_fraction = fraction
		for part in patch_parts: part.visible = part.state_closed == closed
		queue_redraw()

	func hardware_end() -> float:
		return length if vertical else length+end_cap

	func rendered_areas() -> Array[Rect2]:
		var result: Array[Rect2] = [visual_rect.grow(7)]
		var transform := Transform2D(rotation,position)
		for part in patch_parts:
			if not part.visible: continue
			var area := Rect2(transform*part.area.position,Vector2.ZERO)
			for point in [part.area.end,Vector2(part.area.end.x,part.area.position.y),Vector2(part.area.position.x,part.area.end.y)]: area = area.expand(transform*point)
			result.append(area)
		return result

	func _paint_threshold(canvas: CanvasItem) -> void:
		if floor_texture == null: return
		var corners := PackedVector2Array([Vector2.ZERO,Vector2(length,0),Vector2(length,depth),Vector2(0,depth)])
		var uvs := PackedVector2Array()
		for corner in corners:
			# The steel rotates for side doors; the floor keeps the corridor's
			# world registration and orientation, including its partial tile.
			uvs.append((position+corner.rotated(rotation)-floor_origin)/floor_tile)
		canvas.draw_polygon(corners,PackedColorArray([floor_tint,floor_tint,floor_tint,floor_tint]),uvs,floor_texture)

	func _draw() -> void:
		draw_builds += 1
		if not patch_parts.is_empty(): return
		if leaf_texture == null and not gate.get("raised_door",false): _paint_threshold(self)
		if leaf_texture != null:
			var leaves := Sliding.leaves(gate,float(gate.slide_fraction))
			var quarters := posmod(int(gate.get("rotation_quarters",0)),4)
			for index in leaves.size():
				var area: Rect2 = leaves[index]
				if quarters>=2: area.position = Vector2(length,depth)-area.end
				preload("res://scripts/presentation/texture_tiles.gd").paint_region(self,leaf_texture,area,Rect2(Vector2.ZERO,leaf_texture.get_size()),Color.WHITE,index==1,2 if quarters>=2 else 0)
			return
		if custom_texture != null:
			var state_texture: Texture2D = closed_custom_texture if closed and closed_custom_texture!=null else custom_texture
			var quarters := posmod(int(gate.get("rotation_quarters",0)),4)
			var patches: Array = closed_patches if closed else open_patches
			if not patches.is_empty():
				# Shared header/jambs keep the opening fixed across both leaf states.
				for patch in patches:
					var t: Texture2D = patch.texture
					var s: Array = patch.source
					var d: Array = patch.destination
					var target := Rect2(d[0],d[1],d[2],d[3])
					if quarters>=2: target.position = Vector2(length,depth)-target.end
					var source := Rect2(Vector2(s[0],s[1])*t.get_size(),Vector2(s[2],s[3])*t.get_size())
					preload("res://scripts/presentation/texture_tiles.gd").paint_region(self,t,target,source,Color.WHITE,false,int(patch.rotation_quarters)+(2 if quarters>=2 else 0))
				return
			if quarters>=2:
				preload("res://scripts/presentation/texture_tiles.gd").paint_region(self,state_texture,Rect2(0,0,length,depth),Rect2(Vector2.ZERO,state_texture.get_size()),Color.WHITE,false,2)
			else: draw_texture_rect(state_texture,Rect2(0,0,length,depth),false)
			return
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
		if style == "free" and gate.get("frame_only",false): return
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
	var primary_spec := Geometry.primary_spec(world)
	_add(primary_spec,Geometry.projected_rect(world,primary_spec),art)
	# Earlier maps painted ungated entrances with a permanently open gate
	# sprite. Replace those too; they are now clear passage ends, not bars.
	for fixture in world.fixtures:
		if Geometry.controlled_fixture(fixture):
			var access_id := str(fixture.get("access_id",""))
			if door_by_id.has(access_id): door_by_id["fixture:"+str(fixture.get("id",fixture.rect))] = door_by_id[access_id]
			continue
		if not Geometry.managed_fixture(fixture): continue
		var asset := str(fixture.asset_id)
		var free := asset.contains("open") or asset=="doorway_free_v48"
		var spec: Dictionary = Geometry.art_spec(fixture).duplicate(true)
		spec.merge({"id":"fixture:"+str(fixture.get("id",fixture.rect)),"kind":"open" if free else "locked" if asset.contains("locked") else "static","rect":fixture.rect,"closed":not free},true)
		if world.has_method("_changed") and (spec.has("sliding_door") or spec.get("manual_door",false)): spec = world.door_passage.by_id(spec.id)
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
	var file := str(spec.get("manifest",room_config.get("terrain_manifest","res://art/environment/factory_v45/manifest.json")))
	if not floor_definitions.has(file):
		if not FileAccess.file_exists(file): return null
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(file))
		var definitions := {}
		for asset in manifest.get("assets",[]): definitions[str(asset.id)] = asset
		floor_definitions[file] = definitions
	var asset: Dictionary = floor_definitions[file].get(str(spec.asset_id),{})
	return null if asset.is_empty() else TextureLoader.load_asset(asset)

func _occupants() -> Array:
	if not world.has_method("_changed"): return []
	var game = get_parent()
	var result: Array = game.actors.duplicate()
	result.append_array([game.guard,game.dog])
	if game.gate_watch: result.append_array(game.gate_watch.guards)
	if game.prison_alert: result.append_array(game.prison_alert.reinforcements)
	if game.trade: result.append_array(game.trade.actors.values())
	if game.resident_staff: result.append_array(game.resident_staff.actors.values())
	return result

func _overlap(actor, pieces: Array[Rect2]) -> float:
	var body := preload("res://scripts/core/actor_footprint.gd").body_at(actor.position)
	var area := 0.0
	for piece in pieces: area += body.intersection(piece).get_area()
	return area

func tick(force := false, delta := 0.0) -> void:
	var moved := false
	for door in doors:
		if not door.gate.has("sliding_door"): continue
		var current := float(door.gate.slide_fraction)
		var target := 1.0 if door.gate.get("closed",false) else 0.0
		var next := target if force else move_toward(current,target,maxf(0,delta)/float(door.gate.sliding_door.seconds))
		if next>current:
			var previous := Sliding.world_solids(door.gate,door.visual_rect,current)
			var proposed := Sliding.world_solids(door.gate,door.visual_rect,next)
			# Allow an invalid old spawn to separate, but never increase a body's
			# overlap. Back off a closing leaf if someone enters its swept area.
			if _occupants().any(func(actor):return is_instance_valid(actor) and actor.get("escaped")!=true and _overlap(actor,proposed)>_overlap(actor,previous)+0.01):
				next = current if force else move_toward(current,0.0,maxf(0,delta)/float(door.gate.sliding_door.seconds))
		if next==current: continue
		door.gate.slide_fraction = next
		moved = true
	if moved and world.has_method("_changed"): world._changed()
	# Guard movement and room transitions do not rebuild door art or meshes.
	var next: int = world.get("obstacle_revision") if world.get("obstacle_revision") != null else world.fixtures_revision
	if not force and revision == next: return
	revision = next
	for door in doors: door.refresh(force)

func by_id(id: String):
	return door_by_id.get(id)
