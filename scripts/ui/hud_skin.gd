extends RefCounted

const INK := Color("303b46")
const PAPER := Color("eee6d5")
const TEAL := Color("328b82")
static var cache := {}

static func box(kind := "paper") -> StyleBoxFlat:
	if cache.has(kind): return cache[kind]
	var style := StyleBoxFlat.new()
	style.bg_color = {"paper":PAPER,"canvas":Color("e3dac5"),"inset":Color("e5ddcd"),"selected":Color("eaf0e7"),"teal":TEAL,"disabled":Color("dedbce")}.get(kind,PAPER)
	style.border_color = TEAL if kind=="selected" else Color("596159")
	style.set_border_width_all(3 if kind=="selected" else 2)
	style.set_corner_radius_all(9)
	style.shadow_color = Color(0,0,0,0.19)
	style.shadow_size = 3 if kind in ["paper","canvas","teal"] else 0
	style.shadow_offset = Vector2(0,2)
	style.set_content_margin_all(10)
	cache[kind] = style
	return style

static func button(control: Button, accent := false):
	control.add_theme_stylebox_override("normal",box("teal" if accent else "paper"))
	control.add_theme_stylebox_override("hover",box("selected"))
	control.add_theme_stylebox_override("pressed",box("inset"))
	control.add_theme_stylebox_override("disabled",box("disabled"))
	control.add_theme_color_override("font_color",Color("f7f2e7") if accent else INK)
	control.add_theme_color_override("font_hover_color",INK)
	control.add_theme_color_override("font_pressed_color",INK)
	control.add_theme_color_override("font_disabled_color",Color("92978d"))

static func rivets(canvas: CanvasItem, size: Vector2):
	for point in [Vector2(9,9),Vector2(size.x-9,9),Vector2(9,size.y-9),size-Vector2(9,9)]:
		canvas.draw_circle(point,3.2,Color("4a514c"),true,-1,true)
		canvas.draw_circle(point-Vector2(0.6,0.6),2.2,Color("b1b2a1"),true,-1,true)
		canvas.draw_line(point-Vector2(1.3,-1.3),point+Vector2(1.3,-1.3),Color("62685f"),1,true)

class Plate extends Panel:
	var canvas_header := false
	func _ready():
		add_theme_stylebox_override("panel",preload("res://scripts/ui/hud_skin.gd").box("canvas" if canvas_header else "paper"))
		resized.connect(queue_redraw)
	func _draw():
		preload("res://scripts/ui/hud_skin.gd").rivets(self,size)
		draw_line(Vector2(17,5),Vector2(size.x-17,5),Color(1,1,1,0.35),1,true)
		if canvas_header:
			for x in range(20,int(size.x)-20,9):
				draw_line(Vector2(x,size.y-7),Vector2(x+4,size.y-7),Color("a89f8b"),1,true)
