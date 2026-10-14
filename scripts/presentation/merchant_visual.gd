extends Node2D

var items_view
var actor

func configure(owner_view, owner_actor) -> void:
	items_view=owner_view
	actor=owner_actor
	material=items_view.game.presentation.character_material
	tick_visual()

func tick_visual() -> void:
	var game=items_view.game
	# Match the foot-depth rule used by prisoners and guards. The merchant
	# body belongs to its moving actor, not the fixed ground-item layer.
	actor.z_index=preload("res://scripts/presentation/world_depth.gd").for_y(actor.position.y+float(actor.service_spec.get("draw_depth_offset",0)),game.world.bounds.end.y) if game.perspective_floor else 21
	visible=bool(actor.service_spec.get("exterior_service",false)) or not game.world.is_under_roof(actor.position)
	queue_redraw()

func _draw() -> void:
	items_view.paint_merchant_body(self,actor)
