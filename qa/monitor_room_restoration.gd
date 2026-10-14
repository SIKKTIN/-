extends "res://qa/p105_collision.gd"

const OUT="res://docs/art/monitor-room-v01/"
func check(label: String, passed: bool):checks[label]=passed
func _initialize():
	create_timer(150).timeout.connect(func():quit(124))
	call_deferred("run")
func capture(label: String, center: Vector2, zoom: float):
	if DisplayServer.get_name()=="headless":return
	game.map_camera.zoom=Vector2.ONE*zoom
	game.map_camera.position=center-Vector2(root.size)/(2*zoom)
	game.map_camera.following=false
	game.map_camera.force_update_scroll()
	game.room_visibility.tick(0,true)
	game.resident_staff.tick(0)
	game.presentation.tick(0)
	await frame()
	await frame()
	var shot=root.get_texture().get_image()
	check(label+" saved",shot.save_png(OUT+label+".png")==OK)
	if label=="runtime-interior":
		var sample=Vector2(root.size)/2+(Vector2(4805,962)-center)*zoom
		var blue: Color=shot.get_pixelv(Vector2i(sample))
		check("bounded wall texture samples blue wainscot",blue.b>blue.r+.02)
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://monitor-room-qa.cfg")
	root.size=Vector2i(1280,900);root.content_scale_size=root.size
	var disk:=FileAccess.get_file_as_string("res://data/rooms/r04.json")
	var map: Dictionary=JSON.parse_string(disk)
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"last-input-map.json"))
	var registration: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"map-registration.json"))
	for key in before:
		if key not in ["walls","architecture","fixtures","zones","visibility_rooms","floor_regions","concept_plan","resident_staff","access_doors"]:
			check("preserve map "+key,JSON.stringify(before[key])==JSON.stringify(map[key]))
	for group in ["zones","visibility_rooms"]:
		check("preserve other "+group,JSON.stringify(before[group].filter(func(v):return v.id!="monitor"))==JSON.stringify(map[group].filter(func(v):return v.id!="monitor")))
	check("preserve other doors",JSON.stringify(before.access_doors.filter(func(v):return v.id!="monitor-entry"))==JSON.stringify(map.access_doors.filter(func(v):return v.id!="monitor-entry")))
	var own=func(f):return f.get("monitor_generated",false) or f.id in ["campus-admin-desk-2","campus-admin-board-2","campus-admin-cabinet-2","campus-monitor-entry-visual"]
	check("preserve other fixtures",JSON.stringify(before.fixtures.filter(func(f):return not own.call(f)))==JSON.stringify(map.fixtures.filter(func(f):return not own.call(f))))
	check("preserve other floors",JSON.stringify(before.floor_regions.filter(func(f):return f.id!="campus-monitor"))==JSON.stringify(map.floor_regions.filter(func(f):return f.id!="campus-monitor")))
	check("preserve existing staff",JSON.stringify(before.resident_staff.filter(func(f):return f.id!="monitor_guard"))==JSON.stringify(map.resident_staff.filter(func(f):return f.id!="monitor_guard")))
	var old_profiles: Dictionary={};var new_profiles: Dictionary={}
	for s in before.architecture.wall_surfaces:old_profiles[int(s.wall_index)]=s
	for s in map.architecture.wall_surfaces:new_profiles[int(s.wall_index)]=s
	var walls_preserved=true;var profiles_preserved=true
	for key in registration.wall_remap:
		var old_index=int(key)
		if registration.selected_walls.any(func(v):return int(v)==old_index):continue
		var new_index=int(registration.wall_remap[key])
		walls_preserved=walls_preserved and before.walls[old_index]==map.walls[new_index]
		var a: Dictionary=old_profiles.get(old_index,{}).duplicate(true);var b: Dictionary=new_profiles.get(new_index,{}).duplicate(true)
		a.erase("wall_index");b.erase("wall_index")
		profiles_preserved=profiles_preserved and JSON.stringify(a)==JSON.stringify(b)
	check("all unrelated wall geometry preserved",walls_preserved)
	check("all unrelated wall profiles preserved",profiles_preserved)
	var assets: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"asset-registration.json"))
	for asset in assets.assets:check("original PNG "+asset.key,FileAccess.get_sha256("res://"+asset.path)==asset.sha256)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false)
	game.world.admission_filter=Callable();game.orders.clear();game.schedule.set_time_speed(0)
	var player=game.actors[0]
	for actor in game.actors:actor.position=Vector2(3800+actor.actor_id*60,2600)
	game.guard.position=Vector2(3000,1500);game.dog.position=Vector2(3100,1500)
	var room=game.room_visibility.rooms.filter(func(r):return r.id=="monitor")[0]
	check("compact monitoring region",room.area.size==Vector2(380,500))
	check("visible floor depth 420",registration.visible_interior[3]==420)
	var door=game.room_visibility.doorways.by_id("monitor-entry")
	check("both door state textures loaded",door.custom_texture!=null and door.closed_custom_texture!=null)
	check("door retains locking rules",game.world.access_by_id("monitor-entry").kind=="locked")
	check("door starts closed",door.closed)
	var outside:=Vector2(4970,1060);var inside:=Vector2(4970,950)
	check("closed door blocks passage",not game.world.motion_clear(outside,inside,player,false,true))
	game.world.set_access_closed("monitor-entry",false);game.room_visibility.doorways.tick(true)
	check("door open state applied",not door.closed)
	# The left swung leaf occupies the painted edge; test three lanes inside
	# the actual aperture rather than placing a full body through the leaf.
	for x in [4940,4970,5020]:
		check("open door both directions "+str(x),travel(player,Vector2(x,1060),Vector2(x,940)) and travel(player,Vector2(x,940),Vector2(x,1060)))
	check("west open jamb blocks",not game.world.door_body_clear(Vector2(4875,1005)))
	check("east open jamb blocks",not game.world.door_body_clear(Vector2(5065,1005)))
	for point in [Vector2(4870,605),Vector2(5080,580),Vector2(4885,760),Vector2(4890,630),Vector2(5005,780),Vector2(5055,830)]:
		check("reachable interior "+str(point),travel(player,outside,point))
	check("cabinet still searchable",game.looting.containers.has("campus-admin-cabinet-2"))
	check("old console removed",not map.fixtures.any(func(f):return f.id=="campus-admin-desk-2" or f.id=="campus-admin-board-2"))
	var fixtures=game.world.fixtures.filter(func(f):return f.get("monitor_generated",false))
	var solids: Array=[]
	for f in fixtures:
		if f.blocks_movement:solids.append_array(game.world.fixture_collision_rects(f))
	var overlap=false
	for i in range(solids.size()):
		for j in range(i+1,solids.size()):overlap=overlap or solids[i].intersection(solids[j]).get_area()>.01
	check("furniture footprints do not overlap",not overlap)
	var guard=game.resident_staff.actors.monitor_guard
	check("existing guard art reused",guard.definition.id=="patrol_guard" and guard.motion.walk.size()==8)
	check("guard feet clear",game.world.can_place_circle(guard.position,game.ACTOR_RADIUS,null,false,false))
	for point in map.resident_staff.filter(func(f):return f.id=="monitor_guard")[0].patrol:
		check("guard patrol reachable "+str(point),not game.world.find_path(outside,Vector2(point[0],point[1]),player,false,true).is_empty())
	check("human scale retained",preload("res://scripts/core/world_scale.gd").HUMAN==1.4)
	var cover=game.room_visibility.covers.filter(func(c):return c.room.id=="monitor")[0]
	player.position=outside;game.room_visibility.tick(0,true)
	check("monitor roof visible outside",cover.visible and cover.modulate.a==1)
	game.presentation.tick(0)
	check("exterior plaque visible with roof closed",game.presentation.volumes.any(func(v):return v.kind=="fixture" and game.world.fixtures[v.wall_index].id=="monitor-v1-sign" and v.visible))
	check("dedicated monitor roof loaded",cover.style=="monitor" and cover.roof_texture!=null)
	check("roof has vent detail",cover.has_node("roof_vent_hood"))
	var builds=cover.draw_builds
	for i in range(30):game.presentation.tick(0)
	await frame()
	check("roof geometry remains cached",cover.draw_builds==builds)
	player.position=Vector2(4970,740);game.room_visibility.tick(0,true)
	check("monitor roof hides inside",not cover.visible and cover.modulate.a==0)
	var doc=preload("res://scripts/editor/map_document.gd").new();doc.open_file("res://data/rooms/r04.json")
	check("map validation",doc.validate().errors.is_empty())
	var catalog=preload("res://scripts/editor/editor_catalog.gd").new()
	for id in assets.definition_ids:
		var entries=catalog.entries.filter(func(e):return e.id==id)
		check("editor icon "+id,entries.size()==1 and catalog.icon(entries[0])!=null)
		if entries.size()==1:
			var icon: Texture2D=catalog.icon(entries[0])
			check("bounded runtime texture "+id,icon!=null and maxi(icon.get_width(),icon.get_height())<=512)
	var ref=doc.add("fixtures",Vector2(4900,700),"monitor_console_v1")
	check("editor preserves console ratio",is_equal_approx(doc.value(ref).rect[2],260))
	doc.undo();check("editor placement undo",not doc.dirty())
	if DisplayServer.get_name()!="headless":
		game.get_node("HUD").hide()
		root.size=Vector2i(840,1000);root.content_scale_size=root.size
		await capture("runtime-interior",Vector2(4970,665),1.35)
		game.world.set_access_closed("monitor-entry",true);game.room_visibility.doorways.tick(true)
		await capture("runtime-door-closed",Vector2(4970,940),1.7)
		root.size=Vector2i(1280,900);root.content_scale_size=root.size
		player.position=outside
		await capture("runtime-roof",Vector2(4970,665),1.1)
		player.position=Vector2(4890,760)
		await capture("runtime-corner",Vector2(4800,875),2.1)
	check("QA does not mutate saved map",disk==FileAccess.get_file_as_string("res://data/rooms/r04.json"))
	var failed=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+("headless" if DisplayServer.get_name()=="headless" else "native")+"-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"passed":checks.size()-failed.size()},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)
