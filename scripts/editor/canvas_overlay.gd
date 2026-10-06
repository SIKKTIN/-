extends Node2D
var canvas
func _draw() -> void:
	if canvas != null: canvas.paint_foreground(self)
