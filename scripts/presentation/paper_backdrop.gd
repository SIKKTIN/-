extends Node2D

# Separate paper from the lit room canvas, so the outer page stays readable.
func _ready() -> void:
	z_index = -1
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	get_viewport().size_changed.connect(queue_redraw)

func _draw() -> void:
	draw_rect(get_viewport_rect(),Color("f2ebdd"))
