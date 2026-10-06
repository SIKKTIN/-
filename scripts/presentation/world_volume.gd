extends Node2D

const Tiles = preload("res://scripts/presentation/texture_tiles.gd")
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
var lintel_visual: Sprite2D

func painted_material() -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = load("res://art/architecture/v24/opaque_core.gdshader")
	return result

func configure(owner_world, type: String, index: int = 0, render_profile: Dictionary = {}, assets: Dictionary = {}) -> void:
	world = owner_world
	kind = type
	wall_index = index
	profile = render_profile.duplicate(true)
	if type == "wall" and owner_world.wall_surfaces.has(index):
		var surface: Dictionary = owner_world.wall_surfaces[index]
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
			material = painted_material()
		if surface.has("return_material"):
			profile.return_material = surface.return_material
			material = painted_material()
	definitions = assets
	if type == "fixture" and str(owner_world.fixtures[index].asset_id).ends_with("_v24"):
		material = painted_material()
	if type == "fixture" and owner_world.fixtures[index].has("lintel_asset"):
		lintel_visual = Sprite2D.new()
		lintel_visual.texture = world.art_textures.get(str(owner_world.fixtures[index].lintel_asset))
		lintel_visual.material = painted_material()
		add_child(lintel_visual)
	_wall_geometry_valid = false
	# Minified bars and furniture need prefiltered texture levels. Fractional
	# camera motion stays smooth; snapping the camera would introduce stepping.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
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
	if kind == "wall" and _wall_geometry_valid and next_footprint == footprint and _wall_bounds == world.bounds:
		return
	footprint = next_footprint
	_wall_geometry_valid = kind == "wall"
	_wall_bounds = world.bounds
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

func paint_facade(area: Rect2) -> void:
	var facade: Dictionary = profile.painted_facade
	if facade.get("layout","wing") == "wing":
		draw_texture_rect(world.art_textures[str(facade.asset)],area,false)
		return
	# Extend the original painted middle at its natural width, crop the last
	# panel and finish with a stone corner. All geometry follows the map wall.
	var jamb := Rect2(area.position,Vector2(32,area.size.y))
	var corner := Rect2(area.end.x-28,area.position.y,28,area.size.y)
	var middle := Rect2(jamb.end.x,area.position.y,maxf(0,corner.position.x-jamb.end.x),area.size.y)
	draw_texture_rect(world.art_textures[str(facade.jamb)],jamb,false)
	Tiles.paint(self,world.art_textures[str(facade.middle)],middle,Vector2(144,area.size.y),middle)
	draw_texture_rect(world.art_textures[str(facade.corner)],corner,false)

func _draw() -> void:
	if not world:
		return
	var r := footprint
	if kind == "wall":
		var height := elevation
		if profile.has("painted_facade"):
			paint_facade(Rect2(r.position-Vector2(0,height),r.size+Vector2(0,height)))
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
			draw_texture_rect(world.art_textures[prop_id()],display_rect,false)
