extends Node2D

const Tiles = preload("res://scripts/presentation/texture_tiles.gd")
var game
var presentation
var spec: Dictionary = {}
var footprint := Rect2()
var front := Rect2()
var roof := Rect2()
var door := Rect2()
var status_label: Label

func configure(owner_game, owner_presentation, index: int) -> void:
	game = owner_game
	presentation = owner_presentation
	spec = game.world.roofed_cells[index]
	footprint = spec.rect
	door = game.world.access_by_id(str(spec.door_id)).rect
	var base := maxf(footprint.end.y,door.end.y)
	var height := float(spec.get("height",110))
	front = Rect2(footprint.position.x,base-height,footprint.size.x,height)
	# The complete roof and facade stay within the building's plan envelope.
	# Adjacent streets remain visible; interior bodies and overlays are separately
	# occluded by the same room bounds, including at the door's open state.
	roof = Rect2(footprint.position,Vector2(footprint.size.x,front.position.y-footprint.position.y))
	z_index = int(base)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	status_label = Label.new()
	status_label.add_theme_font_override("font",presentation.font)
	status_label.add_theme_font_size_override("font_size",14)
	status_label.add_theme_color_override("font_color",Color("dfddc9"))
	status_label.position = Vector2(footprint.position.x+10,base+5)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	status_label.material = unshaded
	add_child(status_label)
	tick_information()
	queue_redraw()

func tick_information() -> void:
	if game.room_access == null: return
	var gate: Dictionary = game.world.access_by_id(str(spec.door_id))
	var text := "禁闭室 · 已锁" if gate.get("closed",true) else "禁闭室 · 已开"
	for id in game.room_access.held:
		if str(game.room_access.cells()[int(game.room_access.held[id].cell)].get("door_id","")) == str(spec.door_id):
			text = "伙伴%d · %s" % [int(id)+1,game.room_access.label_for(int(id))]
	if status_label.text != text: status_label.text = text

func paint_surface(id: String, area: Rect2, fallback: Color, tint := Color.WHITE) -> void:
	if not area.has_area(): return
	# Opaque underpaint guarantees that material edge pixels never expose a bed,
	# light or moving character beneath this sealed building.
	draw_rect(area,fallback)
	var texture: Texture2D = game.world.art_textures.get(id)
	if texture == null: return
	var dims: Array = spec.get("roof_tile_size",[320,240]) if id == str(spec.get("roof","solitary_roof_v23")) else presentation.asset_definitions.get(id,{}).get("world_size",[128,110])
	Tiles.paint(self,texture,area,Vector2(dims[0],dims[1]),area,tint)

func _draw() -> void:
	if game == null: return
	var roof_id := str(spec.get("roof","solitary_roof_v23"))
	var front_id := str(spec.get("front","solitary_wall_front_v23"))
	var top_id := str(spec.get("top","solitary_coping_v23"))
	paint_surface(roof_id,roof,Color("484c48"))
	# A dark interior recess is still opaque when the leaf opens; the gameplay
	# gate alone owns collision, so opening the slab permits rescue and passage.
	draw_rect(front,Color("202a2a"))
	var left := Rect2(front.position,Vector2(maxf(0,door.position.x-front.position.x),front.size.y))
	var right := Rect2(Vector2(door.end.x,front.position.y),Vector2(maxf(0,front.end.x-door.end.x),front.size.y))
	paint_surface(front_id,left,Color("525c54"))
	paint_surface(front_id,right,Color("525c54"))
	# Solid coping edges around the roof and short jamb reveals join the metal
	# asset to the masonry, sharing its baseline instead of drawing an arch.
	for edge in [Rect2(roof.position,Vector2(roof.size.x,12)),Rect2(roof.position,Vector2(12,roof.size.y)),Rect2(Vector2(roof.end.x-12,roof.position.y),Vector2(12,roof.size.y)),Rect2(Vector2(roof.position.x,roof.end.y-12),Vector2(roof.size.x,12))]:
		paint_surface(top_id,edge,Color("62675e"))
	var eave := Rect2(roof.position.x-2,roof.end.y,roof.size.x+4,8)
	paint_surface(top_id,eave,Color("3b443e"),Color(0.65,0.65,0.65,1))
	draw_line(eave.position+Vector2(0,8),eave.end,Color("303b3c"),1.5,true)
	for jamb in [Rect2(door.position.x-14,front.position.y,14,front.size.y),Rect2(door.end.x,front.position.y,14,front.size.y)]:
		paint_surface(top_id,jamb,Color("62675e"))
	var outline := Color("303b3c")
	draw_rect(roof,outline,false,1.5,true)
	draw_line(front.position+Vector2(0,front.size.y),front.end,outline,1.5,true)
	var plaque := Rect2(front.end.x-56,front.position.y+34,48,25)
	draw_rect(plaque,Color("c9c5aa"))
	draw_rect(plaque,outline,false,1.2,true)
	draw_string(presentation.font,plaque.position+Vector2(3,17),"禁闭室",HORIZONTAL_ALIGNMENT_LEFT,-1,13,outline)
