@tool
extends RefCounted

const Document = preload("res://scripts/editor/map_document.gd")
const WorldTexture = preload("res://scripts/presentation/world_texture.gd")
const CATEGORIES := ["furniture","cafeteria","props","actors","items","rules","areas"]
const CATEGORY_NAMES := {"furniture":"家具 / 设施","cafeteria":"食堂设施","props":"杂物摆设","actors":"人物 / NPC","items":"可拾取物品","rules":"规则 / 日常点","areas":"区域 / 寝室门"}
const SUBCATEGORY_NAMES := {"all":"全部类型", "furnishings":"家具摆设", "tiles_h":"建筑瓦片 · 横墙", "tiles_v":"建筑瓦片 · 纵墙", "tiles_corner":"建筑瓦片 · 转角", "tiles_junction":"建筑瓦片 · T形连接", "tiles_end":"建筑瓦片 · 端面", "tiles_frame":"建筑瓦片 · 门柱 / 门楣", "tiles_coping":"建筑瓦片 · 压顶", "buildings":"完整建筑", "doors":"门窗 / 门禁", "attachments":"墙面设施", "serving":"取餐 / 回收", "tableware":"餐盘", "barriers":"排队围栏", "misc":"杂物", "staff":"人物", "loot":"物品", "routes":"巡逻路线", "activities":"日常活动", "regions":"区域", "dorms":"寝室门"}
const SUBCATEGORY_ORDER := ["furnishings","tiles_h","tiles_v","tiles_corner","tiles_junction","tiles_end","tiles_frame","tiles_coping","buildings","doors","attachments","serving","tableware","barriers","misc","staff","loot","routes","activities","regions","dorms"]
# One authoring set; old definitions remain available to existing map references.
const BUILDING_NAMES := {"cafeteria_t_v29": "石墙 · T形连接24", "cafeteria_t_20_v29": "石墙 · T形连接20", "cafeteria_wall_mid_v24": "石墙 · 横墙", "cafeteria_wing_left_v24": "石墙 · 左门翼", "cafeteria_wing_right_v24": "石墙 · 右门翼", "cafeteria_wall_v_l_v27": "石墙 · 左纵墙24", "cafeteria_wall_v_r_v27": "石墙 · 右纵墙24", "cafeteria_wall_v_l_20_v27": "石墙 · 左纵墙20", "cafeteria_wall_v_r_20_v27": "石墙 · 右纵墙20", "cafeteria_turn_l_v28": "石墙 · 左转角24", "cafeteria_turn_r_v28": "石墙 · 右转角24", "cafeteria_turn_l_20_v28": "石墙 · 左转角20", "cafeteria_turn_r_20_v28": "石墙 · 右转角20", "cafeteria_end_v27": "石墙 · 端面24", "cafeteria_end_20_v27": "石墙 · 端面20", "cafeteria_jamb_left_v24": "石墙 · 左门柱", "cafeteria_jamb_right_v24": "石墙 · 右门柱", "cafeteria_lintel_v24": "石墙 · 门楣", "solitary_shell_closed_v24": "禁闭室 · 门关闭", "solitary_shell_open_v24": "禁闭室 · 门打开"}
var entries: Array[Dictionary] = []
var assets: Dictionary = {}
var tool_icons: Dictionary = {}
var texture_cache: Dictionary = {}
var paired_icons := 0

func _init() -> void:
	var paired: Dictionary = {}
	for file in ["res://art/editor/v01/manifest.json","res://art/editor/v02/manifest.json","res://art/editor/v03/manifest.json","res://art/editor/v04/manifest.json","res://art/editor/v05/manifest.json","res://art/editor/v06/manifest.json","res://art/editor/v07/manifest.json","res://art/editor/v08/manifest.json","res://art/editor/v09/manifest.json"]:
		if not FileAccess.file_exists(file): continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(file))
		if not parsed is Dictionary: continue
		for item in parsed.get("assets",[]): paired[str(item.id)] = item
		for item in parsed.get("tools",[]): tool_icons[str(item.id)] = str(item.get("icon",""))
	assets = load("res://scripts/presentation/prop_catalog.gd").assets()
	for id in assets:
		if not is_placeable(str(id)): continue
		var category := "cafeteria" if str(id).begins_with("cafeteria_") else "furniture"
		var entry: Dictionary = paired.get(id,{})
		var subcategory := asset_subcategory(str(id),assets[id])
		if subcategory in ["tiles_h","tiles_v","tiles_corner","tiles_junction","tiles_end","tiles_frame","tiles_coping","buildings","doors","attachments"]: category = "furniture"
		else: category = str(entry.get("category",category))
		entries.append({"id":id,"name":str(BUILDING_NAMES.get(id,entry.get("name",Document.ASSET_NAMES.get(id,id)))),"category":category,"subcategory":subcategory,"group":"fixtures","asset_id":id,"icon":str(entry.get("editor_icon",""))})
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
		entries.append({"id":id,"name":definition[1],"category":definition[2],"subcategory": "routes" if group == "patrol" else "activities" if definition[2] == "rules" else "dorms" if group == "dorm_doors" else "regions" if definition[2] == "areas" else "loot" if definition[2] == "items" else "staff","group":group,"definition_id":id if group == "items" else "","icon":tool_icons.get(id,tool_icons.get(group,""))})

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

func asset_subcategory(id: String, definition: Dictionary) -> String:
	var mode := str(definition.get("render_mode",""))
	if mode == "architecture_junction_t": return "tiles_junction"
	if mode == "architecture_corner_l": return "tiles_corner"
	if mode == "architecture_tiled_top": return "tiles_v"
	if mode == "architecture_end_face": return "tiles_end"
	if mode in ["architecture_jamb","architecture_lintel"] or id.contains("jamb") or id.contains("lintel") or id.contains("corner_post"): return "tiles_frame"
	if mode == "architecture_coping": return "tiles_coping"
	if mode in ["architecture_shell","architecture_shell_overlay","architecture_portal_reference"]: return "buildings"
	if mode.begins_with("architecture_"): return "tiles_h"
	if mode == "embedded_door" or id.contains("door") or id.contains("gate") or id in ["access_reader","cell_bars"]: return "doors"
	if mode == "wall_attachment": return "attachments"
	if id in ["cafeteria_counter","cafeteria_return"]: return "serving"
	if id == "cafeteria_tray": return "tableware"
	if id == "cafeteria_queue": return "barriers"
	return "misc" if id.begins_with("heavy_crate") else "furnishings"

func subcategories(category: String) -> Array[String]:
	var result: Array[String] = ["all"]
	for id in SUBCATEGORY_ORDER:
		if entries.any(func(e): return e.category == category and e.subcategory == id): result.append(id)
	return result

func filtered_entries(category: String, subcategory: String, query := "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var term := query.strip_edges().to_lower()
	for entry in entries:
		if entry.category != category or (subcategory != "all" and entry.subcategory != subcategory): continue
		if not term.is_empty() and not (str(entry.name)+" "+str(entry.id)).to_lower().contains(term): continue
		result.append(entry)
	if subcategory.begins_with("tiles_"):
		result.sort_custom(func(a,b): return BUILDING_NAMES.keys().find(a.id) < BUILDING_NAMES.keys().find(b.id))
	return result

func is_placeable(id: String) -> bool:
	var mode := str(assets.get(id,{}).get("render_mode",""))
	if mode == "architecture_material": return false
	if mode.begins_with("architecture_"): return BUILDING_NAMES.has(id)
	return assets.has(id)

func display_name(id: String) -> String:
	if BUILDING_NAMES.has(id): return BUILDING_NAMES[id]
	for entry in entries:
		if entry.id == id: return str(entry.name)
	return str(assets.get(id,{}).get("name",Document.ASSET_NAMES.get(id,id)))

func appearance_ids(current_id: String) -> Array[String]:
	var result: Array[String] = []
	for entry in entries:
		if entry.group == "fixtures": result.append(str(entry.id))
	# An old draft must keep its current ID without offering other retired assets.
	if not result.has(current_id): result.append(current_id)
	return result
