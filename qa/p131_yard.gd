extends "res://qa/p105_collision.gd"

func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p131-yard.cfg")
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.reset_round(["chat","backpack","strong"],131)
	game.world.admission_filter=Callable()
	for actor in game.actors:actor.position=Vector2(2300+actor.actor_id*100,2700)
	var world=game.world
	world.update_dorm_doors(false,[])
	for gate in world.access_doors:world.set_access_closed(str(gate.id),false)
	world._changed(true)
	var actor=game.actors[0]
	var yard:=Rect2(120,3360,560,840)
	var r: Dictionary=game.room_config
	check("yard_ground_replaces_lawn",r.floor_regions.any(func(e):return str(e.id)=="southwest-maintenance-yard" and e.asset_id=="gravel_yard_v52" and Rect2(e.rect[0],e.rect[1],e.rect[2],e.rect[3])==yard))
	check("open_air_has_no_room_roof",not game.room_visibility.rooms.any(func(room):return room.area.intersects(yard)) and not world.is_under_roof(yard.get_center()))
	check("south_paving_excludes_yard",r.floor_regions.filter(func(e):return str(e.id) in ["south-life-loop","life-rear-walk"]).all(func(e):return e.rect[0]>=700))
	check("preserves_seven_day_map",world.bounds==Rect2(0,0,6000,4500) and r.demo_single_map and game.schedule.day_seconds==900)
	var document=load("res://scripts/editor/map_document.gd").new()
	check("editor_opens_native_map",document.open_file("res://data/rooms/r04.json"))
	var validation: Dictionary=document.validate()
	check("map_validation",validation.errors.is_empty())
	if not validation.errors.is_empty():print(validation.errors)
	var catalog=load("res://scripts/editor/editor_catalog.gd").new()
	var new_assets: Array=JSON.parse_string(FileAccess.get_file_as_string("res://art/props/southwest_v52/manifest.json")).assets
	check("nine_new_props_registered",new_assets.size()==9)
	for spec in new_assets:
		check("editor_"+str(spec.id),catalog.entries.any(func(e):return e.id==spec.id and not str(e.icon).is_empty()) and game.presentation.asset_definitions.has(str(spec.id)) and world.art_textures.get(str(spec.id))!=null)
	var debris: Array=world.fixtures.filter(func(f):return str(f.id).begins_with("southwest-debris-"))
	check("debris_inside_enclosure",debris.size()==10 and debris.all(func(f):return yard.encloses(f.rect)))
	check("small_rubble_walkable",debris.filter(func(f):return str(f.asset_id).begins_with("rubble_")).all(func(f):return not f.blocks_movement))
	check("scrap_piles_block_feet",debris.filter(func(f):return str(f.asset_id).begins_with("scrap_")).all(func(f):return f.blocks_movement and not world.can_place_circle(f.rect.get_center(),8,actor,false,false)))
	var booth: Dictionary=world.fixtures.filter(func(f):return str(f.id)=="southwest-corner-booth")[0]
	check("corner_booth_blocks",booth.blocks_sight and not world.can_place_circle(booth.rect.get_center(),8,actor,false,false))
	actor.position=Vector2(610,3500)
	world.move_actor(actor,Vector2(160,0))
	check("east_wall_stops_feet",actor.position.x<675)
	actor.position=Vector2(510,3380)
	world.move_actor(actor,Vector2(0,-100))
	check("north_wall_stops_feet",actor.position.y>=3360)
	actor.position=Vector2(510,4160)
	world.move_actor(actor,Vector2(0,100))
	check("south_wall_stops_feet",actor.position.y<4200)
	check("no_environment_entrance_fixture",not world.fixtures.any(func(f):return str(f.id)=="southwest-yard-entry"))
	check("no_environment_portal",not world.door_passage.portals.any(func(port):return port.rect.intersects(Rect2(680,3740,20,200))))
	for start in [Vector2(750,3800),Vector2(750,3870),Vector2(750,3930)]:
		actor.position=start
		world.move_actor(actor,Vector2(-200,0))
		check("former_entry_stops_"+str(start),actor.position.x>=708)
	for target in [Vector2(400,3500),Vector2(610,3870),Vector2(610,3970)]:
		check("player_cannot_path_into_scenery_"+str(target),world.find_path(Vector2(750,3870),target,actor,false,true).is_empty())
		check("npc_cannot_path_into_scenery_"+str(target),world.find_path(Vector2(750,3870),target,game.actors[1],false,true).is_empty())
	check("scenery_has_no_search_targets",not game.looting.containers.values().any(func(c):return yard.has_point(c.fixture.rect.get_center())))
	check("corridor_to_laundry",travel(actor,Vector2(750,4000),Vector2(750,3400)) and travel(actor,Vector2(750,3400),Vector2(900,3440)))
	check("corridor_to_service_route",travel(actor,Vector2(750,3870),Vector2(1500,4070)))
	var solids_before: int=world.static_solids.size()
	var layer=game.presentation.scene_layers.filter(func(l):return l.kind=="ground_static")[0]
	await frame()
	var builds: int=layer.static_ground.builds
	for i in range(10):
		game.room_visibility.tick(0,true)
		game.presentation.tick(0)
		await frame()
	check("static_decor_not_rebuilt_each_frame",layer.static_ground.builds==builds and world.static_solids.size()==solids_before)
	var failed: Array=checks.keys().filter(func(key):return not checks[key])
	FileAccess.open("res://docs/tests/p131-yard.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	quit(0 if failed.is_empty() else 1)
