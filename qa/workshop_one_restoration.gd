extends SceneTree
const OUT="res://docs/art/workshop-one-restoration/"
var checks={}
var game
func check(label:String,passed:bool):checks[label]=passed
func _initialize():call_deferred("run")
func frame():
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func minute(value:float):
	game.schedule.clock_elapsed=(value-float(game.schedule.config.start_minutes))/1440*game.schedule.day_seconds
	game.schedule.tick(false)
	game.workshop.update_gate()
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://workshop-one-qa.cfg")
	root.size=Vector2i(1600,1050);root.content_scale_size=root.size
	var text:=FileAccess.get_file_as_string("res://data/rooms/r04.json")
	var before:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"last-input-map.json"))
	var after:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"last-output-map.json"))
	var record:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"map-registration.json"))
	check("all wall geometry retained",before.walls==after.walls)
	check("all room visibility bounds retained",before.visibility_rooms==after.visibility_rooms)
	for key in before:
		if key not in ["architecture","fixtures","floor_regions","access_doors","routine_points","workshop","zones","workshop_restoration_version"]:check("preserved map field "+key,before[key]==after[key])
	check("other floors retained",before.floor_regions.filter(func(v):return v.id!="workshop")==after.floor_regions.filter(func(v):return v.id!="workshop"))
	check("other fixtures retained",before.fixtures.filter(func(v):return not record.edited_fixture_ids.has(v.id) and not v.get("workshop_generated",false))==after.fixtures.filter(func(v):return not record.edited_fixture_ids.has(v.id) and not v.get("workshop_generated",false)))
	check("other wall surfaces retained",before.architecture.wall_surfaces.filter(func(v):return not record.selected_walls.has(v.wall_index))==after.architecture.wall_surfaces.filter(func(v):return not record.selected_walls.has(v.wall_index)))
	for id in ["workshop-entry","workshop-entry-east"]:
		var old:Dictionary=before.access_doors.filter(func(v):return v.id==id)[0]
		var now:Dictionary=after.access_doors.filter(func(v):return v.id==id)[0]
		for key in old:
			if key!="asset_id":check("preserved gate "+id+" "+key,old[key]==now[key])
	var assets:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"asset-registration.json"))
	for a in assets.assets:check("unchanged PNG "+a.key,FileAccess.get_sha256("res://"+a.path)==a.sha256)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false)
	var player=game.actors[0]
	var area:=Rect2(820,1420,1360,720)
	check("same room dimensions",game.workshop.area==area)
	check("human scale unchanged",preload("res://scripts/core/world_scale.gd").HUMAN==1.4)
	minute(480)
	player.position=Vector2(1430,1820)
	game.room_visibility.tick(0,true)
	for id in ["workshop-entry","workshop-entry-east"]:
		var gate:Dictionary=game.world.access_by_id(id)
		var door=game.room_visibility.doorways.by_id(id)
		check("open art and closed art loaded "+id,door.custom_texture!=null and door.closed_custom_texture!=null)
		var centre:=Vector2(gate.rect.get_center().x,0)
		var outside:=Vector2(centre.x,gate.rect.end.y+55)
		var inside:=Vector2(centre.x,gate.rect.position.y-140)
		check("whole body crosses both directions "+id,game.world.motion_clear(outside,inside,player,false,true) and game.world.motion_clear(inside,outside,player,false,true))
		check("straight exterior approach clear "+id,game.world.motion_clear(Vector2(centre.x,gate.rect.end.y+150),inside,player,false,true))
		if not checks["whole body crosses both directions "+id]:
			print("DOOR DEBUG "+id+" "+str(game.world.body_solids.filter(func(v):return game.world.ray_rect_fraction(outside,inside,v)>=0)))
	var fixtures:Array=game.world.fixtures.filter(func(v):return str(v.asset_id).begins_with("workshop_"))
	var solids:Array=[]
	for f in fixtures:
		if f.blocks_movement:solids.append_array(game.world.fixture_collision_rects(f))
	var overlaps:=false
	for i in range(solids.size()):
		for j in range(i+1,solids.size()):
			if solids[i].intersection(solids[j]).get_area()>.01:overlaps=true
	check("new furniture ground areas do not overlap",not overlaps)
	var origin:=Vector2(1340,2265)
	for i in range(after.routine_points.work.size()):
		var v:Array=after.routine_points.work[i];var point:=Vector2(v[0],v[1])
		check("work point clear "+str(i),game.world.can_place_circle(point,game.ACTOR_RADIUS,player,false,false))
		if not checks["work point clear "+str(i)]:print("STATION DEBUG "+str(point)+" "+str(game.world.solid_rects(false).filter(func(v):return v.grow(10).has_point(point))))
		check("work point reachable "+str(i),not game.world.find_path(origin,point,player,false,true).is_empty())
	for i in range(after.workshop.patrol.size()):
		var v:Array=after.workshop.patrol[i];var point:=Vector2(v[0],v[1])
		check("patrol point reachable "+str(i),not game.world.find_path(origin,point,player,false,true).is_empty())
	for f in fixtures:
		if not f.has("loot_profile"):continue
		check("search container registered "+f.id,game.looting.containers.has(f.id))
		var point:Vector2=f.rect.get_center()+Vector2(0,f.rect.size.y/2+28)
		for candidate in [point,f.rect.get_center()+Vector2(0,f.rect.size.y/2+12),f.rect.get_center()+Vector2(f.rect.size.x/2+16,0),f.rect.get_center()-Vector2(f.rect.size.x/2+16,0)]:
			if game.world.can_place_circle(candidate,game.ACTOR_RADIUS,player,false,false) and not game.world.find_path(origin,candidate,player,false,true).is_empty():
				point=candidate;break
		player.position=point
		game.room_visibility.tick(0,true)
		check("search approach reachable "+f.id,game.world.can_place_circle(point,game.ACTOR_RADIUS,player,false,false) and not game.world.find_path(origin,point,player,false,true).is_empty())
		check("search can open "+f.id,game.looting.reason(f.id)=="")
	var locker:Dictionary=game.world.fixtures.filter(func(v):return v.id=="locker_0")[0]
	player.position=locker.rect.get_center()+Vector2(0,locker.rect.size.y/2+28)
	game.room_visibility.tick(0,true)
	check("open retained tool locker",game.looting.open("locker_0"))
	game.looting.tick(40)
	var state:Dictionary=game.looting.containers["locker_0"]
	if not state.ids.is_empty():
		var id:String=state.ids[0];var cell:Vector2i=state.layout[id].position
		check("tool can transfer to backpack",game.looting.take(id).ok)
		check("tool can return to source",game.looting.move_item(id,"bag","source",cell).ok and state.ids.has(id))
	else:check("tool locker has loot",false)
	game.looting.close()
	for i in range(game.actors.size()):
		var p:Array=after.routine_points.work[i%3]
		game.actors[i].position=Vector2(p[0],p[1]);game.actors[i].immune_until=INF
	game.workshop.overseer.position=Vector2(after.workshop.overseer_start[0],after.workshop.overseer_start[1])
	game.room_visibility.tick(0,true);game.presentation.tick(0)
	game.get_node("HUD").hide()
	game.map_camera.center_on(area.get_center()+Vector2(0,-20));game.map_camera.force_update_scroll()
	await frame();await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+"runtime-interior.png")
	var cover=game.room_visibility.covers.filter(func(v):return v.room.id=="workshop")[0]
	check("roof hidden inside",not cover.visible)
	minute(550)
	check("both doors close for labour",game.world.access_by_id("workshop-entry").closed and game.world.access_by_id("workshop-entry-east").closed)
	check("closed gate blocks whole body",not game.world.motion_clear(Vector2(1340,2265),Vector2(1340,2060),player,false,true))
	for i in range(game.actors.size()):
		if i==0:check("start labour at new station "+str(i),game.workshop.start_work(i))
		else:game.routines.start_work(i)
		check("new station is working "+str(i),game.routines.is_working(i))
	var revisions:int=game.world.obstacle_revision
	for i in range(60):game.workshop.update_gate()
	check("unchanged schedule does not rebuild obstacles",game.world.obstacle_revision==revisions)
	game.schedule.set_time_speed(0)
	var overseer_start:Vector2=game.workshop.overseer.position
	for i in range(180):game._process(.1)
	check("overseer actually patrols new room",game.workshop.overseer.position.distance_to(overseer_start)>15 and area.has_point(game.workshop.overseer.position))
	minute(720)
	check("both doors reopen at lunch",not game.world.access_by_id("workshop-entry").closed and not game.world.access_by_id("workshop-entry-east").closed)
	player.position=origin;game.room_visibility.tick(0,true)
	check("roof restored outside",cover.visible)
	var doc=preload("res://scripts/editor/map_document.gd").new()
	check("editor map validates",doc.open_file("res://data/rooms/r04.json") and doc.validate().errors.is_empty())
	var catalog=preload("res://scripts/editor/editor_catalog.gd").new()
	for id in ["workshop_workbench_v1","workshop_west_parts_rack_v1","workshop_corner_nw","doorway_workshop_open_v1","doorway_workshop_closed_v1"]:check("editor includes "+id,catalog.entries.any(func(v):return v.id==id))
	check("QA leaves saved map untouched",text==FileAccess.get_file_as_string("res://data/rooms/r04.json"))
	var failed:Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	game.queue_free();await frame();quit(0 if failed.is_empty() else 1)
