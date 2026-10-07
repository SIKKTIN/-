extends Node2D

const Tiles = preload("res://scripts/presentation/texture_tiles.gd")
const Components = preload("res://scripts/presentation/wall_components.gd")
var world
var kind: String
var wall_index: int = 0
var footprint := Rect2()
var display_rect := Rect2()
var profile: Dictionary = {}
var definitions: Dictionary = {}
var elevation: float = 20.0
var _wall_geometry_valid := false
var _wall_bounds := Rect2()
var _visual_asset := ""
var _fixture_revision := -1
var lintel_visual: Sprite2D

func painted_material(shader_path := "res://art/architecture/v24/opaque_core.gdshader") -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = load(shader_path)
	return result

func configure(owner_world, type: String, index: int = 0, render_profile: Dictionary = {}, assets: Dictionary = {}) -> void:
	world = owner_world
	kind = type
	wall_index = index
	profile = render_profile.duplicate(true)
	if type == "wall" and owner_world.wall_surfaces.has(index):
		var surface: Dictionary = owner_world.wall_surfaces[index]
		var alpha_shader := str(surface.get("alpha_shader","res://art/architecture/v24/opaque_core.gdshader"))
		profile.wall_elevation = float(surface.get("height",100))
		profile.block_elevation = profile.wall_elevation
		profile.block_top_tiled = true
		profile.material_slots = profile.get("material_slots",{}).duplicate(true)
		profile.material_slots.wall_top = surface.get("top","cafeteria_coping_v23")
		profile.material_slots.wall_front = surface.get("front","cafeteria_wall_front_v23")
		profile.render_enabled = surface.get("render_enabled",true)
		if surface.has("render_top_start"): profile.render_top_start = surface.render_top_start
		if surface.has("painted_facade"):
			profile.painted_facade = surface.painted_facade
			material = painted_material(alpha_shader)
		if surface.has("return_wall"):
			profile.return_wall = surface.return_wall
			material = painted_material(alpha_shader)
		if surface.has("return_material"):
			profile.return_material = surface.return_material
			material = painted_material()
	definitions = assets
	if type == "fixture":
		var fixture_id := str(owner_world.fixtures[index].asset_id)
		var definition: Dictionary = definitions.get(fixture_id,{})
		if definition.has("alpha_core_shader") or fixture_id.ends_with("_v24"):
			material = painted_material(str(definition.get("alpha_core_shader","res://art/architecture/v24/opaque_core.gdshader")))
	if type == "fixture" and owner_world.fixtures[index].has("lintel_asset"):
		lintel_visual = Sprite2D.new()
		var lintel_id := str(owner_world.fixtures[index].lintel_asset)
		if not definitions.get(lintel_id,{}).has("assembly_patches"):
			lintel_visual.texture = world.art_textures.get(lintel_id)
		lintel_visual.material = painted_material(str(owner_world.fixtures[index].get("alpha_shader","res://art/architecture/v24/opaque_core.gdshader")))
		add_child(lintel_visual)
	_wall_geometry_valid = false
	# Minified bars and furniture need prefiltered texture levels. Fractional
	# camera motion stays smooth; snapping the camera would introduce stepping.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if (profile.has("painted_facade") and str(profile.painted_facade.get("asset","")).ends_with("_v26")) or (profile.has("return_wall") and str(profile.return_wall.top).ends_with("_v26")) or (kind == "fixture" and (str(owner_world.fixtures[index].asset_id).ends_with("_v26") or str(owner_world.fixtures[index].get("lintel_asset","")).ends_with("_v26"))):
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	tick_visual()

func asset_id(slot: String, fallback: String) -> String:
	return str(profile.get("material_slots",{}).get(slot,fallback))

func prop_id() -> String:
	if kind == "fixture":
		var fixture: Dictionary = world.fixtures[wall_index]
		if fixture.has("access_id"):
			var gate: Dictionary = world.access_by_id(str(fixture.access_id))
			return str(fixture.get("closed_asset",fixture.asset_id) if gate.get("closed",true) else fixture.get("open_asset",fixture.asset_id))
		return str(world.fixtures[wall_index].asset_id)
	return asset_id("crate","heavy_crate_v02") if kind == "crate" else asset_id("door_open","locked_door_open_v02") if world.door_open else asset_id("door_closed","locked_door_closed_v02")

func tick_visual() -> void:
	var next_footprint: Rect2 = world.walls[wall_index] if kind == "wall" else world.fixtures[wall_index].rect if kind == "fixture" else world.door if kind == "door" else world.crate
	# Godot retains canvas commands across camera transforms and light updates.
	# Static wall polygons only need rebuilding on configure/geometry changes.
	var next_asset := "" if kind == "wall" else prop_id()
	if _wall_geometry_valid and next_footprint == footprint and _wall_bounds == world.bounds and _visual_asset == next_asset and (kind == "wall" or _fixture_revision == world.fixtures_revision):
		return
	footprint = next_footprint
	_wall_geometry_valid = true
	_wall_bounds = world.bounds
	_visual_asset = next_asset
	_fixture_revision = world.fixtures_revision
	elevation = float(profile.get("block_elevation",24)) if kind == "wall" and footprint.size.x > 60 else float(profile.get("wall_elevation",18)) if kind == "wall" else 20.0
	display_rect = Rect2(footprint.position-Vector2(0,elevation),footprint.size+Vector2(0,elevation))
	visible = not world.wall_is_roofed(wall_index) if kind == "wall" else not world.fixtures[wall_index].get("hidden",false) if kind == "fixture" else true
	if kind == "wall": visible = visible and profile.get("render_enabled",true)
	if kind != "wall" and world.art_textures.has(prop_id()) and definitions.get(prop_id(),{}).has("ground_rect"):
		var definition: Dictionary = definitions[prop_id()]
		var ground: Array = definition.ground_rect
		var scale := footprint.size/Vector2(ground[2],ground[3])
		display_rect = Rect2(footprint.position-Vector2(ground[0],ground[1])*scale,world.art_textures[prop_id()].get_size()*scale)
		elevation = float(definition.get("elevation_world",20))
	if kind == "wall" and profile.get("painted_facade",{}).get("layout","") == "tiled":
		var definition: Dictionary = definitions.get(str(profile.painted_facade.asset),{})
		if definition.has("render_size"):
			var visual_height := float(definition.render_size[1])
			display_rect = Rect2(footprint.position.x,footprint.end.y-visual_height,footprint.size.x,visual_height)
	if kind == "fixture":
		var fixture: Dictionary = world.fixtures[wall_index]
		var definition: Dictionary = definitions.get(prop_id(),{})
		if definition.get("render_mode","") == "embedded_door":
			var dims: Array = fixture.get("render_size",definition.get("render_size",[footprint.size.x,110]))
			elevation = float(dims[1])
			display_rect = Rect2(Vector2(footprint.position.x,footprint.end.y-elevation),Vector2(footprint.size.x,elevation))
		elif fixture.has("render_size"):
			var dims: Array = fixture.render_size
			display_rect = Rect2(Vector2(footprint.get_center().x-dims[0]/2.0,footprint.end.y-dims[1]),Vector2(dims[0],dims[1]))
	z_index = int(world.fixtures[wall_index].get("draw_depth",footprint.end.y)) if kind == "fixture" else int(footprint.end.y)
	if lintel_visual != null and lintel_visual.texture != null:
		var height := float(world.fixtures[wall_index].get("lintel_height",31.5))
		lintel_visual.position = Vector2(display_rect.get_center().x,display_rect.position.y-height/2)
		lintel_visual.scale = Vector2(display_rect.size.x,height)/lintel_visual.texture.get_size()
	queue_redraw()

func paint_registered(texture: Texture2D, area: Rect2, clip: Rect2) -> void:
	var visible_area := area.intersection(clip)
	if not visible_area.has_area(): return
	var ratio := texture.get_size()/area.size
	draw_texture_rect_region(texture,visible_area,Rect2((visible_area.position-area.position)*ratio,visible_area.size*ratio))

func subtract_piece(pieces: Array[Rect2], cut: Rect2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for piece in pieces:
		var overlap := piece.intersection(cut)
		if not overlap.has_area():
			result.append(piece)
			continue
		if overlap.position.y > piece.position.y: result.append(Rect2(piece.position,Vector2(piece.size.x,overlap.position.y-piece.position.y)))
		if overlap.end.y < piece.end.y: result.append(Rect2(piece.position.x,overlap.end.y,piece.size.x,piece.end.y-overlap.end.y))
		if overlap.position.x > piece.position.x: result.append(Rect2(piece.position.x,overlap.position.y,overlap.position.x-piece.position.x,overlap.size.y))
		if overlap.end.x < piece.end.x: result.append(Rect2(overlap.end.x,overlap.position.y,piece.end.x-overlap.end.x,overlap.size.y))
	return result

func paint_facade(area: Rect2) -> void:
	var facade: Dictionary = profile.painted_facade
	var left_trim := float(facade.get("trim_left",0))
	var right_trim := float(facade.get("trim_right",0))
	var clip := Rect2(area.position+Vector2(left_trim,0),Vector2(maxf(0,area.size.x-left_trim-right_trim),area.size.y))
	var pieces: Array[Rect2] = [clip]
	for replacement in facade.get("replace_ranges",[]):
		# Optional vertical offset removes the front only, retaining the cap.
		var top := clampf(float(replacement[2]) if replacement.size() > 2 else 0.0,0,area.size.y)
		pieces = subtract_piece(pieces,Rect2(area.position+Vector2(replacement[0],top),Vector2(replacement[1],area.size.y-top)))
	for cutout in facade.get("cap_cutouts",[]):
		pieces = subtract_piece(pieces,Rect2(area.position+Vector2(cutout[0],cutout[1]),Vector2(cutout[2],cutout[3])))
	for piece in pieces:
		if facade.get("layout","wing") == "tiled":
			var id := str(facade.asset)
			var dims: Array = definitions[id].render_size
			var phase: Array = facade.get("phase_shift",[0,0])
			paint_component_run(id,area,Vector2(dims[0],area.size.y),piece,false,Vector2(phase[0],phase[1]))
		elif facade.get("layout","wing") == "wing":
			paint_registered(world.art_textures[str(facade.asset)],area,piece)
		else:
			# Preserve source registration while replacing only a corner's footprint.
			var jamb := Rect2(area.position,Vector2(32,area.size.y))
			var corner_width := float(facade.get("end_post_width",28))
			var corner := Rect2(area.end.x-corner_width,area.position.y,corner_width,area.size.y)
			var middle := Rect2(jamb.end.x,area.position.y,maxf(0,corner.position.x-jamb.end.x),area.size.y)
			paint_registered(world.art_textures[str(facade.jamb)],jamb,piece)
			Tiles.paint(self,world.art_textures[str(facade.middle)],middle,Vector2(144,area.size.y),piece)
			if not facade.get("omit_end_post",false):
				paint_registered(world.art_textures[str(facade.corner)],corner,piece)
	for patch in facade.get("junctions",[]):
		var offset: Array = patch.get("offset",[0,0])
		var size: Array = patch.size
		var origin := Vector2(area.end.x if patch.get("anchor","") == "right" else area.position.x,area.position.y)
		var rect := Rect2(origin+Vector2(offset[0],offset[1]),Vector2(size[0],size[1]))
		var phase: Array = patch.get("phase_shift",[0,0])
		var patch_clip := Rect2()
		if patch.has("clip"):
			var values: Array = patch.clip
			patch_clip = Rect2(area.position+Vector2(values[0],values[1]),Vector2(values[2],values[3]))
		paint_junction(str(patch.asset),rect,patch.get("mirror_x",false),patch_clip,Vector2(phase[0],phase[1]),patch.get("top_only",false),patch.get("reuse_cap",false))
	for post in facade.get("posts",[]):
		var offset: Array = post.offset
		var size: Array = post.size
		var phase: Array = post.get("phase_shift",[0,0])
		paint_junction(str(post.asset),Rect2(area.position+Vector2(offset[0],offset[1]),Vector2(size[0],size[1])),post.get("mirror_x",false),Rect2(),Vector2(phase[0],phase[1]))

func paint_component_run(id: String, area: Rect2, tile: Vector2, clip: Rect2, mirror_x: bool, phase_shift := Vector2.ZERO) -> void:
	var visible_area := area.intersection(clip)
	if not visible_area.has_area() or tile.x <= 0 or tile.y <= 0: return
	var cursor := area.position
	while cursor.x < area.end.x:
		cursor.y = area.position.y
		while cursor.y < area.end.y:
			paint_junction(id,Rect2(cursor,tile),mirror_x,visible_area,phase_shift)
			cursor.y += tile.y
		cursor.x += tile.x

func paint_junction(id: String, rect: Rect2, mirror_x: bool, clip := Rect2(), phase_shift := Vector2.ZERO, top_only := false, reuse_cap := false) -> void:
	var definition: Dictionary = definitions[id]
	if reuse_cap:
		definition = definition.duplicate()
		definition.assembly_patches = definition.assembly_patches.filter(func(p): return str(p.get("role","")) == "longitudinal_stem")
	if top_only:
		# The extended facade already owns its original repeating front.
		# A portal wing fragment here would create an unrelated stone seam.
		definition = definition.duplicate()
		definition.assembly_patches = definition.assembly_patches.filter(func(p): return not str(p.get("role", "")).begins_with("unaltered original wing fragment"))
	Components.paint(self,world.art_textures[id],definition,rect,mirror_x,clip,phase_shift)

func _draw() -> void:
	if not world:
		return
	var r := footprint
	if kind == "wall":
		var height := elevation
		if profile.has("painted_facade"):
			var area := Rect2(r.position-Vector2(0,height),r.size+Vector2(0,height))
			if profile.painted_facade.get("layout","") == "tiled":
				var dims: Array = definitions[str(profile.painted_facade.asset)].render_size
				area = Rect2(Vector2(r.position.x,r.end.y-float(dims[1])),Vector2(r.size.x,dims[1]))
			paint_facade(area)
			return
		if profile.has("return_wall"):
			# A longitudinal wall shows its narrow horizontal top and east side.
			# Only its south endpoint gets a front-facing 90-high stone face.
			var wall: Dictionary = profile.return_wall
			var top_area := Rect2(r.position-Vector2(0,height),r.size)
			if wall.has("tile_origin_y"):
				top_area.position.y = float(wall.tile_origin_y)
				top_area.size.y = maxf(0,r.end.y-height-top_area.position.y)
			var start := maxf(world.bounds.position.y,float(profile.get("render_top_start",top_area.position.y)))
			var clip := Rect2(world.bounds.position.x,start,world.bounds.size.x,maxf(0,world.bounds.end.y-start))
			var dims: Array = wall.get("tile_size",[24,128])
			if definitions[str(wall.top)].has("assembly_patches"):
				paint_component_run(str(wall.top),top_area,Vector2(r.size.x,dims[1]),clip,wall.get("mirror_x",false))
			else:
				Tiles.paint(self,world.art_textures[str(wall.top)],top_area,Vector2(r.size.x,dims[1]),clip,Color.WHITE,wall.get("mirror_x",false))
			var south_face := Rect2(r.position.x,r.end.y-height,r.size.x,height).intersection(world.bounds)
			paint_junction(str(wall.end),south_face,wall.get("mirror_x",false))
			return
		if profile.has("return_material"):
			var side_body := Rect2(r.position-Vector2(0,height),r.size+Vector2(0,height))
			var start := maxf(world.bounds.position.y,float(profile.get("render_top_start",side_body.position.y)))
			var side_clip := Rect2(world.bounds.position.x,start,world.bounds.size.x,maxf(0,world.bounds.end.y-start))
			Tiles.paint(self,world.art_textures[str(profile.return_material)],side_body,Vector2(r.size.x,121.5),side_clip)
			return
		var top_tint: Array = profile.get("top_modulate",[1,1,1,1])
		var top_color := Color(top_tint[0],top_tint[1],top_tint[2],top_tint[3])
		var top := Rect2(r.position-Vector2(0,height),r.size)
		var clip_bounds: Rect2 = world.bounds
		if profile.has("render_top_start"):
			var start := maxf(clip_bounds.position.y,float(profile.render_top_start))
			clip_bounds = Rect2(clip_bounds.position.x,start,clip_bounds.size.x,maxf(0,clip_bounds.end.y-start))
		var clipped := top.intersection(clip_bounds)
		if r.size.x > 60 and not profile.get("block_top_tiled",false):
			var texture: Texture2D = world.art_textures[asset_id("block_top","block_top_v02")]
			var scale := texture.get_size()/top.size
			draw_texture_rect_region(texture,clipped,Rect2((clipped.position-top.position)*scale,clipped.size*scale),top_color)
		else:
			var id := asset_id("wall_top","low_wall_top_v02")
			var size: Array = definitions.get(id,{}).get("world_size",[64,64])
			Tiles.paint(self,world.art_textures[id],top,Vector2(size[0],size[1]),clip_bounds,top_color)
			var side_width: float = profile.get("wall_side_width",0.0)
			if side_width > 0:
				var side := Rect2(Vector2(top.end.x-side_width,top.position.y),Vector2(side_width,top.size.y)).intersection(clip_bounds)
				var shade: float = profile.get("wall_side_shade",0.68)
				if profile.get("wall_side_gradient",false):
					Tiles.paint_side_gradient(self,world.art_textures[id],top,Vector2(size[0],size[1]),side,top_color,Color(shade,shade,shade,1))
				else:
					Tiles.paint(self,world.art_textures[id],top,Vector2(size[0],size[1]),side,Color(shade,shade,shade,1))
					for step in range(2):
						var transition := Rect2(side.position+Vector2(step*0.55,0),Vector2(0.55,side.size.y))
						var value := lerpf(1.0,shade,float(step+1)/3)
						Tiles.paint(self,world.art_textures[id],top,Vector2(size[0],size[1]),transition.intersection(clip_bounds),Color(value,value,value,1))
		var front := Rect2(r.position+Vector2(0,r.size.y-height),Vector2(r.size.x,height))
		var front_id := asset_id("wall_front","low_wall_front_v02")
		var front_size: Array = definitions.get(front_id,{}).get("world_size",[64,18])
		var tint: Array = definitions.get(front_id,{}).get("front_modulate",profile.get("front_modulate",[1,1,1,1]))
		Tiles.paint(self,world.art_textures[front_id],front,Vector2(front_size[0],height),world.bounds,Color(tint[0],tint[1],tint[2],tint[3]))
		var width: float = profile.get("outline_width",2.0)
		if width > 0:
			var color := Color(profile.get("outline_color","303b46"))
			var aa: bool = profile.get("wall_outline_aa",false)
			draw_rect(clipped,color,false,width,aa)
			draw_line(front.position+Vector2(0,height),front.end,color,width,aa)
			draw_line(clipped.position+Vector2(clipped.size.x,0),r.end,color,width,aa)
			draw_line(clipped.position,Vector2(r.position.x,r.end.y),color,width,aa)
	else:
		if world.art_textures.has(prop_id()):
			if definitions.get(prop_id(),{}).has("assembly_patches"):
				paint_junction(prop_id(),display_rect,false)
			else:
				draw_texture_rect(world.art_textures[prop_id()],display_rect,false)
		if kind == "fixture" and world.fixtures[wall_index].has("lintel_asset"):
			var fixture: Dictionary = world.fixtures[wall_index]
			var id := str(fixture.lintel_asset)
			if definitions.get(id,{}).has("assembly_patches"):
				var height := float(fixture.get("lintel_height",31.5))
				var phase: Array = fixture.get("phase_shift",[0,0])
				paint_junction(id,Rect2(display_rect.position-Vector2(0,height),Vector2(display_rect.size.x,height)),false,Rect2(),Vector2(phase[0],phase[1]))
