@tool
extends RefCounted
const Tiles = preload("res://scripts/presentation/texture_tiles.gd")
const WorldTexture = preload("res://scripts/presentation/world_texture.gd")
static var textures: Dictionary = {}
static var definitions: Dictionary = {}

static func texture(id: String, file := "res://art/environment/factory_v45/manifest.json") -> Texture2D:
	if not textures.has(file):
		if not FileAccess.file_exists(file): return null
		var manifest = JSON.parse_string(FileAccess.get_file_as_string(file))
		var assets := {}
		var specs := {}
		if manifest is Dictionary:
			for asset in manifest.assets:
				assets[str(asset.id)]=WorldTexture.load_asset(asset)
				specs[str(asset.id)]=asset
		textures[file]=assets
		definitions[file]=specs
	return textures[file].get(id)

static func paint(painter: CanvasItem, config: Dictionary, clip: Rect2, offset := Vector2.ZERO, scale_factor := 1.0) -> void:
	var screen_clip := Rect2(offset+clip.position*scale_factor,clip.size*scale_factor)
	var manifest_path: String = config.get("terrain_manifest","res://art/environment/factory_v45/manifest.json")
	for region in config.get("floor_regions",[]):
		var values: Array = region.rect
		var area := Rect2(values[0],values[1],values[2],values[3])
		if not area.intersects(clip):continue
		var source := texture(str(region.asset_id),manifest_path)
		if source == null:continue
		var dims: Array = region.get("tile_size",[640,640])
		var tile := Vector2(dims[0],dims[1])
		var visible_area := area.intersection(clip)
		var start := area.position+((visible_area.position-area.position)/tile).floor()*tile
		var end := area.position+((visible_area.end-area.position)/tile).ceil()*tile
		var paint_area := Rect2(offset+start*scale_factor,(end-start)*scale_factor)
		var paint_clip := Rect2(offset+visible_area.position*scale_factor,visible_area.size*scale_factor)
		Tiles.paint(painter,source,paint_area,tile*scale_factor,paint_clip,Color(region.get("tint","#ffffff")))
	# Natural ground patches use their original soft alpha and free placement.
	# They never participate in collision, tile snapping or room visibility.
	for patch in config.get("terrain_patches",[]):
		var values: Array = patch.rect
		var area := Rect2(values[0],values[1],values[2],values[3])
		if not area.intersects(clip):continue
		var source := texture(str(patch.asset_id),manifest_path)
		if source == null:continue
		var spec: Dictionary=definitions[manifest_path].get(str(patch.asset_id),{})
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
