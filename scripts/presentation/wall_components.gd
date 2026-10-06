extends RefCounted

const Tiles = preload("res://scripts/presentation/texture_tiles.gd")

static func paint(canvas: CanvasItem, texture: Texture2D, definition: Dictionary, rect: Rect2, mirror_x := false, clip := Rect2(), phase_shift := Vector2.ZERO) -> void:
	if not definition.has("assembly_patches"):
		var visible_rect := rect.intersection(clip) if clip.has_area() else rect
		if not visible_rect.has_area(): return
		var ratio := texture.get_size()/rect.size
		var source := Rect2((visible_rect.position-rect.position)*ratio,visible_rect.size*ratio)
		if mirror_x: source.position.x = texture.get_width()-source.end.x
		Tiles.paint_region(canvas,texture,visible_rect,source,Color.WHITE,mirror_x)
		return
	var source_origin := Vector2.ZERO
	if texture is AtlasTexture:
		texture = texture.atlas
	elif definition.has("region"):
		# WorldTexture crops before mip generation. Assembly source coordinates
		# are absolute in the original PNG, so register them to that crop once.
		var region: Array = definition.region
		source_origin = Vector2(region[0],region[1])
	var dims: Array = definition.render_size
	var scale := rect.size/Vector2(dims[0],dims[1])
	for patch in definition.assembly_patches:
		var src: Array = patch.source
		var dest: Array = patch.destination
		var region := Rect2(Vector2(src[0],src[1])-source_origin,Vector2(src[2],src[3]))
		if patch.has("phase_axis"):
			var phase := phase_shift.y if patch.phase_axis == "y" else phase_shift.x
			region.position.x += phase/float(definition.get("tile_period",128))*texture.get_width()
		var area := Rect2(rect.position+Vector2(dest[0],dest[1])*scale,Vector2(dest[2],dest[3])*scale)
		if mirror_x:
			area.position.x = rect.end.x-(float(dest[0])+float(dest[2]))*scale.x
		var tint = patch.get("modulate",[1,1,1,1])
		var color := Color(tint[0],tint[1],tint[2],tint[3]) if tint is Array else Color(float(tint),float(tint),float(tint),1)
		Tiles.paint_region(canvas,texture,area,region,color,mirror_x != bool(patch.get("mirror_x",false)),int(patch.get("rotation_quarters",0)),clip,patch.get("transpose",false))
