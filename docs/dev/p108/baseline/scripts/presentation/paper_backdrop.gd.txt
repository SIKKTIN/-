extends Node2D

# Separate paper from the lit room canvas, so the outer page stays readable.
func _ready() -> void:
	z_index = -1000
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	get_viewport().size_changed.connect(queue_redraw)

func _draw() -> void:
	# Screen-space frame hides the scrolled world outside the map panel.
	var size := get_viewport_rect().size
	var paper := Color("f2ebdd")
	draw_rect(Rect2(0,0,size.x,114),paper)
	draw_rect(Rect2(0,674,size.x,maxf(0,size.y-674)),paper)
	draw_rect(Rect2(0,114,74,560),paper)
	draw_rect(Rect2(996,114,maxf(0,size.x-996),560),paper)
