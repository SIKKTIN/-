extends RefCounted

const INK:=Color("303b3c")
const LIGHT:=Color("eee8d7")
const MUTED:=Color("b9bbac")
const AMBER:=Color("dca94b")
const TEAL:=Color("2a8279")
const BAG_ATLAS=preload("res://art/ui/looting_v04/bag.png")
const CLEAN_ATLAS=preload("res://art/ui/looting_v03/surfaces.png")
static var textures: Dictionary={}

static func texture(kind: String) -> Texture2D:
	if textures.has(kind):return textures[kind]
	var result:=AtlasTexture.new()
	result.atlas=BAG_ATLAS if kind=="bag" else CLEAN_ATLAS
	result.region={"drawer":Rect2(77,408,801,494),"bag":Rect2(37,102,1330,931),"frame":Rect2(75,55,1471,329),"paper":Rect2(915,530,645,145)}[kind]
	result.filter_clip=true
	textures[kind]=result
	return result

static func patch(kind: String, margins: Vector4) -> StyleBoxTexture:
	var result:=StyleBoxTexture.new()
	result.texture=texture(kind)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		result.set_texture_margin(side,margins[side])
	return result

static func box(color: Color, border: Color, radius:=6, padding:=8.0) -> StyleBoxFlat:
	var result:=StyleBoxFlat.new()
	result.bg_color=color
	result.border_color=border
	result.set_border_width_all(1)
	result.set_corner_radius_all(radius)
	result.set_content_margin_all(padding)
	return result

static func style_button(control: Button, primary:=false):
	var normal:=box(TEAL if primary else Color("e9dfc6"),Color("46a99c") if primary else Color("b7b49d"))
	normal.shadow_color=Color(0,0,0,0.24)
	normal.shadow_size=2
	normal.shadow_offset=Vector2(0,2)
	control.add_theme_stylebox_override("normal",normal)
	control.add_theme_stylebox_override("hover",box(Color("359b8f") if primary else Color("f3ebd7"),AMBER))
	control.add_theme_stylebox_override("pressed",box(Color("21645d") if primary else Color("c7bfa7"),Color("a69877")))
	control.add_theme_stylebox_override("disabled",box(Color("455650") if primary else Color("a4a796"),Color("667368")))
	for state in ["font_color","font_hover_color","font_pressed_color"]:
		control.add_theme_color_override(state,LIGHT if primary else INK)
	control.add_theme_color_override("font_disabled_color",Color("737b70") if not primary else Color("899b8b"))
	control.add_theme_color_override("icon_disabled_color",Color(1,1,1,0.32))
	control.add_theme_constant_override("h_separation",9)
	control.add_theme_constant_override("icon_max_width",24)
	control.expand_icon=true

class Frame extends Panel:
	var frame_fill: StyleBoxTexture
	func _ready():
		var skin=preload("res://scripts/ui/looting_skin.gd")
		var style: StyleBoxFlat=skin.box(Color(0.12,0.17,0.15,0.12),Color.TRANSPARENT,11)
		style.set_border_width_all(0)
		style.shadow_color=Color(0,0,0,0.4)
		style.shadow_size=9
		style.shadow_offset=Vector2(0,4)
		add_theme_stylebox_override("panel",style)
		frame_fill=skin.patch("frame",Vector4(64,64,64,64))
		texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		resized.connect(queue_redraw)
	func _draw():
		if not frame_fill:return
		# Scale border texels uniformly, then stretch only the calm center.
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE*0.2)
		draw_style_box(frame_fill,Rect2(Vector2.ZERO,size/0.2))
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

class Surface extends Panel:
	var surface_texture: Texture2D
	var drawer_fill: StyleBoxTexture
	var drawer_surface:=false
	var drop_state:=0
	func _ready():
		add_theme_stylebox_override("panel",StyleBoxEmpty.new())
		mouse_filter=Control.MOUSE_FILTER_IGNORE
		texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		if drawer_surface:drawer_fill=preload("res://scripts/ui/looting_skin.gd").patch("drawer",Vector4(80,32,32,32))
		resized.connect(queue_redraw)
	func _draw():
		if drawer_fill:
			draw_set_transform(Vector2.ZERO,0,Vector2.ONE*0.5)
			draw_style_box(drawer_fill,Rect2(Vector2.ZERO,size*2))
			draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
		elif surface_texture:draw_texture_rect(surface_texture,Rect2(Vector2.ZERO,size),false)
		if drop_state!=0:
			var tint:=Color("4faaa0") if drop_state>0 else Color("c9795a")
			var outline:=preload("res://scripts/ui/looting_skin.gd").box(Color(tint,0.06),tint,9,0)
			outline.set_border_width_all(2)
			draw_style_box(outline,Rect2(Vector2(5,5),size-Vector2(10,10)))

class SewnTag extends Panel:
	func _ready():
		add_theme_stylebox_override("panel",preload("res://scripts/ui/looting_skin.gd").box(Color("e9dfc9"),Color("97968a"),3,4))
		mouse_filter=Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw():
		for x in range(6,int(size.x)-6,8):
			draw_line(Vector2(x,4),Vector2(x+3,4),Color("aaa293"),1,true)
			draw_line(Vector2(x,size.y-4),Vector2(x+3,size.y-4),Color("aaa293"),1,true)

class PaperTag extends Panel:
	var paper_fill: StyleBoxTexture
	func _ready():
		add_theme_stylebox_override("panel",StyleBoxEmpty.new())
		paper_fill=preload("res://scripts/ui/looting_skin.gd").patch("paper",Vector4(44,24,44,24))
		texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		mouse_filter=Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw():
		if not paper_fill:return
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE*0.3)
		draw_style_box(paper_fill,Rect2(Vector2.ZERO,size/0.3))
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
