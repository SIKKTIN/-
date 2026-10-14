@tool
extends RefCounted

const Document = preload("res://scripts/editor/map_document.gd")
const WorldTexture = preload("res://scripts/presentation/world_texture.gd")
const CATEGORIES := ["furniture","cafeteria","floors","props","actors","items","rules","areas"]
const CATEGORY_NAMES := {"furniture":"家具 / 设施","cafeteria":"食堂设施","floors":"地板 / 地面","props":"杂物摆设","actors":"人物 / NPC","items":"可拾取物品","rules":"规则 / 日常点","areas":"区域 / 寝室门"}
const SUBCATEGORY_NAMES := {"all":"全部类型", "furnishings":"家具摆设", "tiles_h":"建筑瓦片 · 横墙", "tiles_v":"建筑瓦片 · 纵墙", "tiles_corner":"建筑瓦片 · L型 / 圆弧转角", "tiles_junction":"建筑瓦片 · T形连接", "tiles_end":"建筑瓦片 · 端面", "tiles_frame":"建筑瓦片 · 门柱 / 门楣", "tiles_coping":"建筑瓦片 · 压顶", "buildings":"完整建筑", "doors":"门窗 / 门禁", "attachments":"墙面设施", "serving":"取餐 / 回收", "tableware":"餐盘", "barriers":"排队围栏", "misc":"杂物", "staff":"人物", "loot":"物品", "routes":"巡逻路线", "activities":"日常活动", "regions":"区域", "dorms":"寝室门"}
const SUBCATEGORY_ORDER := ["furnishings","tiles_h","tiles_v","tiles_corner","tiles_junction","tiles_end","tiles_frame","tiles_coping","buildings","doors","attachments","serving","tableware","barriers","misc","staff","loot","routes","activities","regions","dorms"]
# One authoring set; old definitions remain available to existing map references.
const BUILDING_NAMES := {"wall_grid_h": "横墙 · 2×6格", "wall_grid_t": "T接口 · 3×6格", "wall_grid_l_left": "左转角 · 2×6格", "wall_grid_l_right": "右转角 · 2×6格", "wall_grid_v": "纵墙 · 1×6格", "wall_grid_end": "端面 · 1×5格", "wall_grid_jamb": "门柱 · 1×6格", "wall_grid_lintel": "门楣 · 4×1格", "solitary_shell_closed_v24": "禁闭室 · 门关闭", "solitary_shell_open_v24": "禁闭室 · 门打开"}
const CURRENT_EDITOR_MANIFEST := "res://art/editor/v16/manifest.json"
const RETIRED_PROP_IDS := ["cafeteria_counter_front_v40","cafeteria_backline_v40","cafeteria_return","cafeteria_tray","workbench","tool_locker","laundry_cart","wash_basin","bunk_bed","toilet_sink","communal_table"]
var entries: Array[Dictionary] = []
var assets: Dictionary = {}
var tool_icons: Dictionary = {}
var texture_cache: Dictionary = {}
var paired_icons := 0
var item_catalog = preload("res://scripts/items/item_catalog.gd").new()

func _init() -> void:
	var paired: Dictionary = {}
	for file in ["res://art/editor/v01/manifest.json","res://art/editor/v02/manifest.json","res://art/editor/v03/manifest.json","res://art/editor/v04/manifest.json","res://art/editor/v05/manifest.json","res://art/editor/v06/manifest.json","res://art/editor/v07/manifest.json","res://art/editor/v08/manifest.json","res://art/editor/v09/manifest.json","res://art/editor/v10/manifest.json","res://art/editor/v11/manifest.json","res://art/editor/v12/manifest.json","res://art/editor/v13/manifest.json","res://art/editor/v15/manifest.json",CURRENT_EDITOR_MANIFEST,"res://art/editor/v17/manifest.json","res://art/editor/v19/manifest.json","res://art/editor/v20/manifest.json","res://art/editor/v21/manifest.json","res://art/editor/v22/manifest.json","res://art/editor/v24/manifest.json","res://art/editor/v25/manifest.json"]:
		if not FileAccess.file_exists(file): continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(file))
		if not parsed is Dictionary: continue
		for item in parsed.get("assets",[]): paired[str(item.id)] = item
		for item in parsed.get("tools",[]): tool_icons[str(item.id)] = str(item.get("icon",""))
	assets = load("res://scripts/presentation/prop_catalog.gd").assets()
	tool_icons["eraser"] = "res://art/ui/editor_eraser.svg"
	for id in assets:
		if not is_placeable(str(id)): continue
		var category := "cafeteria" if str(id).begins_with("cafeteria_") else "furniture"
		var entry: Dictionary = paired.get(id,{})
		var subcategory := asset_subcategory(str(id),assets[id])
		if subcategory in ["tiles_h","tiles_v","tiles_corner","tiles_junction","tiles_end","tiles_frame","tiles_coping","buildings","doors","attachments"]: category = "furniture"
		else: category = str(entry.get("category",category))
		entries.append({"id":id,"name":str(BUILDING_NAMES.get(id,entry.get("name",Document.ASSET_NAMES.get(id,assets[id].get("name",id))))),"category":category,"subcategory":subcategory,"group":"walls" if assets[id].has("grid_tile") else "fixtures","asset_id":id,"icon":str(entry.get("editor_icon",""))})
		if not str(entry.get("editor_icon","")).is_empty(): paired_icons += 1
	var definitions := [
		["gate_guards","门岗混混","actors","gate_guards"],
		["merchants","商人","actors","merchants"],
		["resident_staff","常驻人员岗位","actors","resident_staff"],
		["scrap","旧零件","items","items"],
		["door_key","钥匙","items","items"],
		["lock_tool","撬锁工具","items","items"],
		["patrol","巡逻点","rules","patrol"],
		["work","工作点","rules","work"],
		["meal","取餐点","rules","meal"],
		["dine","用餐点","rules","dine"],
		["free","活动点","rules","free"],
		["zones","区域范围","areas","zones"],
		["visibility_rooms","房间可见范围","areas","visibility_rooms"],
		["dorm_doors","寝室门","areas","dorm_doors"]]
	for definition in definitions:
		if definition[2] == "items": continue
		var id: String = definition[0]
		var group: String = definition[3]
		entries.append({"id":id,"name":definition[1],"category":definition[2],"subcategory": "routes" if group == "patrol" else "activities" if definition[2] == "rules" else "dorms" if group == "dorm_doors" else "regions" if definition[2] == "areas" else "loot" if definition[2] == "items" else "staff","group":group,"definition_id":id if group == "items" else "","icon":tool_icons.get(id,tool_icons.get(group,""))})
	for id in item_catalog.definitions:
		entries.append({"id":id,"name":str(item_catalog.definitions[id].name),"category":"items","subcategory":"loot","group":"items","definition_id":id,"icon":""})
	for spec in preload("res://scripts/editor/floor_catalog.gd").materials():
		entries.append({"id":spec.id,"name":spec.name,"category":"floors","subcategory":"all","group":"floor_regions","asset_id":spec.asset_id,"floor_spec":spec,"icon":""})

func icon(entry: Dictionary) -> Texture2D:
	if entry.get("group","") == "floor_regions": return preload("res://scripts/editor/floor_catalog.gd").texture(entry.floor_spec)
	var id: String = str(entry.id)
	if texture_cache.has(id): return texture_cache[id]
	var texture: Texture2D
	if entry.get("group","") == "items": texture = item_catalog.icon(id)
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
	if definition.has("editor_subcategory"): return str(definition.editor_subcategory)
	if mode == "architecture_junction_t": return "tiles_junction"
	if mode in ["architecture_corner_l","architecture_junction_l"]: return "tiles_corner"
	if mode == "architecture_tiled_top": return "tiles_v"
	if mode in ["architecture_end_face","architecture_endface"]: return "tiles_end"
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
		result.sort_custom(func(a,b): return str(a.id) < str(b.id))
	return result

func is_placeable(id: String) -> bool:
	if assets.get(id,{}).get("editor_hidden",false): return false
	if id in RETIRED_PROP_IDS: return false
	if id in ["cafeteria_counter","cafeteria_gate_closed_v23","cafeteria_gate_open_v23"]: return false
	if assets.get(id,{}).has("grid_tile"): return assets[id].get("authoring_set","") in ["equipment-secure-v1","chess-room-v1","tool-room-v1","universal-v36","universal-v37","universal-v38","universal-v53","clinic-v1","bath-v1","cafeteria-v1","cafeteria-v2","duty-room-v1","monitor-room-v1","laundry-v1","laundry-repair-v3","workshop-one-v1"]
	var mode := str(assets.get(id,{}).get("render_mode",""))
	if mode == "architecture_material": return false
	if assets.get(id,{}).get("editor_placeable",false): return true
	if mode.begins_with("architecture_"): return BUILDING_NAMES.has(id)
	return assets.has(id)

func display_name(id: String) -> String:
	if BUILDING_NAMES.has(id): return BUILDING_NAMES[id]
	for entry in entries:
		if entry.id == id: return str(entry.name)
	return str(assets.get(id,{}).get("name",Document.ASSET_NAMES.get(id,id)))

func compatible_wall_ids(current_id: String) -> Array[String]:
	var result: Array[String] = []
	var current: Dictionary = assets.get(current_id,{})
	for entry in entries:
		if entry.group != "walls": continue
		var definition: Dictionary = assets[entry.id]
		if definition.get("connection_tag","")==current.get("connection_tag","legacy") and definition.render_size==current.get("render_size",[]): result.append(str(entry.id))
	result.sort()
	if not result.has(current_id): result.append(current_id)
	return result

func stable_variant(id: String, map_id: String, point: Vector2) -> String:
	var family: String = str(assets.get(id,{}).get("variant_family",""))
	if family == "": return id
	var pool: Array[String] = []
	for entry in entries:
		if str(assets.get(entry.id,{}).get("variant_family","")) != family: continue
		pool.append(str(entry.id))
		if family == "horizontal" and str(entry.id).right(1) in ["a","b","c"]:
			pool.append(str(entry.id));pool.append(str(entry.id))
	pool.sort()
	if pool.is_empty(): return id
	var seed_text := "%s/%s/%d/%d" % [map_id,family,roundi(point.x/20),roundi(point.y/20)]
	var value := ("0x"+seed_text.sha256_text().left(8)).hex_to_int()
	return pool[int(value%pool.size())]

func appearance_ids(current_id: String) -> Array[String]:
	var result: Array[String] = []
	for entry in entries:
		if entry.group == "fixtures": result.append(str(entry.id))
	# An old draft must keep its current ID without offering other retired assets.
	if not result.has(current_id): result.append(current_id)
	return result
