extends SceneTree
const OUT := "res://docs/art/factory-terrain-v46/"
var checks := {}
func _initialize() -> void:call_deferred("run")
func check(label: String,value: bool) -> void:
	checks[label]=value
	if not value:print("FAIL: ",label)
func run() -> void:
	var doc=load("res://scripts/editor/map_document.gd").new()
	check("R04 native document opens",doc.open_file("res://data/rooms/r04.json"))
	var validation: Dictionary=doc.validate()
	check("native validation clean",validation.errors.is_empty() and validation.warnings.is_empty())
	var data: Dictionary=doc.data
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"baseline/r04.json"))
	for key in ["walls","architecture","fixtures","doors","access_gates","escape_routes","dormitories","confinement","routine_points","items","concept_plan"]:
		check(key+" unchanged",data.get(key)==before.get(key))
	check("floor coverage unchanged",data.floor_regions.size()==before.floor_regions.size() and range(data.floor_regions.size()).all(func(i):return data.floor_regions[i].rect==before.floor_regions[i].rect))
	check("all6 C materials",["common_floor_v46","workshop_floor_v46","warehouse_floor_v46","loading_floor_v46","laundry_floor_v46","grass_base_v46"].all(func(id):return data.floor_regions.any(func(r):return r.asset_id==id)))
	check("natural ground does not show editor grid",data.floor_regions[0].get("natural_ground",false))
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(data.terrain_manifest))
	var renderer=load("res://scripts/presentation/region_terrain.gd")
	for asset in manifest.assets:
		check(asset.id+" original bytes preserved",FileAccess.get_sha256(asset.texture)==asset.sha256)
		check(asset.id+" native texture loaded",renderer.texture(asset.id,data.terrain_manifest)!=null)
	check("all patch materials registered",data.terrain_patches.all(func(p):return manifest.assets.any(func(a):return a.id==p.asset_id)))
	check("painted vegetation stays upright",data.terrain_patches.all(func(p):return int(p.get("rotation_quarters",0))==0 and not p.get("mirror_x",false)))
	check("natural sprites preserve source proportions",data.terrain_patches.all(func(p):
		var asset: Dictionary=manifest.assets.filter(func(a):return a.id==p.asset_id)[0]
		return absf(float(p.rect[2])/float(p.rect[3])-float(asset.region[2])/float(asset.region[3]))<0.001))
	check("camera orientation guarded in material metadata",manifest.assets.filter(func(a):return a.texture.ends_with("organic_atlas.png")).all(func(a):return a.get("fixed_orientation",false) and a.get("preserve_aspect",false)))
	var alpha=Image.load_from_file("res://art/environment/factory_v46/organic_atlas.png")
	check("organic atlas transparent",alpha.get_pixel(0,0).a==0 and alpha.get_pixel(760,510).a==0)
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;game.set_process(false)
	game.load_room("r04",["lockpick","chat","backpack"],52)
	check("runtime uses C manifest",game.room_config.get("terrain_manifest","")==data.terrain_manifest)
	check("runtime terrain loaded",game.room_config.get("terrain_patches",[]).size()==data.terrain_patches.size())
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"passed":checks.size()-failed.size(),"failed":failed,"validation":validation},"  "))
	print(JSON.stringify({"passed":checks.size()-failed.size(),"failed":failed,"validation":validation}))
	game.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
