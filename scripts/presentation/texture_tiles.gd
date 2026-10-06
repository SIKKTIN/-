extends RefCounted

# Tail tiles keep the same world scale by cropping the source region.
static func paint(canvas: CanvasItem, texture: Texture2D, area: Rect2, tile: Vector2, clip: Rect2, modulate: Color = Color.WHITE, mirror_x: bool = false) -> void:
	var cursor := area.position
	while cursor.x < area.end.x:
		cursor.y = area.position.y
		while cursor.y < area.end.y:
			var cell := Rect2(cursor, Vector2(minf(tile.x,area.end.x-cursor.x),minf(tile.y,area.end.y-cursor.y)))
			var visible_cell := cell.intersection(clip)
			if visible_cell.has_area():
				var ratio := texture.get_size()/tile
				var source := Rect2((visible_cell.position-cursor)*ratio,visible_cell.size*ratio)
				if mirror_x:
					source.position.x = texture.get_width()-source.end.x
				paint_region(canvas,texture,visible_cell,source,modulate,mirror_x)
			cursor.y += tile.y
		cursor.x += tile.x

static func paint_region(canvas: CanvasItem, texture: Texture2D, area: Rect2, source: Rect2, modulate := Color.WHITE, mirror_x := false, rotation_quarters := 0, clip := Rect2(), transpose := false) -> void:
	var visible_area := area.intersection(clip) if clip.has_area() else area
	if not visible_area.has_area(): return
	if not mirror_x and not transpose and rotation_quarters % 4 == 0:
		var ratio := source.size/area.size
		canvas.draw_texture_rect_region(texture,visible_area,Rect2(source.position+(visible_area.position-area.position)*ratio,visible_area.size*ratio),modulate)
		return
	# Rounding can leave a near-zero clipped tail below quad triangulation tolerance.
	# At supported camera zooms this is invisible; omit the degenerate quad.
	if visible_area.size.x < 0.001 or visible_area.size.y < 0.001: return
	# Explicit UV reflection avoids negative destination rectangles: region
	# clipping and custom alpha shaders do not consistently mirror those.
	var corners := PackedVector2Array([visible_area.position,Vector2(visible_area.end.x,visible_area.position.y),visible_area.end,Vector2(visible_area.position.x,visible_area.end.y)])
	var uv_rect := Rect2(source.position/texture.get_size(),source.size/texture.get_size())
	var normal := PackedVector2Array([uv_rect.position,Vector2(uv_rect.end.x,uv_rect.position.y),uv_rect.end,Vector2(uv_rect.position.x,uv_rect.end.y)])
	if transpose: normal = PackedVector2Array([normal[0],normal[3],normal[2],normal[1]])
	var rotated := PackedVector2Array()
	for index in range(4): rotated.append(normal[posmod(index-rotation_quarters,4)])
	if mirror_x: rotated = PackedVector2Array([rotated[1],rotated[0],rotated[3],rotated[2]])
	var uvs := PackedVector2Array()
	for point in corners:
		var fraction := (point-area.position)/area.size
		uvs.append(rotated[0].lerp(rotated[1],fraction.x).lerp(rotated[3].lerp(rotated[2],fraction.x),fraction.y))
	canvas.draw_polygon(corners,PackedColorArray([modulate,modulate,modulate,modulate]),uvs,texture)

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
