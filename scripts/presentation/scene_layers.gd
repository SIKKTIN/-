extends Node2D

const SoftShadow = preload("res://scripts/presentation/soft_shadow.gd")

var game
var presentation
var kind: String

func configure(owner_game, owner_presentation, type: String) -> void:
	game = owner_game
	presentation = owner_presentation
	kind = type
	z_index = 10 if kind == "ground" else 2000
	if kind == "information":
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded

func _draw() -> void:
	if not game:
		return
	var world = game.world
	if kind == "ground":
		var tint := Color("c9534b") if game.guard.state == "chasing" else Color("d9ac54")
		tint.a = 0.21
		draw_set_transform(game.guard.position)
		draw_colored_polygon(game.guard.view_polygon(),tint)
		draw_set_transform(Vector2.ZERO)
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
		draw_rect(Rect2(986,355,10,180),Color("328b82"))
		draw_texture_rect(world.art_textures.exit_v01,Rect2(927,410,54,54),false)
	else:
		var point: Vector2 = world.door.position+Vector2(-27,world.door.size.y*0.5)
		draw_arc(point,10,0,TAU,24,Color("9a8fb9"),2,true)
		if world.lock_progress > 0 and not world.door_open:
			var progress_offset := Vector2(-28,-float(presentation.visuals[0].definition.world_height)-48)
			draw_rect(Rect2(point+progress_offset,Vector2(56,6)),Color("536052"))
			draw_rect(Rect2(point+progress_offset,Vector2(56*world.lock_progress,6)),Color("9a8fb9"))
		for visual in presentation.visuals:
			if not visual.actor.escaped:
				draw_set_transform(visual.actor.position)
				visual.paint_information(self)
				draw_set_transform(Vector2.ZERO)
