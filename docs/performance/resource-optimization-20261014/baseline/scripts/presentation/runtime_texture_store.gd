@tool
extends RefCounted

# Generated resources keep original artwork/coordinates intact. A stale or
# absent bake falls back to the source loader, including new editor assets.
const INDEX := "res://art/runtime_textures/index.json"
static var entries: Dictionary = {}
static var checked := false
static var hits := 0
static var misses := 0

static func key(asset: Dictionary, base := false) -> String:
	var region: Array=[]
	for value in asset.get("region",[]): region.append(int(value))
	return str(asset.texture)+JSON.stringify(region)+( "::limit"+str(int(asset.runtime_size_limit)) if int(asset.get("runtime_size_limit",0))>0 else "")+("::base" if base else "")

static func texture(asset: Dictionary, base := false) -> Texture2D:
	if OS.get_environment("ESCAPE_SOURCE_TEXTURES")=="1": return null
	if not checked:
		checked=true
		if FileAccess.file_exists(INDEX):
			var data=JSON.parse_string(FileAccess.get_file_as_string(INDEX))
			if data is Dictionary: entries=data.get("textures",{})
	var entry: Dictionary=entries.get(key(asset,base),{})
	if entry.is_empty(): misses+=1;return null
	# Source PNGs may be absent in exported games. In the editor, a changed
	# source must immediately bypass its old bake.
	var modified: int=FileAccess.get_modified_time(str(asset.texture)) if FileAccess.file_exists(str(asset.texture)) else 0
	if modified>0 and modified!=int(entry.source_modified): misses+=1;return null
	if not ResourceLoader.exists(str(entry.resource)): misses+=1;return null
	hits+=1
	return load(str(entry.resource)) as Texture2D

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
