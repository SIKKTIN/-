@tool
extends RefCounted

signal changed
const ORDER := ["architecture","fixtures","ground","actors","patrol","items","routine","areas","visibility"]
const NAMES := {"architecture":"墙门 / 机关","fixtures":"场景摆设","ground":"地面 / 标记","actors":"人物 / NPC","patrol":"巡逻 / 搜查","items":"可拾取物品","routine":"日常活动点","areas":"区域 / 寝室","visibility":"房间可见范围"}
const GROUPS := {"architecture":["bounds","walls","door","dorm_doors","access_doors","crate","exit","escape_routes"],"fixtures":["fixtures"],"ground":["floor_regions","terrain_patches","ground_details"],"actors":["starts","guard_start","gate_guards","merchants","resident_staff"],"patrol":["patrol","guard_zone"],"items":["items"],"routine":["work","meal","dine","free"],"areas":["zones","dormitories","confinement"],"visibility":["visibility_rooms"]}
var visible: Dictionary = {}
var locked: Dictionary = {}

func _init() -> void:
	for key in ORDER:
		visible[key] = key not in ["patrol","routine","areas","visibility"]
		# Large paving regions are intentionally protected until the author
		# unlocks the ground layer; erasing a prop must not erase its whole floor.
		locked[key] = key == "ground"

func key_for(group: String) -> String:
	if group in ["floor_regions","terrain_patches","ground_details"]: return "ground"
	for key in ORDER:
		if group in GROUPS.get(key,[]): return key
	return "architecture"

func is_visible(group: String) -> bool:
	return visible.get(key_for(group),true)

func is_editable(group: String) -> bool:
	return is_visible(group) and not locked.get(key_for(group),false)

func set_visible(key: String, value: bool) -> void:
	visible[key] = value
	changed.emit()

func set_locked(key: String, value: bool) -> void:
	locked[key] = value
	changed.emit()

func preset(mode: String, solo_key := "") -> void:
	for key in ORDER:
		visible[key] = true if mode == "all" else key == solo_key if mode == "solo" else key not in ["patrol","routine","areas","visibility"]
	changed.emit()
