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

# A continuous vertex-color ramp replaces hard-edged subpixel strips. UVs
# follow the same world tile registration as paint(), including partial cells.
static func paint_side_gradient(canvas: CanvasItem, texture: Texture2D, area: Rect2, tile: Vector2, side: Rect2, light: Color, shade: Color) -> void:
	var cursor := area.position
	var transition_end := minf(side.end.x,side.position.x+1.1)
	while cursor.x < area.end.x:
		cursor.y = area.position.y
		while cursor.y < area.end.y:
			var cell := Rect2(cursor,Vector2(minf(tile.x,area.end.x-cursor.x),minf(tile.y,area.end.y-cursor.y)))
			for slice in [Rect2(side.position,Vector2(transition_end-side.position.x,side.size.y)),Rect2(Vector2(transition_end,side.position.y),Vector2(side.end.x-transition_end,side.size.y))]:
				var visible := cell.intersection(slice)
				if not visible.has_area():
					continue
				var left := light.lerp(shade,clampf((visible.position.x-side.position.x)/1.1,0,1))
				var right := light.lerp(shade,clampf((visible.end.x-side.position.x)/1.1,0,1))
				var points := PackedVector2Array([visible.position,Vector2(visible.end.x,visible.position.y),visible.end,Vector2(visible.position.x,visible.end.y)])
				var uvs := PackedVector2Array()
				for point in points:
					uvs.append((point-cursor)/tile)
				canvas.draw_polygon(points,PackedColorArray([left,right,right,left]),uvs,texture)
			cursor.y += tile.y
		cursor.x += tile.x
