@tool
extends RefCounted

const Terrain = preload("res://scripts/presentation/region_terrain.gd")
static var thumbnails: Dictionary = {}
const MATERIALS := [
	["grass_base_v46","外围草地","res://art/environment/factory_v46/manifest.json",930,true],
	["earth_v45","砂土地面","res://art/environment/factory_v45/manifest.json",640,true],
	["common_floor_v46","生活区灰绿方砖","res://art/environment/factory_v46/manifest.json",320,false],
	["loading_floor_v46","室外水泥方砖","res://art/environment/factory_v46/manifest.json",320,false],
	["workshop_floor_v46","旧车间水泥地","res://art/environment/factory_v46/manifest.json",320,false],
	["warehouse_floor_v46","仓库深灰地砖","res://art/environment/factory_v46/manifest.json",384,false],
	["workshop_tiles_v1","车间灰绿小方砖","res://art/environment/workshop_one_v1/manifest.json",160,false],
	["clinic_tiles_a","医务室浅色瓷砖","res://art/environment/clinic_restoration/manifest.json",160,false],
	["clinic_tiles_b","医务室磨损瓷砖","res://art/environment/clinic_restoration/manifest.json",160,false],
	["duty_tiles_v1","值班室方砖","res://art/environment/duty_room_v1/manifest.json",160,false],
	["monitor_tiles_v1","监控室方砖","res://art/environment/monitor_room_v1/manifest.json",160,false],
	["laundry_tiles_v1","洗衣房地砖","res://art/environment/laundry_v1/manifest.json",250,false],
	["bath_dry_tiles","浴室干区瓷砖","res://art/architecture/bath_v1/manifest.json",160,false],
	["bath_wet_tiles","浴室湿区瓷砖","res://art/architecture/bath_v1/manifest.json",160,false],
	["cafeteria_floor_v1","食堂地砖","res://art/architecture/cafeteria_v2/manifest.json",240,false],
	["toolroom_floor_v1","工具房水泥地","res://art/architecture/tool_room_v1/manifest.json",240,false],
	["chess_tiles_v1","棋牌室方砖","res://art/props/chess_room_v1/manifest.json",240,false],
	["yard_concrete_a_v55","放风院水泥地","res://art/environment/exercise_yard_v55/manifest.json",640,false],
	["yard_concrete_b_v55","放风院磨损水泥地","res://art/environment/exercise_yard_v55/manifest.json",640,false],
	["loading_floor_v1","装卸场方砖","res://art/environment/loading_yard_v1/manifest.json",320,false],
	["energy_concrete_v1","能源庭院旧混凝土","res://art/environment/pipe_energy_court_v1/manifest.json",240,false],
	["equipment_secure_floor_v1","机密设备室深灰工业地面","res://art/architecture/equipment_secure_v1/manifest.json",240,false],
	["tree_court_lawn_v1","自强树庭橄榄草皮","res://art/environment/tree_courtyard_v1/manifest.json",500,true],
	["tree_court_pavers_v1","自强树庭小石砖","res://art/environment/tree_courtyard_v1/manifest.json",240,false]
]

static func key(spec: Dictionary) -> String: return str(spec.asset_id)+"@"+str(spec.manifest)
static func materials(config := {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen := {}
	for values in MATERIALS:
		var spec := {"asset_id":values[0],"name":values[1],"manifest":values[2],"tile_size":[values[3],values[3]],"natural_ground":values[4]}
		spec.id = key(spec)
		result.append(spec)
		seen[spec.id] = true
	# Custom and old maps keep their source manifest instead of silently
	# switching to a texture that happens to have the same asset ID.
	for region in config.get("floor_regions",[]):
		var spec: Dictionary = region.duplicate(true)
		spec.manifest = str(region.get("manifest",config.get("terrain_manifest","res://art/environment/factory_v45/manifest.json")))
		spec.id = key(spec)
		if seen.has(spec.id): continue
		spec.name = "已有材质 · "+str(spec.asset_id)
		spec.tile_size = region.get("tile_size",[640,640]).duplicate()
		result.append(spec)
		seen[spec.id] = true
	return result

static func texture(spec: Dictionary) -> Texture2D: return Terrain.texture(str(spec.asset_id),str(spec.manifest))

# Dropdowns measure item icons, including items that are not selected.
# Keep their real texture dimensions small rather than relying on a paint-
# only theme override that can still leave a large minimum control width.
static func thumbnail(spec: Dictionary) -> Texture2D:
	var id := key(spec)
	if thumbnails.has(id): return thumbnails[id]
	var source := texture(spec)
	if source == null: return null
	var pixels := source.get_image()
	if pixels == null or pixels.is_empty(): return null
	var factor := 24.0/maxi(pixels.get_width(),pixels.get_height())
	pixels.resize(maxi(1,roundi(pixels.get_width()*factor)),maxi(1,roundi(pixels.get_height()*factor)),Image.INTERPOLATE_BILINEAR)
	var result := ImageTexture.create_from_image(pixels)
	thumbnails[id] = result
	return result
