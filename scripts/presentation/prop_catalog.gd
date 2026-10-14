@tool
extends RefCounted

# Ordered override layers. Add a prop set here once for game and editor use.
const FILES := [
	"res://art/architecture/canteen_side_v3/manifest.json",
	"res://art/architecture/departure_gate_v1/manifest.json",
	"res://art/props/chess_room_v1/manifest.json",
	"res://art/architecture/kiosk_v2/manifest.json",
	"res://art/architecture/kiosk_v1/manifest.json",
	"res://art/architecture/tool_room_v1/manifest.json",
	"res://art/props/reading_room_v1/manifest.json",
	"res://art/props/workshop_one_v2/manifest.json",
	"res://art/architecture/workshop_one_v1/manifest.json",
	"res://art/props/workshop_one_v1/manifest.json",
	"res://art/architecture/cafeteria_v1/manifest.json",
	"res://art/architecture/cafeteria_v2/manifest.json",
	"res://art/props/bath_watercard_v1/manifest.json",
	"res://art/props/prison_v08/manifest.json",
	"res://art/props/cafeteria_v14/manifest.json",
	"res://art/props/manifest-v03.json",
	"res://art/props/prison_v17/manifest.json",
	"res://art/props/security_v19/manifest.json",
	"res://art/architecture/v23/manifest.json",
	"res://art/architecture/v24/manifest.json",
	"res://art/architecture/v25/manifest.json",
	"res://art/architecture/v26/manifest.json",
	"res://art/architecture/v27/manifest.json",
	"res://art/architecture/v28/manifest.json",
	"res://art/architecture/v29/manifest.json",
	"res://art/architecture/v30/manifest.json",
	"res://art/architecture/v31/manifest.json",
	"res://art/architecture/v32/manifest.json",
	"res://art/architecture/v33/manifest.json",
	"res://art/architecture/v34/manifest.json",
	"res://art/architecture/v36/manifest.json",
	"res://art/architecture/v37/manifest.json",
	"res://art/architecture/v38/manifest.json",
	"res://art/architecture/v53/manifest.json",
	"res://art/props/cafeteria_v41/manifest.json",
	"res://art/props/prison_v42/manifest.json",
	"res://art/props/factory_v43/manifest.json",
	"res://art/props/factory_v44/manifest.json",
	"res://art/props/campus_v47/manifest.json",
	"res://art/props/courtyard_v48/manifest.json",
	"res://art/props/bedside_v51/manifest.json",
	"res://art/props/southwest_v52/manifest.json",
	"res://art/props/exercise_yard_v54/manifest.json",
	"res://art/props/exercise_yard_v55/manifest.json",
	"res://art/props/clinic_restoration/manifest.json",
	"res://art/props/dorm_restoration/manifest.json",
	"res://art/props/duty_room_v1/manifest.json",
	"res://art/props/office_v1/manifest.json",
	"res://art/props/monitor_room_v1/manifest.json",
	"res://art/architecture/monitor_room_v1/manifest.json",
	"res://art/architecture/duty_room_v1/manifest.json",
	"res://art/architecture/clinic_v1/manifest.json",
	"res://art/architecture/bath_v1/manifest.json",
	"res://art/architecture/clinic_sliding_v2/manifest.json",
	"res://art/props/laundry_v1/manifest.json",
	"res://art/architecture/laundry_v1/manifest.json",
	"res://art/props/laundry_v2/manifest.json",
	"res://art/architecture/laundry_v2/manifest.json",
	"res://art/architecture/workshop_door_v2/manifest.json",
	"res://art/architecture/administration_doors_v2/manifest.json",
	"res://art/props/workshop_two_v1/manifest.json",
	"res://art/props/warehouse_v1/manifest.json",
	"res://art/props/loading_yard_v1/manifest.json",
	"res://art/props/south_laundry_bath_v1/manifest.json",
	"res://art/architecture/bath_pocket_v1/manifest.json",
	"res://art/architecture/laundry_repair_v3/manifest.json",
	"res://art/architecture/reading_chess_roofs_v1/manifest.json",
	"res://art/architecture/administration_roofs_v1/manifest.json",
	"res://art/props/drying_yard_v1/manifest.json",
	"res://art/props/pipe_energy_court_v1/manifest.json",
	"res://art/props/tree_courtyard_v1/manifest.json",
	"res://art/architecture/dorm_door_v1/manifest.json",
	"res://art/architecture/equipment_secure_v1/manifest.json",
	"res://art/props/equipment_pipes_v2/manifest.json",
	"res://art/props/valve_maintenance_v1/manifest.json",
	"res://art/props/energy_south_road_v2/manifest.json",
	"res://art/props/west_service_roads_v3/manifest.json",
	"res://art/props/workshop_roads_v4/manifest.json",
	"res://art/props/repair_courtyard_v1/manifest.json",
	"res://art/props/north_west_roads_v5/manifest.json",
]

static var cached_assets: Dictionary = {}
static var cached_signature: Array = []
static var next_catalog_check := 0

static func invalidate() -> void:
	cached_assets.clear()
	next_catalog_check=0

static func assets() -> Dictionary:
	var now: int=Time.get_ticks_msec()
	if not cached_assets.is_empty() and now<next_catalog_check:return cached_assets.duplicate(true)
	var signature: Array=[]
	for path in FILES+["res://art/props/legacy-aliases.json","res://data/presentation/prop_proportions.json"]:
		signature.append(FileAccess.get_modified_time(path))
	next_catalog_check=now+1000
	if not cached_assets.is_empty() and signature==cached_signature:return cached_assets.duplicate(true)
	cached_signature=signature
	preload("res://scripts/presentation/prop_proportions.gd").settings.clear()
	var result := {}
	for path in FILES:
		if not FileAccess.file_exists(path): continue
		var manifest := _read_manifest(path)
		for entry in manifest.get("assets",[]):
			var asset: Dictionary = entry.duplicate(true)
			if manifest.has("edge_shader") and not asset.has("alpha_core_shader"):
				asset.alpha_core_shader = manifest.edge_shader
			if path.contains("prison_v17") and str(asset.id)=="notice_board":
				asset.id = "prison_notice_board"
			result[str(asset.id)] = asset
	preload("res://scripts/presentation/prop_proportions.gd").apply(result)
	_apply_aliases(result)
	cached_assets=result.duplicate(true)
	return result

static func _read_manifest(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

static func _apply_aliases(result: Dictionary) -> void:
	# Old IDs still used by room JSONs are real dependencies, not dead art.
	var manifest := _read_manifest("res://art/props/legacy-aliases.json")
	for id in manifest.get("aliases",{}):
		var target: String = str(manifest.aliases[id])
		if not result.has(target):
			push_error("Missing replacement prop: "+target)
			continue
		var asset: Dictionary = result[target].duplicate(true)
		asset.id = str(id)
		asset.replacement_asset = target
		result[str(id)] = asset
