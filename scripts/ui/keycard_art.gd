extends RefCounted

# The generated material is shared. Numbers and labels are native text so
# arbitrary room numbering stays sharp and independent of randomized names.
static func caption(canvas: CanvasItem, game, id: String, font: Font, rect: Rect2):
	if not game.keycards or not game.keycards.is_card(id) or not font: return
	var entry: Dictionary=game.inventory.instances[id]
	var label: String=str(entry.get("card_label",""))
	if label.is_empty():
		label=game.inventory.item_name(id).replace("通行卡","").replace("房卡","").replace("卡","")
	var font_size: int=clampi(int(rect.size.x*0.075),8,25)
	canvas.draw_string(font,rect.position+Vector2(rect.size.x*0.43,rect.size.y*0.50),label,HORIZONTAL_ALIGNMENT_LEFT,rect.size.x*0.46,font_size,Color("293a3d"))

class CardThumbnail extends TextureRect:
	var game
	var item_id: String=""
	var font: Font
	func _draw():
		if not texture: return
		var fitted: Vector2=texture.get_size()*minf(size.x/texture.get_width(),size.y/texture.get_height())
		preload("res://scripts/ui/keycard_art.gd").caption(self,game,item_id,font,Rect2((size-fitted)/2,fitted))
