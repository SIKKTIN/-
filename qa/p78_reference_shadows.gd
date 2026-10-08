extends Node2D
const SoftShadow = preload("res://scripts/presentation/soft_shadow.gd")
var game
func _draw() -> void:
	for fixture in game.world.fixtures:
		if fixture.get("hidden",false) or game.world.is_under_roof(fixture.rect.get_center()): continue
		var definition: Dictionary = game.presentation.asset_definitions.get(str(fixture.asset_id),{})
		if definition.has("assembly_patches"):
			var filled := 0.0
			for patch in definition.assembly_patches: filled+=float(patch.destination[2])*float(patch.destination[3])
			var dims: Array=definition.render_size
			if filled<float(dims[0])*float(dims[1])*0.99: continue
		if not definition.get("shadow_baked",false) and not str(definition.get("render_mode","")).begins_with("wall"):
			SoftShadow.contact_rect(self,fixture.rect,float(definition.get("elevation_world",20)),game.world.bounds,game.presentation.profile)
