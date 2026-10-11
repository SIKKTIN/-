extends SceneTree
const OUT := "res://docs/art/factory-terrain-v45/"
var checks := {}
var game
func _initialize() -> void:call_deferred("run")
func check(label: String,value: bool) -> void:
	checks[label]=value
	if not value:print("FAIL: ",label)
func clock(minute: float) -> void:
	game.schedule.clock_elapsed=(minute-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.tick(false);game.room_access.tick()
func run() -> void:
	var doc=load("res://scripts/editor/map_document.gd").new()
	check("R04 native document opens",doc.open_file("res://data/rooms/r04.json"))
	var validation: Dictionary=doc.validate()
	check("native validation has no errors or warnings",validation.errors.is_empty() and validation.warnings.is_empty())
	print(JSON.stringify(validation))
	var data: Dictionary=doc.data
	var assets: Dictionary=load("res://scripts/presentation/prop_catalog.gd").assets()
	check("all furniture references resolve",data.fixtures.all(func(f):return assets.has(f.asset_id)))
	check("all wall references resolve",data.architecture.wall_surfaces.all(func(s):return assets.has(s.grid_tile_asset)))
	check("architecture keeps 20 unit components",data.walls.all(func(r):return r.all(func(v):return is_zero_approx(fmod(float(v),20)))))
	var step: Array=data.concept_plan.west_perimeter_step
	check("wall segments include concept west perimeter dogleg",step.size()==4 and Vector2(step[0][0],step[0][1])==Vector2(100,2240) and Vector2(step[1][0],step[1][1])==Vector2(600,2240) and Vector2(step[2][0],step[2][1])==Vector2(600,2700) and Vector2(step[3][0],step[3][1])==Vector2(3800,2700))
	check("garden is enclosed below warehouse",data.concept_plan.horizontal.any(func(s):return s.id=="garden-south" and s.y==2240) and data.concept_plan.vertical.any(func(s):return s.id=="garden-east"))
	check("warehouse has two east openings",data.concept_plan.vertical.filter(func(s):return s.id=="warehouse-yard-divider")[0].gaps.size()==2)
	check("no invented south warehouse gate",data.concept_plan.horizontal.filter(func(s):return s.id=="warehouse-south")[0].gaps.is_empty())
	check("all six materials represented",["common_floor_v45","workshop_floor_v45","warehouse_floor_v45","loading_floor_v45","laundry_floor_v45","earth_v45"].all(func(id):return data.floor_regions.any(func(r):return r.asset_id==id)))
	check("free terrain ignores tile snapping",data.terrain_patches.any(func(p):return p.rect.any(func(v):return not is_zero_approx(fmod(float(v),20)))))
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/environment/factory_v45/manifest.json"))
	for a in manifest.assets:
		check(a.id+" original bytes preserved",FileAccess.get_sha256(a.texture)==a.sha256)
		check(a.id+" native texture resolves",load("res://scripts/presentation/region_terrain.gd").texture(str(a.id))!=null)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.set_process(false);game.load_room("r04",["lockpick","chat","backpack"],52)
	game.routine_panel.close();game.schedule.set_time_speed(0);game.orders.clear()
	for actor in game.actors:actor.immune_until=INF
	var world=game.world;var player=game.actors[0]
	clock(730)
	var daily:=Vector2(1500,1300)
	for pair in [["warehouse",Vector2(2850,1200)],["loading",Vector2(3750,1600)],["laundry",Vector2(1150,2300)]]:
		check(str(pair[0])+" reachable from daily hall",not world.find_path(daily,pair[1],null,false).is_empty())
	for item in data.items:
		var p:=Vector2(item.position[0],item.position[1])
		check("pickup reachable "+str(p),world.can_place_circle(p,17,null,false) and not world.find_path(daily,p,null,false).is_empty())
	for key in ["work","meal","dine","free"]:
		for i in range(data.routine_points[key].size()):
			var p: Array=data.routine_points[key][i]
			check("daily landing "+key+str(i),world.can_place_circle(Vector2(p[0],p[1]),17,null,false))
	check("equipment needs preparation",world.find_path(daily,Vector2(2420,2240),null,false).is_empty())
	player.position=Vector2(2100,1945)
	game.room_visibility.tick(0,true)
	check("maintenance interaction reachable",world.can_place_circle(player.position,17,null,false) and game.skills.door_id(player)=="maintenance-entry")
	var key: String=game.inventory.add_ground("door_key",player.position)
	check("preparation key picked up",game.inventory.try_pickup(0,key).ok)
	check("key opens paired equipment doors",game.inventory.try_use(0,key).ok and not world.access_by_id("maintenance-entry").closed and not world.access_by_id("laundry-equipment").closed)
	check("equipment reachable after preparation",not world.find_path(daily,Vector2(2420,2240),null,false).is_empty())
	player.position=Vector2(2470,2400)
	check("inside latch landing clear",world.can_place_circle(player.position,17,null,false))
	check("inside latch opens rear route",game.room_access.open_latch(0,"service-side") and not world.access_by_id("rear-exit").closed and not world.access_by_id("service-barrier").closed)
	check("rear escape connected",not world.find_path(player.position,world.escape_routes[2].rect.get_center(),null,false).is_empty())
	player.position=world.escape_routes[2].rect.get_center();check("rear route completes escape",world.check_exit(player));player.escaped=false
	player.position=Vector2(3750,1600);clock(959)
	check("logistics closed before window",world.access_by_id("loading-exit").closed)
	clock(960)
	check("logistics opens at16",not world.access_by_id("loading-exit").closed)
	check("logistics path reaches exit",not world.find_path(player.position,world.escape_routes[1].rect.get_center(),player,false).is_empty())
	player.position=world.escape_routes[1].rect.get_center();check("logistics escape succeeds",world.check_exit(player));player.escaped=false
	clock(1020);check("logistics deadline maintained",not world.check_exit(player))
	player.position=daily;clock(730)
	world.reset_world();world.set_gate_guarded(false)
	check("closed north gate cannot be bypassed",world.find_path(daily,world.exit_area.get_center(),null,false).is_empty())
	world.open_door();world.set_gate_guarded(false)
	check("opened north gate connected",not world.find_path(daily,world.exit_area.get_center(),null,false).is_empty())
	player.position=world.exit_area.get_center();check("main exit succeeds",world.check_exit(player));player.escaped=false
	# Real staff walk through the relocated horizontal main gate and back.
	player.position=Vector2(data.starts[0][0],data.starts[0][1]);clock(720)
	var officer=game.workshop.overseer
	for i in range(900):game.staff_traffic.tick_guard(officer,0.05)
	var record: Dictionary=game.staff_traffic.records[officer.get_instance_id()]
	check("staff leave through north checkpoint",record.status=="offsite" and not officer.visible)
	clock(780)
	for i in range(900):game.staff_traffic.tick_guard(officer,0.05)
	check("staff return to workshop",record.status=="duty" and officer.position.distance_to(record.home)<2)
	world.set_access_closed("workshop-entry",true)
	check("two workshop doors share labor gate",world.access_by_id("workshop-entry-east").closed)
	world.reset_world()
	check("reset restores preparation locks",["maintenance-entry","laundry-equipment","service-side","rear-exit"].all(func(id):return world.access_by_id(id).closed))
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"passed":checks.size()-failed.size(),"failed":failed,"validation":validation},"  "))
	print(JSON.stringify({"passed":checks.size()-failed.size(),"failed":failed}))
	game.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
