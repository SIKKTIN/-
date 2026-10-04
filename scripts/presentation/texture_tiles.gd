extends RefCounted

# Tail tiles keep the same world scale by cropping the source region.
static func paint(canvas: CanvasItem, texture: Texture2D, area: Rect2, tile: Vector2, clip: Rect2, modulate: Color = Color.WHITE) -> void:
	var cursor := area.position
	while cursor.x < area.end.x:
		cursor.y = area.position.y
		while cursor.y < area.end.y:
			var cell := Rect2(cursor, Vector2(minf(tile.x,area.end.x-cursor.x),minf(tile.y,area.end.y-cursor.y)))
			var visible_cell := cell.intersection(clip)
			if visible_cell.has_area():
				var ratio := texture.get_size()/tile
				canvas.draw_texture_rect_region(texture,visible_cell,Rect2((visible_cell.position-cursor)*ratio,visible_cell.size*ratio),modulate)
			cursor.y += tile.y
		cursor.x += tile.x
