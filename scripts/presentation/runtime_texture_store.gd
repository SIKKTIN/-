@tool
extends RefCounted

# Generated resources keep original artwork/coordinates intact. A stale or
# absent bake falls back to the source loader, including new editor assets.
const INDEX := "res://art/runtime_textures/index.json"
const ANDROID_INDEX := "res://art/runtime_textures_android/index.json"
static var entries: Dictionary = {}
static var checked := false
static var hits := 0
static var misses := 0

static func index_path() -> String:
	return ANDROID_INDEX if OS.has_feature("android") else INDEX

static func key(asset: Dictionary, base := false) -> String:
	var region: Array=[]
	for value in asset.get("region",[]): region.append(int(value))
	return str(asset.texture)+JSON.stringify(region)+( "::limit"+str(int(asset.runtime_size_limit)) if int(asset.get("runtime_size_limit",0))>0 else "")+("::base" if base else "")

static func texture(asset: Dictionary, base := false) -> Texture2D:
	if OS.get_environment("ESCAPE_SOURCE_TEXTURES")=="1": return null
	if not checked:
		checked=true
		var selected_index := index_path()
		if FileAccess.file_exists(selected_index):
			var data=JSON.parse_string(FileAccess.get_file_as_string(selected_index))
			if data is Dictionary: entries=data.get("textures",{})
	var entry: Dictionary=entries.get(key(asset,base),{})
	if entry.is_empty(): misses+=1;return null
	# Source PNGs may be absent in exported games. In the editor, a changed
	# source must immediately bypass its old bake.
	var modified: int=FileAccess.get_modified_time(str(asset.texture)) if FileAccess.file_exists(str(asset.texture)) else 0
	if modified>0 and modified!=int(entry.source_modified): misses+=1;return null
	if not ResourceLoader.exists(str(entry.resource)): misses+=1;return null
	hits+=1
	var result := load(str(entry.resource)) as Texture2D
	# BC7 and ETC2 blocks are multiples of four. Keep the authored logical size even
	# when the encoded pixels are aligned; ImageTexture does not serialize
	# its size override. Assembly UVs and editor dimensions use this size.
	if result is ImageTexture and entry.has("size"):
		var logical := Vector2i(int(entry.size[0]),int(entry.size[1]))
		if Vector2i(result.get_size()) != logical: result.set_size_override(logical)
	return result

static func use_vram_compression(asset: Dictionary, base := false) -> bool:
	# World art only. Text, portraits, character frames and UI retain
	# their lossless pixels; manifests may explicitly opt out for fine detail.
	if base or asset.get("runtime_lossless",false): return false
	var path := str(asset.texture)
	return path.begins_with("res://art/architecture/") or path.begins_with("res://art/props/") or path.begins_with("res://art/environment/")

static func size_limit(asset: Dictionary, source_size: Vector2i) -> int:
	var explicit: int=int(asset.get("runtime_size_limit",0))
	var path: String=str(asset.texture)
	# Repeating ground has a separate budget from roof/assembly detail.
	# Authored limits are upper bounds, so these may safely use fewer pixels.
	if not path.begins_with("res://art/characters/") and (path.contains("floor") or path.contains("tiles") or path.contains("paver") or path.contains("lawn-tile") or path.contains("concrete-")):
		return mini(explicit,512) if explicit>0 else 512
	if explicit>0:return explicit
	# Cropped animation frames retain authored dimensions/anchors. 512px
	# remains ample for ~80px actors without changing their world geometry.
	if path.begins_with("res://art/characters/"):return 512
	# UI and world maps may contain text: keep their original resolution.
	if path.begins_with("res://art/ui/") or path.begins_with("res://art/items/"):return maxi(source_size.x,source_size.y)
	if asset.has("assembly_patches") or asset.has("grid_tile") or str(asset.get("render_mode","")).begins_with("architecture_"):return 1024
	var dimensions: Array=asset.get("render_size",asset.get("world_size",[]))
	if dimensions.size()==2 and maxf(float(dimensions[0]),float(dimensions[1]))>256:return 1024
	if path.contains("roof") or path.contains("floor") or path.contains("tiles") or path.contains("paver"):return 1024
	return 512
