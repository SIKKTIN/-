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

func configure(owner_world, type: String, index: int = 0, render_profile: Dictionary = {}, assets: Dictionary = {}) -> void:
	world = owner_world
	kind = type
	wall_index = index
	profile = render_profile
	definitions = assets
	tick_visual()

func asset_id(slot: String, fallback: String) -> String:
	return str(profile.get("material_slots",{}).get(slot,fallback))

func prop_id() -> String:
	return asset_id("crate","heavy_crate_v02") if kind == "crate" else asset_id("door_open","locked_door_open_v02") if world.door_open else asset_id("door_closed","locked_door_closed_v02")

func tick_visual() -> void:
	footprint = world.walls[wall_index] if kind == "wall" else world.door if kind == "door" else world.crate
	elevation = float(profile.get("block_elevation",24)) if kind == "wall" and footprint.size.x > 60 else float(profile.get("wall_elevation",18)) if kind == "wall" else 20.0
	display_rect = Rect2(footprint.position-Vector2(0,elevation),footprint.size+Vector2(0,elevation))
	if kind != "wall" and definitions.get(prop_id(),{}).has("ground_rect"):
		var definition: Dictionary = definitions[prop_id()]
		var ground: Array = definition.ground_rect
		var scale := footprint.size/Vector2(ground[2],ground[3])
		display_rect = Rect2(footprint.position-Vector2(ground[0],ground[1])*scale,world.art_textures[prop_id()].get_size()*scale)
		elevation = float(definition.get("elevation_world",20))
	z_index = int(footprint.end.y)
	queue_redraw()

func _draw() -> void:
	if not world:
		return
	var r := footprint
	if kind == "wall":
		var height := elevation
		var top_tint: Array = profile.get("top_modulate",[1,1,1,1])
		var top_color := Color(top_tint[0],top_tint[1],top_tint[2],top_tint[3])
		var top := Rect2(r.position-Vector2(0,height),r.size)
		var clipped := top.intersection(world.bounds)
		if r.size.x > 60 and not profile.get("block_top_tiled",false):
			var texture: Texture2D = world.art_textures[asset_id("block_top","block_top_v02")]
			var scale := texture.get_size()/top.size
			draw_texture_rect_region(texture,clipped,Rect2((clipped.position-top.position)*scale,clipped.size*scale),top_color)
		else:
			var id := asset_id("wall_top","low_wall_top_v02")
			var size: Array = definitions.get(id,{}).get("world_size",[64,64])
			Tiles.paint(self,world.art_textures[id],top,Vector2(size[0],size[1]),world.bounds,top_color)
			var side_width: float = profile.get("wall_side_width",0.0)
			if side_width > 0:
				var side := Rect2(Vector2(top.end.x-side_width,top.position.y),Vector2(side_width,top.size.y)).intersection(world.bounds)
				var shade: float = profile.get("wall_side_shade",0.68)
				Tiles.paint(self,world.art_textures[id],top,Vector2(size[0],size[1]),side,Color(shade,shade,shade,1))
				for step in range(2):
					var transition := Rect2(side.position+Vector2(step*0.55,0),Vector2(0.55,side.size.y))
					var value := lerpf(1.0,shade,float(step+1)/3)
					Tiles.paint(self,world.art_textures[id],top,Vector2(size[0],size[1]),transition,Color(value,value,value,1))
		var front := Rect2(r.position+Vector2(0,r.size.y-height),Vector2(r.size.x,height))
		var front_id := asset_id("wall_front","low_wall_front_v02")
		var front_size: Array = definitions.get(front_id,{}).get("world_size",[64,18])
		var tint: Array = definitions.get(front_id,{}).get("front_modulate",profile.get("front_modulate",[1,1,1,1]))
		Tiles.paint(self,world.art_textures[front_id],front,Vector2(front_size[0],height),world.bounds,Color(tint[0],tint[1],tint[2],tint[3]))
		var width: float = profile.get("outline_width",2.0)
		if width > 0:
			var color := Color(profile.get("outline_color","303b46"))
			draw_rect(clipped,color,false,width)
			draw_line(front.position+Vector2(0,height),front.end,color,width)
			draw_line(clipped.position+Vector2(clipped.size.x,0),r.end,color,width)
			draw_line(clipped.position,r.position+Vector2(0,r.size.y),color,width)
	else:
		draw_texture_rect(world.art_textures[prop_id()],display_rect,false)
