@tool
extends RefCounted

const Document = preload("res://scripts/editor/map_document.gd")
const WorldTexture = preload("res://scripts/presentation/world_texture.gd")
const CATEGORIES := ["furniture","cafeteria","props","actors","items","rules","areas"]
const CATEGORY_NAMES := {"furniture":"家具 / 设施","cafeteria":"食堂设施","props":"杂物摆设","actors":"人物 / NPC","items":"可拾取物品","rules":"规则 / 日常点","areas":"区域 / 寝室门"}
var entries: Array[Dictionary] = []
var assets: Dictionary = {}
var tool_icons: Dictionary = {}
var texture_cache: Dictionary = {}
var paired_icons := 0

func _init() -> void:
	var paired: Dictionary = {}
	for file in ["res://art/editor/v01/manifest.json","res://art/editor/v02/manifest.json","res://art/editor/v03/manifest.json","res://art/editor/v04/manifest.json","res://art/editor/v05/manifest.json","res://art/editor/v06/manifest.json","res://art/editor/v07/manifest.json","res://art/editor/v08/manifest.json"]:
		if not FileAccess.file_exists(file): continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(file))
		if not parsed is Dictionary: continue
		for item in parsed.get("assets",[]): paired[str(item.id)] = item
		for item in parsed.get("tools",[]): tool_icons[str(item.id)] = str(item.get("icon",""))
	assets = load("res://scripts/presentation/prop_catalog.gd").assets()
	for id in assets:
		if assets[id].get("render_mode","") == "architecture_material": continue
		var category := "cafeteria" if str(id).begins_with("cafeteria_") else "furniture"
		var entry: Dictionary = paired.get(id,{})
		entries.append({"id":id,"name":str(entry.get("name",Document.ASSET_NAMES.get(id,id))),"category":str(entry.get("category",category)),"group":"fixtures","asset_id":id,"icon":str(entry.get("editor_icon",""))})
		if not str(entry.get("editor_icon","")).is_empty(): paired_icons += 1
	var definitions := [
		["gate_guards","门岗混混","actors","gate_guards"],
		["merchants","商人","actors","merchants"],
		["scrap","旧零件","items","items"],
		["door_key","钥匙","items","items"],
		["lock_tool","撬锁工具","items","items"],
		["patrol","巡逻点","rules","patrol"],
		["work","工作点","rules","work"],
		["meal","取餐点","rules","meal"],
		["dine","用餐点","rules","dine"],
		["free","活动点","rules","free"],
		["zones","区域范围","areas","zones"],
		["dorm_doors","寝室门","areas","dorm_doors"]]
	for definition in definitions:
		var id: String = definition[0]
		var group: String = definition[3]
		entries.append({"id":id,"name":definition[1],"category":definition[2],"group":group,"definition_id":id if group == "items" else "","icon":tool_icons.get(id,tool_icons.get(group,""))})

func icon(entry: Dictionary) -> Texture2D:
	var id: String = str(entry.id)
	if texture_cache.has(id): return texture_cache[id]
	var texture: Texture2D
	var path: String = entry.get("icon","")
	if path != "" and ResourceLoader.exists(path): texture = load(path)
	if texture == null and assets.has(id): texture = WorldTexture.load_asset(assets[id])
	if texture == null:
		var fallback := "res://art/ui/fullscreen/locate.svg"
		match str(entry.get("group",id)):
			"items": fallback = "res://art/ui/inventory_pickup_v07.svg"
			"gate_guards": fallback = "res://art/ui/skill_chat_v01.svg"
			"merchants": fallback = "res://art/ui/inventory_trade_v07.svg"
			"work": fallback = "res://art/ui/skill_strong_v01.svg"
			"dorm_doors": fallback = "res://art/ui/skill_lockpick_v01.svg"
		texture = load(fallback)
	texture_cache[id] = texture
	return texture
