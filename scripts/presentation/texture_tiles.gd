extends RefCounted

# A few retained quads fade a local floor into the underlying pavement.
# Shared UV registration keeps the source image unchanged and tile seams aligned.
static func paint_soft_edges(canvas: CanvasItem, texture: Texture2D, area: Rect2, tile: Vector2, clip: Rect2, floor_area: Rect2, feather: float, tint: Color) -> void:
	var xs := [floor_area.position.x,floor_area.position.x+feather,floor_area.end.x-feather,floor_area.end.x]
	var ys := [floor_area.position.y,floor_area.position.y+feather,floor_area.end.y-feather,floor_area.end.y]
	var cursor := area.position
	while cursor.x < area.end.x:
		cursor.y = area.position.y
		while cursor.y < area.end.y:
			var cell := Rect2(cursor,tile).intersection(clip)
			for x in range(3):
				for y in range(3):
					var part := Rect2(xs[x],ys[y],xs[x+1]-xs[x],ys[y+1]-ys[y]).intersection(cell)
					if part.size.x < .001 or part.size.y < .001:continue
					var points := PackedVector2Array([part.position,Vector2(part.end.x,part.position.y),part.end,Vector2(part.position.x,part.end.y)])
					var colors := PackedColorArray()
					var uvs := PackedVector2Array()
					for point in points:
						var color := tint
						color.a *= clampf(minf(minf(point.x-floor_area.position.x,floor_area.end.x-point.x),minf(point.y-floor_area.position.y,floor_area.end.y-point.y))/feather,0,1)
						colors.append(color)
						uvs.append((point-cursor)/tile)
					canvas.draw_polygon(points,colors,uvs,texture)
			cursor.y += tile.y
		cursor.x += tile.x

# Tail tiles keep the same world scale by cropping the source region.
static func paint_polygon(canvas: CanvasItem, texture: Texture2D, area: Rect2, tile: Vector2, clip: Rect2, shape: PackedVector2Array, tint: Color = Color.WHITE) -> void:
	var cursor := area.position
	while cursor.x < area.end.x:
		cursor.y = area.position.y
		while cursor.y < area.end.y:
			var cell := Rect2(cursor,tile).intersection(clip)
			if cell.has_area():
				var corners := PackedVector2Array([cell.position,Vector2(cell.end.x,cell.position.y),cell.end,Vector2(cell.position.x,cell.end.y)])
				for piece in Geometry2D.intersect_polygons(shape,corners):
					# A tile touching a curved/concave boundary can yield a sliver
					# with no drawable triangles. Keep it out of the canvas server.
					if piece.size()<3 or Geometry2D.triangulate_polygon(piece).is_empty(): continue
					var colors := PackedColorArray()
					var uvs := PackedVector2Array()
					for point in piece:
						colors.append(tint)
						uvs.append((point-cursor)/tile)
					canvas.draw_polygon(piece,colors,uvs,texture)
			cursor.y += tile.y
		cursor.x += tile.x

# Repeat the original edging pixels along an authored curved perimeter.
# Only the ground outline is painted; it introduces no movement obstacle.
static func paint_outline(canvas: CanvasItem, texture: Texture2D, shape: PackedVector2Array, width: float, repeat_length: float, clip: Rect2) -> void:
	var progress := 0.0
	var clipping := PackedVector2Array([clip.position,Vector2(clip.end.x,clip.position.y),clip.end,Vector2(clip.position.x,clip.end.y)])
	for index in range(shape.size()):
		var start := shape[index]
		var end := shape[(index+1)%shape.size()]
		var length := start.distance_to(end)
		if length < .001: continue
		var tangent := (end-start)/length
		var normal := Vector2(-tangent.y,tangent.x)
		var cursor := 0.0
		while cursor < length-.001:
			var uv_start := fposmod(progress+cursor,repeat_length)/repeat_length
			var span := minf(length-cursor,(1-uv_start)*repeat_length)
			if span < .001: span=minf(length-cursor,repeat_length)
			var a := start+tangent*cursor
			var b := a+tangent*span
			var quad := PackedVector2Array([a-normal*width/2,b-normal*width/2,b+normal*width/2,a+normal*width/2])
			for piece in Geometry2D.intersect_polygons(quad,clipping):
				if absf(_signed_area(piece)) < .001: continue
				var uvs := PackedVector2Array()
				var colors := PackedColorArray()
				for p in piece:
					uvs.append(Vector2(uv_start+(p-a).dot(tangent)/repeat_length,.5+(p-a).dot(normal)/width))
					colors.append(Color.WHITE)
				canvas.draw_polygon(piece,colors,uvs,texture)
			cursor += span
		progress += length

static func _signed_area(shape: PackedVector2Array) -> float:
	var area := 0.0
	for i in range(shape.size()): area += shape[i].cross(shape[(i+1)%shape.size()])
	return area*.5

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

static func paint_region(canvas: CanvasItem, texture: Texture2D, area: Rect2, source: Rect2, modulate := Color.WHITE, mirror_x := false, rotation_quarters := 0, clip := Rect2(), transpose := false, polygon := PackedVector2Array()) -> void:
	var visible_area := area.intersection(clip) if clip.has_area() else area
	if not visible_area.has_area(): return
	if polygon.is_empty() and not mirror_x and not transpose and rotation_quarters % 4 == 0:
		var ratio := source.size/area.size
		canvas.draw_texture_rect_region(texture,visible_area,Rect2(source.position+(visible_area.position-area.position)*ratio,visible_area.size*ratio),modulate)
		return
	# Rounding can leave a near-zero clipped tail below quad triangulation tolerance.
	# At supported camera zooms this is invisible; omit the degenerate quad.
	if visible_area.size.x < 0.001 or visible_area.size.y < 0.001: return
	# Explicit UV reflection avoids negative destination rectangles: region
	# clipping and custom alpha shaders do not consistently mirror those.
	var corners := PackedVector2Array([visible_area.position,Vector2(visible_area.end.x,visible_area.position.y),visible_area.end,Vector2(visible_area.position.x,visible_area.end.y)])
	if not polygon.is_empty():
		var shape := PackedVector2Array()
		for point in polygon: shape.append(area.position+point*area.size)
		var intersections := Geometry2D.intersect_polygons(shape,corners)
		if intersections.is_empty(): return
		# Assembly masks are convex mitre triangles, so clipping yields one part.
		corners = intersections[0]
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
	var colors := PackedColorArray()
	colors.resize(corners.size())
	colors.fill(modulate)
	canvas.draw_polygon(corners,colors,uvs,texture)

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
