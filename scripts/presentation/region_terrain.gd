@tool
extends RefCounted
const Tiles = preload("res://scripts/presentation/texture_tiles.gd")
const WorldTexture = preload("res://scripts/presentation/world_texture.gd")
static var textures: Dictionary = {}
static var definitions: Dictionary = {}

static func texture(id: String, file := "res://art/environment/factory_v45/manifest.json") -> Texture2D:
	if not definitions.has(file):
		if not FileAccess.file_exists(file): return null
		var manifest = JSON.parse_string(FileAccess.get_file_as_string(file))
		var assets := {}
		var specs := {}
		if manifest is Dictionary:
			for asset in manifest.assets:
				specs[str(asset.id)]=asset
		textures[file]=assets
		definitions[file]=specs
	if not textures[file].has(id) and definitions[file].has(id):
		textures[file][id]=WorldTexture.load_asset(definitions[file][id])
	return textures[file].get(id)

static func warm_map(config: Dictionary) -> void:
	var file: String=config.get("terrain_manifest","res://art/environment/factory_v45/manifest.json")
	for key in ["floor_regions","terrain_patches"]:
		for spec in config.get(key,[]):texture(str(spec.asset_id),str(spec.get("manifest",file)))

static func paint(painter: CanvasItem, config: Dictionary, clip: Rect2, offset := Vector2.ZERO, scale_factor := 1.0) -> void:
	var screen_clip := Rect2(offset+clip.position*scale_factor,clip.size*scale_factor)
	var manifest_path: String = config.get("terrain_manifest","res://art/environment/factory_v45/manifest.json")
	for region in config.get("floor_regions",[]):
		var values: Array = region.rect
		var area := Rect2(values[0],values[1],values[2],values[3])
		if not area.intersects(clip):continue
		var source := texture(str(region.asset_id),str(region.get("manifest",manifest_path)))
		if source == null:continue
		var dims: Array = region.get("tile_size",[640,640])
		var tile := Vector2(dims[0],dims[1])
		var visible_area := area.intersection(clip)
		# Adjacent road regions share a world UV origin; clipping keeps each
		# authored footprint intact while their tile joints continue across it.
		var registration: Array = region.get("tile_origin",[area.position.x,area.position.y])
		var tile_origin := Vector2(registration[0],registration[1])
		var start := tile_origin+((visible_area.position-tile_origin)/tile).floor()*tile
		var end := tile_origin+((visible_area.end-tile_origin)/tile).ceil()*tile
		var paint_area := Rect2(offset+start*scale_factor,(end-start)*scale_factor)
		var paint_clip := Rect2(offset+visible_area.position*scale_factor,visible_area.size*scale_factor)
		var feather: float = float(region.get("edge_feather",0))*scale_factor
		if region.has("polygon"):
			var shape := PackedVector2Array()
			for point: Array in region.polygon: shape.append(offset+(area.position+Vector2(point[0],point[1])*area.size)*scale_factor)
			var tint := Color(region.get("tint","#ffffff"))
			if feather > 0:
				# Nested native masks fade the unchanged grass texture into paving.
				for step in range(6):
					var faded := tint
					faded.a *= [0.12,0.22,0.32,0.45,0.60,1.0][step]
					var masks := [shape] if step==0 else Geometry2D.offset_polygon(shape,-feather*step/5.0)
					for mask in masks: Tiles.paint_polygon(painter,source,paint_area,tile*scale_factor,paint_clip,mask,faded)
			else: Tiles.paint_polygon(painter,source,paint_area,tile*scale_factor,paint_clip,shape,tint)
			if region.has("outline_asset_id"):
				var edging := texture(str(region.outline_asset_id),str(region.outline_manifest))
				if edging != null: Tiles.paint_outline(painter,edging,shape,float(region.get("outline_width",12))*scale_factor,360*scale_factor,screen_clip)
		elif feather > 0:
			Tiles.paint_soft_edges(painter,source,paint_area,tile*scale_factor,paint_clip,Rect2(offset+area.position*scale_factor,area.size*scale_factor),feather,Color(region.get("tint","#ffffff")))
		else:
			Tiles.paint(painter,source,paint_area,tile*scale_factor,paint_clip,Color(region.get("tint","#ffffff")))
	# Natural ground patches use their original soft alpha and free placement.
	# They never participate in collision, tile snapping or room visibility.
	for patch in config.get("terrain_patches",[]):
		var values: Array = patch.rect
		var area := Rect2(values[0],values[1],values[2],values[3])
		if not area.intersects(clip):continue
		var patch_manifest: String=str(patch.get("manifest",manifest_path))
		var source := texture(str(patch.asset_id),patch_manifest)
		if source == null:continue
		var spec: Dictionary=definitions[patch_manifest].get(str(patch.asset_id),{})
		if spec.get("preserve_aspect",false):
			var factor:=minf(area.size.x/source.get_width(),area.size.y/source.get_height())
			var fixed_size:=source.get_size()*factor
			area=Rect2(area.get_center()-fixed_size/2,fixed_size)
		var tint := Color(patch.get("tint","#ffffff"))
		tint.a=float(patch.get("opacity",1.0))
		var patch_clip := screen_clip
		if patch.has("clip_rect"):
			var r: Array=patch.clip_rect
			patch_clip=patch_clip.intersection(Rect2(offset+Vector2(r[0],r[1])*scale_factor,Vector2(r[2],r[3])*scale_factor))
			if not patch_clip.has_area():continue
		var fixed: bool=spec.get("fixed_orientation",false)
		Tiles.paint_region(painter,source,Rect2(offset+area.position*scale_factor,area.size*scale_factor),Rect2(Vector2.ZERO,source.get_size()),tint,false if fixed else bool(patch.get("mirror_x",false)),0 if fixed else int(patch.get("rotation_quarters",0)),patch_clip)
