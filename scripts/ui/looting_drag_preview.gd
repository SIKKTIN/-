extends Control

const Art=preload("res://scripts/ui/looting_skin.gd")
var icon: Texture2D
var font: Font
var item_name: String=""
var hint: String="拖到右侧背包"
var state:=0
var styles: Dictionary={}
var compact:=false

func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	size=Vector2(112,114) if compact else Vector2(160,172)
	# A sibling of the looting panel, above every modal control and scroll clip.
	z_index=200
	for key in [-1,0,1]:
		var tint: Color={-1:Color("e89179"),0:Art.AMBER,1:Color("78dcc1")}[key]
		var style=Art.box(Color("202d2b"),tint,9,0)
		style.set_border_width_all(3)
		style.shadow_color=Color(0,0,0,0.55)
		style.shadow_size=7
		style.shadow_offset=Vector2(0,4)
		styles[key]=style

func feedback(next_state: int, text: String):
	if state==next_state and hint==text:return
	state=next_state
	hint=text
	queue_redraw()

func _draw():
	if styles.is_empty():return
	if compact:
		if icon:
			var area:=Rect2(4,0,104,82)
			var fitted:=icon.get_size()*minf(area.size.x/icon.get_width(),area.size.y/icon.get_height())
			draw_texture_rect(icon,Rect2(area.position+(area.size-fitted)/2,fitted),false,Color(1,1,1,0.85))
		if font:
			var caption:=hint.left(8)
			var width:=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
			draw_style_box(Art.box(Color("e9dfc9"),Art.AMBER if state>=0 else Color("d27b64"),4,0),Rect2((size.x-width-12)/2,86,width+12,24))
			draw_string(font,Vector2((size.x-width)/2,103),caption,HORIZONTAL_ALIGNMENT_LEFT,104,12,Art.INK)
		return
	draw_style_box(styles[state],Rect2(Vector2.ZERO,size))
	if icon:
		var area:=Rect2(10,8,140,112)
		var fitted:=icon.get_size()*minf(area.size.x/icon.get_width(),area.size.y/icon.get_height())
		draw_texture_rect(icon,Rect2(area.position+(area.size-fitted)/2,fitted),false)
	if font:
		var title_width:=font.get_string_size(item_name,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x
		draw_string(font,Vector2(maxf(10,(size.x-title_width)/2),139),item_name,HORIZONTAL_ALIGNMENT_LEFT,140,17,Art.LIGHT)
		var tint: Color={-1:Color("e89179"),0:Art.AMBER,1:Color("78dcc1")}[state]
		var hint_width:=font.get_string_size(hint,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
		draw_string(font,Vector2(maxf(8,(size.x-hint_width)/2),161),hint,HORIZONTAL_ALIGNMENT_LEFT,144,14,tint)
