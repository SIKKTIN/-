@tool
extends RefCounted

const LIBRARY_PATH := "res://data/items/library.json"
const ART_PATH := "res://data/presentation/inventory-assets-v07.json"
const LOOT_PATH := "res://data/items/loot_tables.json"
const CATEGORY_NAMES := {"food":"食物", "medical":"医疗", "social":"社交礼物", "material":"制作材料", "tool":"工具", "equipment":"装备", "document":"证件与情报", "misc":"其他"}
var definitions: Dictionary = {}
var art: Dictionary = {}
var loot: Dictionary = {}
var textures: Dictionary = {}

func _init() -> void: reload()

func reload() -> void:
	definitions.clear()
	textures.clear()
	for spec in JSON.parse_string(FileAccess.get_file_as_string(LIBRARY_PATH)).items: definitions[str(spec.id)] = spec
	art = JSON.parse_string(FileAccess.get_file_as_string(ART_PATH)).get("items",{})
	loot = JSON.parse_string(FileAccess.get_file_as_string(LOOT_PATH)).get("profiles",{})

static func texture_from(spec: Dictionary) -> Texture2D:
	var path := str(spec.get("texture",""))
	if path.is_empty(): return null
	var original: Texture2D
	if ResourceLoader.exists(path): original = load(path)
	else:
		if not FileAccess.file_exists(path): return null
		var pixels := Image.load_from_file(path)
		if pixels == null or pixels.is_empty(): return null
		original = ImageTexture.create_from_image(pixels)
	if not spec.has("region") and not spec.get("trim_transparent",false): return original
	var region := Rect2i(Vector2i.ZERO,Vector2i(original.get_size()))
	if spec.has("region"):
		var values: Array = spec.region
		region = Rect2i(values[0],values[1],values[2],values[3])
	if spec.get("trim_transparent",false):
		var used := original.get_image().get_region(region).get_used_rect()
		region = Rect2i(region.position+used.position,used.size)
	var result := AtlasTexture.new()
	result.atlas = original
	result.region = Rect2(region)
	result.filter_clip = true
	return result

func icon(id: String) -> Texture2D:
	if not textures.has(id): textures[id] = texture_from(art.get(id,{}))
	return textures[id]

func sources(id: String) -> Array[String]:
	var result: Array[String] = []
	for source in definitions.get(id,{}).get("acquisition_sources",[]):result.append(str(source))
	for profile in loot.values():
		if id in profile.get("items",[]) or id in profile.get("guaranteed",[]): result.append(str(profile.label))
	return result

func category(id: String) -> String:
	return str(definitions.get(id,{}).get("category","misc"))

func status(id: String) -> String:
	var spec: Dictionary = definitions.get(id,{})
	return str(spec.get("implementation_status","可搜刮 / 可使用" if spec.has("use_action") else "可搜刮 / 可携带"))
