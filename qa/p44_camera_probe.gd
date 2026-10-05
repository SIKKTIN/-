extends "res://scripts/core/map_camera.gd"

# QA-only overview: the production camera keeps its normal zoom and behavior.
func world_view_rect() -> Rect2:
	return Rect2(position,view_rect().size/zoom)
