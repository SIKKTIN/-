extends Node2D

const SoftShadow = preload("res://scripts/presentation/soft_shadow.gd")

var game
var presentation
var kind: String
var fixtures_revision: int = -1

func configure(owner_game, owner_presentation, type: String) -> void:
	game = owner_game
	presentation = owner_presentation
	kind = type
	z_index = 10 if kind == "ground" else 11 if kind == "fixture_shadows" else 2000
	if kind == "information":
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded

func _draw() -> void:
	if not game:
		return
	var world = game.world
	if kind == "fixture_shadows":
		# Static furnishings retain cached CanvasItem draw commands between frames.
		for fixture in world.fixtures:
			var definition: Dictionary = presentation.asset_definitions.get(str(fixture.asset_id),{})
			if not definition.get("shadow_baked",false):
				SoftShadow.contact_rect(self,fixture.rect,float(definition.get("elevation_world",20)),world.bounds,presentation.profile)
		return
	if kind == "ground":
		for zone in game.room_config.get("zones",[]):
			var values: Array = zone.rect
			var area := Rect2(values[0],values[1],values[2],values[3]).intersection(world.bounds)
			var tint := Color(zone.color)
			tint.a = 0.13
			draw_rect(area,tint)
		for r in world.walls+[world.crate,world.door]:
			if r == world.door and world.door_open:
				continue
			if presentation.profile.get("soft_shadows",false):
				var volume = presentation.volumes.filter(func(v): return v.footprint == r).front()
				var id: String = volume.prop_id() if volume.kind != "wall" else volume.asset_id("wall_top","low_wall_top_v02")
				if not presentation.asset_definitions.get(id,{}).get("shadow_baked",false):
					SoftShadow.contact_rect(self,r,volume.elevation,world.bounds,presentation.profile)
			else:
				draw_rect(Rect2(r.position+Vector2(5,4),r.size).intersection(world.bounds),Color(0,0,0,0.12))
		for visual in presentation.visuals:
			if not visual.actor.escaped:
				if presentation.profile.get("soft_shadows",false):
					if not visual.definition.get("shadow_baked",false):
						SoftShadow.contact_actor(self,visual.actor.position,presentation.profile)
				else:
					draw_ellipse(visual.actor.position+Vector2(0,2),15,4,Color(0,0,0,0.12))
		draw_rect(world.exit_strip_rect(),Color("328b82"))
		if game.dog:
			SoftShadow.contact_actor(self,game.dog.position,presentation.profile)
		draw_texture_rect(world.art_textures.exit_v01,world.exit_icon_rect(),false)
	else:
		if presentation.dog_visual:
			draw_set_transform(game.dog.position)
			presentation.dog_visual.paint_information(self,presentation.font)
			draw_set_transform(Vector2.ZERO)
		var view: Rect2 = Rect2(game.map_camera.position+Vector2(74,114),Vector2(922,560)) if game.map_camera else world.bounds
		var zone_label_color := Color("e1dfc9") if presentation.lighting and presentation.lighting.period == "night" else Color("405347")
		for zone in game.room_config.get("zones",[]):
			var values: Array = zone.rect
			var visible_area := Rect2(values[0],values[1],values[2],values[3]).intersection(view)
			if visible_area.size.x >= 150 and visible_area.size.y >= 60:
				draw_string(presentation.font,visible_area.position+Vector2(16,30),str(zone.name),HORIZONTAL_ALIGNMENT_LEFT,-1,20,zone_label_color)
		var zone: Rect2 = world.guard_zone
		var boundary := Color(0.20,0.55,0.51,0.42)
		for y in range(int(zone.position.y+12),int(zone.end.y),24):
			draw_line(Vector2(zone.position.x,y),Vector2(zone.position.x,y+10),boundary,1.5,true)
		var label_color := Color("d8e8dc") if presentation.lighting.period == "night" else Color("536052")
		draw_string(presentation.font,Vector2(world.bounds.position.x+12,world.bounds.end.y-12),"安全房间",HORIZONTAL_ALIGNMENT_LEFT,-1,14,label_color)
		var edge_color := Color("eb977b") if game.guard.state == "chasing" else Color("e1c787")
		edge_color.a = 0.48
		draw_set_transform(game.guard.position)
		draw_polyline(game.guard.view_polygon(),edge_color,1.2,true)
		draw_set_transform(Vector2.ZERO)
		var point: Vector2 = world.door.position+Vector2(-27,world.door.size.y*0.5)
		if world.lock_progress > 0 and not world.door_open:
			var progress_offset := Vector2(-28,-float(presentation.visuals[0].definition.world_height)-48)
			draw_rect(Rect2(point+progress_offset,Vector2(56,6)),Color("536052"))
			draw_rect(Rect2(point+progress_offset,Vector2(56*world.lock_progress,6)),Color("9a8fb9"))
		for visual in presentation.visuals:
			if not visual.actor.escaped:
				draw_set_transform(visual.actor.position)
				visual.paint_information(self)
				draw_set_transform(Vector2.ZERO)
		if game.items_view:
			game.items_view.paint_information(self)
