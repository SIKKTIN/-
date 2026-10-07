extends Node2D

const SoftShadow = preload("res://scripts/presentation/soft_shadow.gd")

var game
var presentation
var kind: String
var fixtures_revision: int = -1
var ground_key: Array = []

func configure(owner_game, owner_presentation, type: String) -> void:
	game = owner_game
	presentation = owner_presentation
	kind = type
	z_index = 10 if kind in ["ground_static","ground"] else 11 if kind == "fixture_shadows" else 2000
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
			if fixture.get("hidden",false):
				continue
			var definition: Dictionary = presentation.asset_definitions.get(str(fixture.asset_id),{})
			if definition.has("assembly_patches"):
				# A compound corner's bounding rectangle includes empty floor.
				# Do not fill that cutout with a rectangular contact shadow.
				var filled := 0.0
				for patch in definition.assembly_patches: filled += float(patch.destination[2])*float(patch.destination[3])
				var dims: Array = definition.render_size
				if filled < float(dims[0])*float(dims[1])*0.99: continue
			if not definition.get("shadow_baked",false) and not str(definition.get("render_mode","")).begins_with("wall"):
				SoftShadow.contact_rect(self,fixture.rect,float(definition.get("elevation_world",20)),world.bounds,presentation.profile)
		return
	if kind == "ground_static":
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
		return
	if kind == "ground":
		for gate in world.dorm_doors:
			var r: Rect2 = gate.rect
			if gate.closed:
				var rail := Rect2(r.position-Vector2(0,34),Vector2(r.size.x,38))
				draw_rect(rail,Color(0.18,0.23,0.25,0.35))
				for x in range(int(r.position.x+5),int(r.end.x),14):
					draw_line(Vector2(x,r.position.y-34),Vector2(x,r.end.y),Color("475452"),4,true)
				draw_line(rail.position,Vector2(rail.end.x,rail.position.y),Color("738176"),4,true)
				draw_line(Vector2(r.position.x,r.end.y),r.end,Color("738176"),4,true)
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
		if presentation.dog_visual and not world.is_under_roof(game.dog.position):
			draw_set_transform(game.dog.position)
			presentation.dog_visual.paint_information(self,presentation.font)
			draw_set_transform(Vector2.ZERO)
		var view: Rect2 = game.map_camera.world_view_rect() if game.map_camera else world.bounds
		var zone_label_color := Color("e1dfc9") if presentation.lighting and presentation.lighting.period == "night" else Color("405347")
		for zone in game.room_config.get("zones",[]):
			if zone.get("hide_label",false): continue
			var values: Array = zone.rect
			var visible_area := Rect2(values[0],values[1],values[2],values[3]).intersection(view)
			if visible_area.size.x >= 150 and visible_area.size.y >= 60:
				draw_string(presentation.font,visible_area.position+Vector2(16,30),str(zone.name),HORIZONTAL_ALIGNMENT_LEFT,-1,20,zone_label_color)
		var zone: Rect2 = game.guard.search_zone()
		var boundary := Color(0.20,0.55,0.51,0.42)
		for y in range(int(zone.position.y+12),int(zone.end.y),24):
			draw_line(Vector2(zone.position.x,y),Vector2(zone.position.x,y+10),boundary,1.5,true)
		var label_color := Color("d8e8dc") if presentation.lighting.period == "night" else Color("536052")
		draw_string(presentation.font,Vector2(world.bounds.position.x+12,world.bounds.end.y-12),"午夜锁寝 · 看守查房" if game.schedule and game.schedule.is_sleep_time() else "寝区自由 · 室外警戒" if game.schedule and game.schedule.is_curfew() else "寝室区",HORIZONTAL_ALIGNMENT_LEFT,-1,14,label_color)
		if game.schedule and game.schedule.is_curfew():
			for index in range(game.actors.size()):
				var dorm: Rect2 = game.schedule.dormitory(index)
				draw_rect(dorm,Color(0.3,0.7,0.6,0.1))
				draw_rect(dorm,Color("328b82"),false,1.5,true)
		var officers: Array = game.guard.warning_officers()
		for officer in officers:
			if world.is_under_roof(officer.position) or not officer.search_zone().has_point(officer.position): continue
			var radius: float = officer.view_radius()
			if not Rect2(officer.position-Vector2.ONE*radius,Vector2.ONE*radius*2).intersects(view): continue
			var edge_color := Color("eb977b") if officer.state == "chasing" or officer.alert_mode() else Color("e1c787")
			edge_color.a = 0.48
			draw_set_transform(officer.position)
			var outline: PackedVector2Array = officer.view_polygon()
			if presentation.lighting.period == "day" and outline.size() >= 3:
				var fill := edge_color
				fill.a = 0.12
				var mesh: ArrayMesh = officer.view_mesh()
				if mesh.get_surface_count() > 0: draw_mesh(mesh,null,Transform2D.IDENTITY,fill)
			if officer.half_fov() >= PI-0.00001 and not outline.is_empty():
				outline.append(outline[0])
			if outline.size() >= 2:
				draw_polyline(outline,edge_color,1.2,true)
		draw_set_transform(Vector2.ZERO)
		var point: Vector2 = world.door.position+Vector2(-27,world.door.size.y*0.5)
		for gate in world.access_doors:
			var text: String = "食堂已关 · 12–14开放" if gate.closed else "食堂开放"
			if str(gate.get("kind","")) == "confinement": text = str(gate.get("name","禁闭室"))+(" · 已锁" if gate.closed else " · 已开")
			if str(gate.get("kind","")) == "workshop": text = "车间锁门 · 请在工位劳动" if gate.closed else "车间入场" if game.workshop and game.workshop.on_duty() else "车间开放"
			if not world.roofed_cells.any(func(spec): return str(spec.door_id) == str(gate.id)):
				draw_string(presentation.font,gate.rect.get_center()+Vector2(-75,38),text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,label_color)
			if float(gate.progress) > 0 and gate.closed:
				var bar := Rect2(gate.rect.get_center()+Vector2(-35,50),Vector2(70,5))
				draw_rect(bar,Color("536052"))
				draw_rect(Rect2(bar.position,Vector2(bar.size.x*float(gate.progress),bar.size.y)),Color("9a8fb9"))
		if world.lock_progress > 0 and not world.door_open:
			var progress_offset := Vector2(-28,-float(presentation.visuals[0].definition.world_height)-48)
			draw_rect(Rect2(point+progress_offset,Vector2(56,6)),Color("536052"))
			draw_rect(Rect2(point+progress_offset,Vector2(56*world.lock_progress,6)),Color("9a8fb9"))
		for visual in presentation.visuals:
			if not visual.actor.escaped and not world.is_under_roof(visual.actor.position):
				draw_set_transform(visual.actor.position)
				visual.paint_information(self)
				draw_set_transform(Vector2.ZERO)
		if game.items_view:
			game.items_view.paint_information(self)
		if game.room_config.has("cafeteria"):
			var cafeteria: Dictionary = game.room_config.cafeteria
			var pickup: Array = cafeteria.pickup_label
			var returned: Array = cafeteria.return_label
			draw_string(presentation.font,Vector2(pickup[0],pickup[1]),"取餐 · 12:00–14:00",HORIZONTAL_ALIGNMENT_LEFT,-1,16,label_color)
			draw_string(presentation.font,Vector2(returned[0],returned[1]),"餐盘回收",HORIZONTAL_ALIGNMENT_LEFT,-1,16,label_color)
			if cafeteria.get("enclosed",false):
				var entrance: Array = cafeteria.entrance
				var door_center := Vector2(entrance[0]+entrance[2]/2.0,entrance[1]+entrance[3]/2.0)
				draw_rect(Rect2(door_center-Vector2(20,entrance[3]/2.0),Vector2(40,entrance[3])),Color(0.20,0.55,0.51,0.08))
				if not cafeteria.get("painted_frontage",false):
					draw_string(presentation.font,door_center+Vector2(35,-60),"食堂入口",HORIZONTAL_ALIGNMENT_LEFT,-1,16,label_color)
				var sign: Array = cafeteria.wall_sign
				var sign_rect := Rect2(sign[0],sign[1],sign[2],sign[3])
				draw_rect(sign_rect,Color("ded2ad"))
				draw_rect(sign_rect,Color("716d5b"),false,2,true)
				draw_string(presentation.font,sign_rect.position+Vector2(12,29),"食堂",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("403f35"))
				var rules: Array = cafeteria.discipline_sign
				var rules_rect := Rect2(rules[0],rules[1],rules[2],rules[3])
				draw_rect(rules_rect,Color("ded2ad"))
				draw_rect(rules_rect,Color("716d5b"),false,1.5,true)
				draw_string(presentation.font,rules_rect.position+Vector2(14,25),"遵守纪律",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("535345"))
				draw_string(presentation.font,rules_rect.position+Vector2(14,49),"文明用餐",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("535345"))
