extends "res://qa/p139_yard_art.gd"

const PREFIX = "exercise-yard-v55-"

func run():
	output_dir="res://docs/art/exercise-yard-v02/"
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://yard-v55-qa.cfg")
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.fullscreen_ui.fps_badge.hide()
	game.reset_round(["chat","backpack","strong"],155)
	game.world.admission_filter=Callable()
	game.orders.clear()
	game.schedule.set_time_speed(0)
	var config: Dictionary=game.room_config
	var world=game.world
	var main=game.actors[0]
	for actor in game.actors:actor.position=Vector2(4000+actor.actor_id*60,2600)
	for gate in world.access_doors:world.set_access_closed(gate.id,false)
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(output_dir+"last-input-map.json"))
	for key in before:
		if key not in ["fixtures","ground_details","terrain_patches","floor_regions","zones","routine_points","lamps","concept_plan"]:
			check("preserve_"+key,JSON.stringify(before[key])==JSON.stringify(config[key]))
	var old_yard=func(f):return str(f.get("id","")).begins_with("exercise-yard-v54-") or str(f.get("id","")).begins_with(PREFIX) or str(f.get("id","")).begins_with("campus-yard-seat-") or str(f.get("id","")).begins_with("campus-yard-planter-") or f.get("id","") in ["campus-yard-hoop","campus-yard-lamp-0"]
	check("unrelated_fixtures_preserved",JSON.stringify(before.fixtures.filter(func(f):return not old_yard.call(f)))==JSON.stringify(config.fixtures.filter(func(f):return not old_yard.call(f))))
	var yard: Array=config.concept_plan.exercise_yard_revision.yard_rect
	check("compact_yard_rectangle",Rect2(yard[0],yard[1],yard[2],yard[3])==Rect2(2140,220,1120,600))
	check("six_benches",world.fixtures.filter(func(f):return str(f.id).begins_with(PREFIX+"bench-")).size()==6)
	check("three_potted_trees",world.fixtures.filter(func(f):return str(f.id).begins_with(PREFIX+"tree-")).size()==3)
	check("local_floor_manifest",config.floor_regions.any(func(f):return f.id=="campus-yard" and f.asset_id=="yard_concrete_a_v55"))
	check("west_paved_passage",travel(main,Vector2(2100,400),Vector2(2100,780)))
	check("east_passage_both_directions",travel(main,Vector2(3190,470),Vector2(3330,470)) and travel(main,Vector2(3330,470),Vector2(3190,470)))
	check("south_passage_both_directions",travel(main,Vector2(2700,770),Vector2(2700,900)) and travel(main,Vector2(2700,900),Vector2(2700,770)))
	check("west_low_curb_blocks",not world.can_place_circle(Vector2(2148,500),8,main,false,false))
	var bars=world.fixtures.filter(func(f):return f.id==PREFIX+"bars")[0]
	check("three_bar_post_colliders",world.fixture_collision_rects(bars).size()==3)
	check("walk_between_bar_posts",world.can_place_circle(bars.rect.position+Vector2(60,6),8,main,false,false))
	check("shelter_underpass_walkable",travel(main,Vector2(3070,390),Vector2(3070,430)))
	for point in [Vector2(2460,620),Vector2(2860,655)]:
		check("npc_point_"+str(point),world.can_place_circle(point,8,main,false,false) and travel(main,Vector2(2750,680),point))
	check("yard_to_workshop_route",travel(main,Vector2(2750,680),Vector2(2780,1410)))
	var document=preload("res://scripts/editor/map_document.gd").new()
	document.open_file("res://data/rooms/r04.json")
	check("map_validation",document.validate().errors.is_empty())
	var catalog=preload("res://scripts/editor/editor_catalog.gd").new()
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/props/exercise_yard_v55/manifest.json"))
	for asset in manifest.assets:
		var entries: Array=catalog.entries.filter(func(e):return e.id==asset.id)
		check(asset.id+"_editor_icon",entries.size()==1 and catalog.icon(entries[0])!=null)
		check(asset.id+"_original_png",FileAccess.get_sha256(asset.texture)==asset.sha256)
		var texture: Texture2D=world.art_textures.get(asset.id)
		check(asset.id+"_runtime_cap",texture!=null and maxf(texture.get_width(),texture.get_height())<=512)
		check(asset.id+"_mipmaps",texture!=null and texture.get_image().has_mipmaps())
	var added=document.add("fixtures",Vector2(2700,680),"yard_curb_corner_sw_v55")
	check("editor_placement_keeps_l_shape",document.value(added).solid_parts.size()==2)
	document.undo()
	check("editor_undo_restores_map",not document.dirty())
	main.position=Vector2(3070,430)
	game.presentation.tick(0)
	check("shelter_roof_fades",game.presentation.canopy_volumes.any(func(v):return is_equal_approx(v.modulate.a,.32)))
	main.position=Vector2(2750,680)
	game.presentation.tick(0)
	check("shelter_roof_restores",game.presentation.canopy_volumes.all(func(v):return is_equal_approx(v.modulate.a,1.0)))
	var static_ground=game.presentation.scene_layers.filter(func(l):return l.kind=="ground_static")[0].static_ground
	var builds=static_ground.builds
	for i in range(30):game.presentation.tick(1.0/60)
	check("ground_not_rebuilt_per_frame",static_ground.builds==builds)
	if DisplayServer.get_name()!="headless":
		await photo("game-yard-overview",Vector2(2700,520),.85,false)
		await photo("game-west-curb",Vector2(2200,735),1.7,false)
		await photo("game-yard-shelter",Vector2(3030,405),1.4,false)
	var failed=checks.keys().filter(func(k):return not checks[k])
	write_report(output_dir+("headless" if DisplayServer.get_name()=="headless" else "native")+"-checks.json",{"checks":checks,"failed":failed,"passed":checks.size()-failed.size()})
	quit(0 if failed.is_empty() else 1)
