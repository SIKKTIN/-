extends SceneTree
const OUT := "res://docs/art/factory-detail-v44/"
var checks := {}
var game
func _initialize() -> void: call_deferred("run")
func check(label: String, value: bool) -> void:
	checks[label] = value
	if not value: print("FAIL: "+label)
func clock(minute: float) -> void:
	game.schedule.clock_elapsed = (minute-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.room_access.tick()
func run() -> void:
	var doc = load("res://scripts/editor/map_document.gd").new()
	check("R04 opens",doc.open_file("res://data/rooms/r04.json"))
	var validation: Dictionary = doc.validate()
	check("R04 validates without warnings",validation.errors.is_empty() and validation.warnings.is_empty())
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT+"baseline/r04.json"))
	check("4000x3000 bounds",Vector2(doc.data.bounds[2],doc.data.bounds[3])==Vector2(4000,3000))
	check("old daily fixtures preserved",old.fixtures.all(func(f):return doc.data.fixtures.any(func(g):return f==g)))
	for key in ["starts","dormitories","dorm_doors","routine_points","workshop","confinement","cafeteria","merchants"]:
		check("daily core preserved: "+key,doc.data[key]==old[key])
	var assets: Dictionary = load("res://scripts/presentation/prop_catalog.gd").assets()
	var catalog = load("res://scripts/editor/editor_catalog.gd").new()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/props/factory_v44/manifest.json"))
	for a in manifest.assets:
		check(a.id+" original bytes unchanged",FileAccess.get_sha256(a.texture)==a.sha256)
		check(a.id+" palette entry and native icon",catalog.entries.any(func(e):return e.id==a.id and e.icon==a.editor_icon) and load(a.editor_icon)!=null)
	check("all fixture assets exist",doc.data.fixtures.all(func(f):return assets.has(f.asset_id)))
	check("wall tile geometry preserved",old.walls==doc.data.walls and old.architecture==doc.data.architecture)
	check("ground dressing retained in document",doc.data.get("ground_details",[]).size()>90)
	check("three independent editable exits",doc.entries().filter(func(r):return r.group=="escape_routes").size()==3)
	game = load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.set_process(false);game.load_room("r04",["lockpick","chat","backpack"],52)
	game.routine_panel.close();game.schedule.set_time_speed(0)
	game.orders.clear()
	for actor in game.actors: actor.immune_until=INF
	var world = game.world
	check("expanded routes prohibit legacy east boundary escape",not world.inside_room(Vector2(4100,150)))
	var actor = game.actors[0]
	clock(730)
	var daily := Vector2(2070,1100)
	for name in ["warehouse","loading","laundry"]:
		var coords: Array = doc.data.expansion.review_points[name]
		var point := Vector2(coords[0],coords[1])
		check(name+" connected from everyday hall",not world.find_path(daily,point,null,false).is_empty())
	check("warehouse-to-yard loop",not world.find_path(Vector2(2800,1100),Vector2(3700,1580),null,false).is_empty())
	check("cafeteria rear connects laundry",not world.find_path(Vector2(1240,2080),Vector2(980,2570),null,false).is_empty())
	check("equipment locked before preparation",world.find_path(daily,Vector2(1850,2610),null,false).is_empty())
	check("rear service inaccessible before latch",world.find_path(daily,Vector2(2600,2880),null,false).is_empty())
	for item in doc.data.items:
		if item.definition_id not in ["lock_tool","door_key"]:continue
		var point := Vector2(item.position[0],item.position[1])
		check("warehouse pickup accessible: "+str(point),world.can_place_circle(point,17,null,false) and not world.find_path(daily,point,null,false).is_empty())
	check("rack blocks sight",not world.line_clear(Vector2(2600,540),Vector2(2800,540)))
	actor.position=Vector2(1790,2370)
	check("maintenance door targets local lock",game.skills.door_id(actor)=="maintenance-entry" and game.skills.door_reason(actor).is_empty())
	var key: String = game.inventory.add_ground("door_key",actor.position)
	check("pickup preparation key",game.inventory.try_pickup(0,key).ok)
	check("key opens maintenance entry",game.inventory.try_use(0,key).ok and not world.access_by_id("maintenance-entry").closed)
	check("equipment accessible after preparation",not world.find_path(daily,Vector2(1850,2610),null,false).is_empty())
	check("outside cannot operate inside latch",not game.room_access.open_latch(0,"service-side"))
	actor.position=Vector2(2110,2730)
	game.presentation.interaction.refresh()
	check("inside latch appears in interaction",game.presentation.interaction.targets.any(func(t):return t.kind=="latch" and t.id=="service-side"))
	check("inside latch opens linked service gates",game.room_access.open_latch(0,"service-side") and ["service-side","service-barrier","rear-exit"].all(func(id):return not world.access_by_id(id).closed))
	check("laundry-service loop after latch",not world.find_path(Vector2(980,2570),Vector2(2600,2880),null,false).is_empty())
	check("equipment-to-rear exit connected",not world.find_path(actor.position,world.escape_routes[2].rect.get_center(),null,false).is_empty())
	actor.position=world.escape_routes[2].rect.get_center()
	check("rear route completes escape",world.check_exit(actor))
	actor.escaped=false;actor.position=Vector2(3700,1580)
	clock(959)
	check("logistics closed before16",world.access_by_id("loading-exit").closed)
	actor.position=Vector2(3890,150)
	check("logistics cannot escape before16",not world.check_exit(actor))
	actor.position=Vector2(3700,1580);clock(960)
	check("logistics opens at16",not world.access_by_id("loading-exit").closed)
	check("loading gate reachable during window",not world.find_path(actor.position,Vector2(3890,150),actor,false).is_empty())
	actor.position=Vector2(3890,150)
	check("logistics route completes escape",world.check_exit(actor))
	actor.escaped=false;clock(1020)
	check("logistics deadline enforced even while clearing gate",not world.check_exit(actor))
	actor.position=Vector2(3700,1580);game.room_access.tick()
	check("loading gate closes after evacuation",world.access_by_id("loading-exit").closed)
	clock(1200);world.open_door();world.set_gate_guarded(false)
	actor.position=daily
	check("main exit connected through old checkpoint",not world.find_path(actor.position,world.exit_area.get_center(),null,false).is_empty())
	actor.position=world.exit_area.get_center()
	check("main route completes escape",world.check_exit(actor))
	actor.escaped=false
	actor.position=Vector2(320,280)
	check("regional guards do not block primary gate",game.gate_watch.guards.filter(func(g):return not g.blocks_primary).size()==2)
	# New map keeps the same identities and physical staff movement to the northern exit.
	clock(720)
	var overseer=game.workshop.overseer
	var max_step:=0.0
	for i in range(600):
		var before: Vector2=overseer.position
		game.staff_traffic.tick_guard(overseer,0.05)
		max_step=maxf(max_step,before.distance_to(overseer.position))
		game.staff_traffic.update_gate()
	var record: Dictionary=game.staff_traffic.records[overseer.get_instance_id()]
	check("staff walks out through northern exit",record.status=="offsite" and not overseer.visible)
	check("staff physical step remains bounded",max_step<=10.76)
	clock(780)
	for i in range(600):game.staff_traffic.tick_guard(overseer,0.05)
	check("staff returns through workshop and main gate",record.status=="duty" and overseer.position.distance_to(record.home)<2 and overseer.visible)
	world.reset_world()
	check("reset restores all preparation gates",["maintenance-entry","service-side","service-barrier","rear-exit"].all(func(id):return world.access_by_id(id).closed))
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	var report: Dictionary={"checks":checks,"passed":checks.size()-failed.size(),"failed":failed,"validation":validation}
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify({"passed":report.passed,"failed":failed}))
	game.queue_free();await process_frame
	quit(0 if failed.is_empty() else 1)
