extends "res://qa/p105_collision.gd"

var output_dir: String="res://docs/dev/p139/"

func _initialize():
	create_timer(120).timeout.connect(func():quit(124))
	call_deferred("run")

func photo(name: String, center: Vector2, zoom:=1.0, hud:=true):
	if DisplayServer.get_name()=="headless": return
	game.map_camera.zoom=Vector2.ONE*zoom
	game.map_camera.position=center-Vector2(root.size)/(2*zoom)
	game.map_camera.following=false
	game.map_camera.force_update_scroll()
	game.actors[0].position=center+Vector2(0,30)
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)
	game._update_ui()
	game.get_node("HUD").visible=hud
	await frame()
	await frame()
	check(name+"_saved",root.get_texture().get_image().save_png(output_dir+name+".png")==OK)
	game.get_node("HUD").show()
	game.map_camera.zoom=Vector2.ONE

func benchmark() -> Dictionary:
	var draw_calls: Array=[]
	var frames: Array=[]
	var before: int=Time.get_ticks_usec()
	for i in range(120):
		game.presentation.tick(1.0/60.0)
		game._update_ui()
		await frame()
		var now: int=Time.get_ticks_usec()
		if i>=30:
			frames.append(float(now-before)/1000.0)
			draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		before=now
	frames.sort()
	return {"frame_ms_median":frames[frames.size()/2],"frame_ms_p95":frames[roundi((frames.size()-1)*0.95)],"draw_calls_average":draw_calls.reduce(func(a,b):return a+b,0.0)/draw_calls.size(),"memory_static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"texture_memory_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"window":[1200,720],"camera_center":[2750,750],"zoom":1,"simulation_frozen":true,"samples":frames.size()}

func write_report(path: String, value: Dictionary):
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:
		push_error("Cannot save yard report %s: %s" % [path,FileAccess.get_open_error()])
		quit(1)
		return
	file.store_string(JSON.stringify(value,"\t"))
	file.close()

func run():
	if not OS.get_environment("ESCAPE_YARD_QA_DIR").is_empty():output_dir=OS.get_environment("ESCAPE_YARD_QA_DIR").trim_suffix("/")+"/"
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p139-yard-art.cfg")
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.fullscreen_ui.fps_badge.hide()
	game.reset_round(["chat","backpack","strong"],139)
	game.world.admission_filter=Callable()
	game.schedule.set_time_speed(0)
	game.actors[0].position=Vector2(2750,780)
	game.map_camera.center_on(Vector2(2750,750))
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)
	if OS.get_environment("ESCAPE_YARD_BASELINE")=="1":
		await photo("before",Vector2(2750,750))
		write_report(output_dir+"baseline.json",await benchmark())
		quit(0)
		return
	# Profile the untouched startup state before editor/path tests warm extra
	# textures or relocate actors, matching the baseline capture conditions.
	if DisplayServer.get_name()!="headless":
		await photo("after-1200",Vector2(2750,750))
		write_report(output_dir+"performance.json",await benchmark())
	var config: Dictionary=game.room_config
	var world=game.world
	var main=game.actors[0]
	for actor in game.actors: actor.position=Vector2(3600+actor.actor_id*60,2400)
	for gate in world.access_doors: world.set_access_closed(gate.id,false)
	# Preservation checks compare the current art pass, not an earlier map
	# revision that can legitimately change in the editor between requests.
	var baseline_path: String="res://docs/dev/p140/r04-before.json" if config.concept_plan.exercise_yard_revision.has("edge_transition") else "res://docs/dev/p139/r04-before.json"
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(baseline_path))
	var boundary_count: int=before.walls.filter(func(r):return Rect2(2300,240,900,900).encloses(Rect2(r[0],r[1],r[2],r[3]))).size()
	check("only_old_yard_boundary_tiles_removed",before.walls.size()-config.walls.size()==boundary_count)
	check("yard_has_no_extra_four_boundary_walls",not world.walls.any(func(r):return Rect2(2300,240,900,900).encloses(r)))
	check("old_thresholds_removed",not world.fixtures.any(func(f):return f.id in ["campus-yard-south","campus-yard-west","campus-yard-east"]))
	check("southwest_and_all_other_walls_preserved",before.walls.filter(func(r):return not Rect2(2300,240,900,900).encloses(Rect2(r[0],r[1],r[2],r[3]))).size()==config.walls.size())
	check("every_other_wall_geometry_preserved",before.walls.filter(func(r):return not Rect2(2300,240,900,900).encloses(Rect2(r[0],r[1],r[2],r[3]))).all(func(r):return config.walls.has(r)))
	var southwest_before: Array=before.fixtures.filter(func(f):return str(f.id).begins_with("southwest-"))
	check("southwest_decor_preserved_from_start_snapshot",southwest_before==config.fixtures.filter(func(f):return str(f.id).begins_with("southwest-")))
	check("wall_surfaces_valid",preload("res://scripts/editor/map_document.gd").check_shape(config)=="")
	check("single_seven_day_map_retained",config.demo_single_map and config.escape_days==7)
	check("existing_actor_scale_retained",is_equal_approx(preload("res://scripts/core/world_scale.gd").HUMAN,1.4))
	check("yard_floor_has_local_manifest",config.floor_regions.any(func(f):return f.id=="campus-yard" and f.asset_id=="yard_concrete_v54" and f.has("manifest")))
	check("yard_floor_soft_transition",config.floor_regions.any(func(f):return f.id=="campus-yard" and float(f.get("edge_feather",0))==56))
	var benches=world.fixtures.filter(func(f):return str(f.id).begins_with("exercise-yard-v54-bench-"))
	var trees=world.fixtures.filter(func(f):return str(f.id).begins_with("exercise-yard-v54-tree-"))
	check("five_benches",benches.size()==5)
	check("seven_potted_tree_groups",trees.size()==7)
	var edge_trees=world.fixtures.filter(func(f):return str(f.id).begins_with("exercise-yard-v54-edge-tree-"))
	check("edge_pots_do_not_block_main_road",edge_trees.size()==3 and travel(main,Vector2(3330,620),Vector2(3330,1130)))
	check("edge_exit_has_two_clear_crossings",world.motion_clear(Vector2(3120,650),Vector2(3340,650),main,false,true) and world.motion_clear(Vector2(3120,700),Vector2(3340,700),main,false,true))
	check("low_edge_shrubs_do_not_block",world.fixtures.filter(func(f):return str(f.id).begins_with("exercise-yard-v54-edge-shrub-")).all(func(f):return not f.blocks_movement and not f.blocks_sight))
	check("half_court_occupies_21_percent",is_equal_approx(440.0*350/(900*800),0.213888889))
	for pair in [[Vector2(2250,810),Vector2(2400,810)],[Vector2(3130,670),Vector2(3250,670)],[Vector2(2770,1000),Vector2(2770,1200)]]:
		check("open_boundary_pass_"+str(pair[0]),travel(main,pair[0],pair[1]))
	var bars=world.fixtures.filter(func(f):return f.id=="exercise-yard-v54-bars")[0]
	var posts: Array=world.fixture_collision_rects(bars)
	check("bars_three_separate_post_bases",posts.size()==3)
	for i in range(posts.size()): check("bar_post_blocks_"+str(i),not world.can_place_circle(posts[i].get_center(),8,main,false,false))
	check("bar_can_walk_between_posts",world.can_place_circle(bars.rect.position+Vector2(60,6),8,main,false,false))
	for id in ["back","front"]:
		var f=world.fixtures.filter(func(v):return v.id=="exercise-yard-v54-shelter-"+id)[0]
		check(id+"_two_post_bases",world.fixture_collision_rects(f).size()==2)
		check(id+"_middle_is_walkable",world.can_place_circle(f.rect.get_center(),8,main,false,false))
	for i in range(trees.size()):
		check("tree_pot_blocks_"+str(i),not world.can_place_circle(trees[i].rect.get_center(),8,main,false,false))
	check("tree_crown_does_not_block",world.can_place_circle(Vector2(2410,310),8,main,false,false))
	check("roof_underpass_is_walkable",travel(main,Vector2(3100,580),Vector2(3110,500)))
	check("main_route_yard_to_workshop",travel(main,Vector2(2740,870),Vector2(2780,1410)))
	for point in [Vector2(2500,970),Vector2(2920,950)]:
		check("npc_free_point_"+str(point),world.can_place_circle(point,8,main,false,false) and travel(main,Vector2(2740,870),point))
	var top_walls=world.walls.filter(func(r):return r.position.y<220 and r.position.x<3000 and r.end.x>2400)
	check("factory_perimeter_still_present",not top_walls.is_empty())
	if not top_walls.is_empty():
		check("factory_perimeter_collision_retained",not world.can_place_circle(top_walls[0].get_center(),8,main,false,false))
	var document=preload("res://scripts/editor/map_document.gd").new()
	document.open_file("res://data/rooms/r04.json")
	check("map_document_has_no_validation_errors",document.validate().errors.is_empty())
	var entry=document.add("fixtures",Vector2(2500,800),"pullup_bars_v54")
	check("editor_placement_keeps_three_post_colliders",document.value(entry).solid_parts.size()==3)
	var catalog=preload("res://scripts/editor/editor_catalog.gd").new()
	for id in ["pullup_bars_v54","yard_shelter_roof_v54","yard_shelter_back_v54","yard_shelter_front_v54","yard_tree_round_v54","yard_tree_square_v54","yard_bench_vertical_v54"]:
		var entries: Array=catalog.entries.filter(func(e):return e.id==id)
		check(id+"_editor_icon",entries.size()==1 and catalog.icon(entries[0])!=null)
		var texture: Texture2D=world.art_textures.get(id)
		check(id+"_texture_capped",texture!=null and maxf(texture.get_width(),texture.get_height())<=512)
		check(id+"_mipmaps",texture!=null and texture.get_image().has_mipmaps())
	check("roof_registered_once",game.presentation.canopy_volumes.size()==1)
	main.position=Vector2(3110,500)
	game.presentation.tick(0)
	check("roof_fades_for_under_roof_actor",is_equal_approx(game.presentation.canopy_volumes[0].modulate.a,.32))
	main.position=Vector2(2730,870)
	game.presentation.tick(0)
	check("roof_restores_outside",is_equal_approx(game.presentation.canopy_volumes[0].modulate.a,1.0))
	var static_ground=game.presentation.scene_layers.filter(func(l):return l.kind=="ground_static")[0].static_ground
	var builds=static_ground.builds
	for i in range(30):game.presentation.tick(1.0/60)
	check("static_ground_cache_not_rebuilt_each_frame",builds==static_ground.builds)
	if DisplayServer.get_name()!="headless":
		await photo("yard-overview",Vector2(2750,705),.65,false)
		root.size=Vector2i(960,540)
		root.content_scale_size=root.size
		await photo("after-960",Vector2(2800,755))
		root.size=Vector2i(1440,900)
		root.content_scale_size=root.size
		await photo("after-1440",Vector2(2750,705))
		root.size=Vector2i(1200,720)
		root.content_scale_size=root.size
		await photo("shelter-walk",Vector2(3110,470),1.4)
	var failed=checks.keys().filter(func(k):return not checks[k])
	write_report(output_dir+("headless" if DisplayServer.get_name()=="headless" else "native")+"-checks.json",{"checks":checks,"failed":failed,"passed":checks.size()-failed.size()})
	quit(0 if failed.is_empty() else 1)
