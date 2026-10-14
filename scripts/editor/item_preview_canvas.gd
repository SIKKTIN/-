@tool
extends Control

var texture: Texture2D
var shape := Vector2i.ONE
var background := 0
var font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	font = load("res://art/fonts/NotoSansCJKsc-Regular.otf")
	resized.connect(queue_redraw)

func set_item(icon: Texture2D, footprint: Vector2i) -> void:
	texture = icon
	shape = footprint
	queue_redraw()

func fit_texture(area: Rect2) -> void:
	if texture == null: return
	var ratio := minf(area.size.x/texture.get_width(),area.size.y/texture.get_height())
	var dims := texture.get_size()*ratio
	draw_texture_rect(texture,Rect2(area.get_center()-dims/2,dims),false)

func _draw() -> void:
	var base := Color("efe7d5") if background == 0 else Color("273633") if background == 1 else Color("858c73")
	draw_rect(Rect2(Vector2.ZERO,size),base)
	var hero := Rect2(12,12,size.x-24,maxf(80,size.y-235))
	if background == 0:
		for y in range(0,ceili(hero.size.y/20)):
			for x in range(0,ceili(hero.size.x/20)):
				if (x+y)%2 == 0: draw_rect(Rect2(hero.position+Vector2(x,y)*20,Vector2.ONE*20).intersection(hero),Color("e0dacd"))
	fit_texture(hero.grow(-25))
	var ink := Color("303e40") if background != 1 else Color("eee8d6")
	var grid_start := Vector2(24,size.y-200)
	draw_string(font,grid_start+Vector2(0,16),"背包占格预览",HORIZONTAL_ALIGNMENT_LEFT,-1,15,ink)
	var cell := minf(45,maxf(24,(size.x-240)/5))
	var grid := Rect2(grid_start+Vector2(0,26),Vector2(shape)*cell)
	for y in range(maxi(2,shape.y)):
		for x in range(5): draw_rect(Rect2(grid.position+Vector2(x,y)*cell,Vector2.ONE*cell).grow(-2),Color("a49c8a"),false,1)
	draw_rect(grid.grow(-2),Color("d4a449"),false,2)
	fit_texture(grid.grow(-8))
	var tiny_start := Vector2(size.x-190,size.y-105)
	draw_string(font,Vector2(tiny_start.x,grid_start.y+16),"小尺寸预览",HORIZONTAL_ALIGNMENT_LEFT,-1,15,ink)
	for index in range(3):
		var edge: int = [32,48,64][index]
		var offset: int = [0,48,112][index]
		fit_texture(Rect2(tiny_start+Vector2(offset,-4-edge),Vector2.ONE*edge))
		draw_string(font,tiny_start+Vector2(offset,18),str(edge)+"px",HORIZONTAL_ALIGNMENT_LEFT,-1,13,ink)
	if texture == null: draw_string(font,hero.get_center()-Vector2(70,0),"缺少美术素材",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("ba674e"))
