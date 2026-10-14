extends RefCounted

const Tiles = preload("res://scripts/presentation/texture_tiles.gd")

static func paint(canvas: CanvasItem, texture: Texture2D, definition: Dictionary, rect: Rect2, mirror_x := false, clip := Rect2(), phase_shift := Vector2.ZERO, textures: Dictionary = {}, definitions: Dictionary = {}, mirror_y := false) -> void:
	if not definition.has("assembly_patches"):
		if mirror_y:
			Tiles.paint_region(canvas,texture,rect,Rect2(Vector2.ZERO,texture.get_size()),Color.WHITE,not mirror_x,2,clip)
			return
		var visible_rect := rect.intersection(clip) if clip.has_area() else rect
		if not visible_rect.has_area(): return
		var ratio := texture.get_size()/rect.size
		var source := Rect2((visible_rect.position-rect.position)*ratio,visible_rect.size*ratio)
		if mirror_x: source.position.x = texture.get_width()-source.end.x
		Tiles.paint_region(canvas,texture,visible_rect,source,Color.WHITE,mirror_x)
		return
	var source_origin := Vector2.ZERO
	var source_scale := Vector2.ONE
	if texture is AtlasTexture:
		texture = texture.atlas
	elif definition.has("region"):
		# WorldTexture crops before mip generation. Assembly source coordinates
		# are absolute in the original PNG, so register them to that crop once.
		var region: Array = definition.region
		source_origin = Vector2(region[0],region[1])
		# Bounded textures retain original-pixel assembly metadata. Translate
		# UVs into the cropped and resized runtime texture before sampling.
		source_scale = texture.get_size()/Vector2(region[2],region[3])
	var dims: Array = definition.render_size
	var scale := rect.size/Vector2(dims[0],dims[1])
	for patch in definition.assembly_patches:
		var patch_texture: Texture2D = texture
		var patch_origin := source_origin
		var patch_scale := source_scale
		if patch.has("texture_asset"):
			var asset_id := str(patch.texture_asset)
			patch_texture = textures.get(asset_id)
			if patch_texture == null: continue
			var crop: Array = definitions[asset_id].get("region",[0,0,patch_texture.get_width(),patch_texture.get_height()])
			patch_origin = Vector2(crop[0],crop[1])
			patch_scale = patch_texture.get_size()/Vector2(crop[2],crop[3])
		var src: Array = patch.source
		var dest: Array = patch.destination
		var region := Rect2((Vector2(src[0],src[1])-patch_origin)*patch_scale,Vector2(src[2],src[3])*patch_scale)
		if patch.has("phase_axis"):
			var phase := phase_shift.y if patch.phase_axis == "y" else phase_shift.x
			region.position.x += phase/float(definition.get("tile_period",128))*texture.get_width()
		var area := Rect2(rect.position+Vector2(dest[0],dest[1])*scale,Vector2(dest[2],dest[3])*scale)
		if mirror_x:
			area.position.x = rect.end.x-(float(dest[0])+float(dest[2]))*scale.x
		if mirror_y:
			area.position.y = rect.end.y-(float(dest[1])+float(dest[3]))*scale.y
		var tint = patch.get("modulate",[1,1,1,1])
		var color := Color(tint[0],tint[1],tint[2],tint[3]) if tint is Array else Color(float(tint),float(tint),float(tint),1)
		var polygon := PackedVector2Array()
		for point in patch.get("clip_polygon",[]):
			polygon.append(Vector2(1-float(point[0]) if mirror_x else float(point[0]),1-float(point[1]) if mirror_y else float(point[1])))
		var reflected_x: bool = mirror_x != bool(patch.get("mirror_x",false))
		var turns := int(patch.get("rotation_quarters",0))
		# UV horizontal reflection plus a half-turn is vertical reflection.
		# Reflection follows the patch's own rotation in paint_region.
		if mirror_y: reflected_x = not reflected_x; turns += 2
		Tiles.paint_region(canvas,patch_texture,area,region,color,reflected_x,turns,clip,patch.get("transpose",false),polygon)
