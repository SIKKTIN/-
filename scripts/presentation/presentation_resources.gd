@tool
extends RefCounted

# One profile policy and asset dependency traversal for loading and rendering.
# This module describes resources; WorldTexture owns their pixel lifetime.
const ACTIVE := "res://data/presentation/active.json"
const PROFILE_ROOT := "res://data/presentation/"
const PROFILE_IDS := ["v01", "v02", "v03"]
const Catalog = preload("res://scripts/presentation/prop_catalog.gd")
const Dependencies = preload("res://scripts/presentation/asset_dependencies.gd")
const Textures = preload("res://scripts/presentation/world_texture.gd")

static func read_dictionary(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path): return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

static func configuration() -> Dictionary:
	return resolve(read_dictionary(ACTIVE),OS.get_environment("ESCAPE_ART_PROFILE"))

static func resolve(active: Dictionary, override_id: String) -> Dictionary:
	var id := override_id
	if id not in PROFILE_IDS or not FileAccess.file_exists(PROFILE_ROOT+id+".json"):
		id = str(active.get("profile","v01"))
	return {"id":id,"active":active,"profile":read_dictionary(PROFILE_ROOT+id+".json")}

static func base_assets(profile: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for field in ["environment","props"]:
		for asset in read_dictionary(str(profile.get(field,""))).get("assets",[]):
			result.append(asset)
	return result

static func definitions(profile: Dictionary) -> Dictionary:
	return from_assets(base_assets(profile))

static func from_assets(assets: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for asset in assets: result[str(asset.id)] = asset
	# Ordered prop layers override legacy profile definitions, as in rendering.
	result.merge(Catalog.assets(),true)
	return result

static func texture_requests(config: Dictionary, profile: Dictionary) -> Array:
	var definitions: Dictionary = Catalog.assets()
	var requests: Dictionary = {}
	# Preserve the prewarm order: all base textures first, then map dependencies.
	for asset in base_assets(profile):
		definitions[str(asset.id)] = asset
		requests[Textures.RuntimeStore.key(asset)] = asset
	for id in Dependencies.ids(config,profile,definitions):
		var asset: Dictionary = definitions[id]
		requests[Textures.RuntimeStore.key(asset)] = asset
	_append_terrain(config,requests)
	return requests.values()

static func _append_terrain(config: Dictionary, requests: Dictionary) -> void:
	var manifests: Dictionary = {}
	for region in config.get("floor_regions",[])+config.get("terrain_patches",[]):
		var floor_path: String = str(region.get("manifest",config.get("terrain_manifest","res://art/environment/factory_v45/manifest.json")))
		for pair in [[region.get("asset_id",""),floor_path],[region.get("outline_asset_id",""),region.get("outline_manifest","")]]:
			var id := str(pair[0])
			var path := str(pair[1])
			if id.is_empty() or path.is_empty(): continue
			if not manifests.has(path): manifests[path] = read_dictionary(path)
			for asset in manifests[path].get("assets",[]):
				if str(asset.id)==id: requests[Textures.RuntimeStore.key(asset)] = asset
