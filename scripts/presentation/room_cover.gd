extends Node2D

const Tiles = preload("res://scripts/presentation/texture_tiles.gd")
var visibility_rules
var room: Dictionary
var roof_texture: Texture2D
var cap_texture: Texture2D
var area := Rect2()

func configure(rules, spec: Dictionary) -> void:
	visibility_rules = rules
	room = spec
	area = room.area
	roof_texture = rules.game.world.art_textures.get("solitary_roof_v23")
	cap_texture = rules.game.world.art_textures.get("cafeteria_coping_v23")
	# Front facades/doors retain their original ground depth above the roof.
	z_index = mini(4094,int(area.end.y)-1)
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	tick(0,true)

func tick(delta: float, immediate := false) -> void:
	var target := 0.0 if visibility_rules.active_id == str(room.id) else 1.0
	if modulate.a == target and not immediate: return
	modulate.a = target if immediate else move_toward(modulate.a,target,maxf(delta,0)/0.2)
	visible = modulate.a > 0.001

func _draw() -> void:
	# Cached roof commands; crossing a doorway changes only alpha, not meshes.
	draw_rect(area,Color("666b62"))
	if roof_texture:
		var scale := Vector2(320,240)/roof_texture.get_size()
		draw_set_transform(area.position,0,scale)
		draw_texture_rect(roof_texture,Rect2(Vector2.ZERO,area.size/scale),true)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_rect(area,Color("666b62"))
	for edge in [Rect2(area.position,Vector2(area.size.x,10)),Rect2(area.position,Vector2(10,area.size.y)),Rect2(area.position.x,area.end.y-10,area.size.x,10),Rect2(area.end.x-10,area.position.y,10,area.size.y)]:
		if cap_texture: draw_texture_rect(cap_texture,edge,false)
		else: draw_rect(edge,Color("b4b09a"))
	draw_rect(area,Color("464b44"),false,2,true)
