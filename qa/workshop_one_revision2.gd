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
	var before:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"revision2-input-map.json"))
	var after:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"revision2-output-map.json"))
	var record:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"map-registration-v2.json"))
	check("requested compact dimensions",Vector2(after.workshop.room_rect[2],after.workshop.room_rect[3])==Vector2(1200,600))
	var back_walls:Array=after.architecture.wall_surfaces.filter(func(v):return str(v.get("grid_tile_asset","")).begins_with("workshop_") and after.walls[int(v.wall_index)][1]==after.workshop.room_rect[1]-140)
	check("north wall uses standard 120 height",back_walls.size()>20 and back_walls.all(func(v):return after.walls[int(v.wall_index)][3]==120))
	for old_index in record.geometry.retained_wall_remap:
		var new_index:int=int(record.geometry.retained_wall_remap[old_index])
		check("preserved outside wall "+old_index,before.walls[int(old_index)]==after.walls[new_index])
		var old_surface:Array=before.architecture.wall_surfaces.filter(func(v):return int(v.wall_index)==int(old_index))
		var new_surface:Array=after.architecture.wall_surfaces.filter(func(v):return int(v.wall_index)==new_index)
		if not old_surface.is_empty():
			var original:Dictionary=old_surface[0].duplicate(true);var updated:Dictionary=new_surface[0].duplicate(true)
			original.erase("wall_index");updated.erase("wall_index")
			check("preserved outside surface "+old_index,original==updated)
	check("other visibility rooms retained",before.visibility_rooms.filter(func(v):return v.id!="workshop")==after.visibility_rooms.filter(func(v):return v.id!="workshop"))
	for key in before:
		if key not in ["walls","visibility_rooms","concept_plan","ground_details","architecture","fixtures","floor_regions","access_doors","routine_points","workshop","zones","workshop_restoration_version"]:check("preserved map field "+key,before[key]==after[key])
	check("other floors retained",before.floor_regions.filter(func(v):return v.id!="workshop")==after.floor_regions.filter(func(v):return v.id!="workshop" and not str(v.id).begins_with("workshop-south-apron") and not str(v.id).begins_with("workshop-east-apron")))
	check("other fixtures retained",before.fixtures.filter(func(v):return not record.edited_fixture_ids.has(v.id) and not record.removed_fixture_ids.has(v.id) and not v.get("workshop_generated",false))==after.fixtures.filter(func(v):return not record.edited_fixture_ids.has(v.id) and not record.removed_fixture_ids.has(v.id) and not v.get("workshop_generated",false)))
	check("north band has fifteen modules",record.north_modules.size()==15)
	check("west band has four modules",record.west_modules.size()==4)
	var ground_indices:Array=record.edited_ground_indices.map(func(v):return int(v))
	check("other ground details retained",before.ground_details.filter(func(v):return not ground_indices.has(before.ground_details.find(v)))==after.ground_details.slice(0,-4))
	check("other zones retained",before.zones.filter(func(v):return v.id!="workshop")==after.zones.filter(func(v):return v.id!="workshop"))
	for key in before.workshop:
		if key not in ["room_rect","patrol","overseer_start"]:check("preserved labour configuration "+key,before.workshop[key]==after.workshop[key])
	for id in ["workshop-entry","workshop-entry-east"]:
		var old:Dictionary=before.access_doors.filter(func(v):return v.id==id)[0]
		var now:Dictionary=after.access_doors.filter(func(v):return v.id==id)[0]
		for key in old:
			if key not in ["asset_id","rect"]:check("preserved gate "+id+" "+key,old[key]==now[key])
	var assets:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"asset-registration-v2.json"))
	for a in assets.assets:check("unchanged PNG "+a.key,FileAccess.get_sha256("res://"+a.path)==a.sha256)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false)
	var player=game.actors[0]
	var a:Array=after.workshop.room_rect
	var area:=Rect2(a[0],a[1],a[2],a[3])
	check("runtime room follows resized dimensions",game.workshop.area==area)
	check("human scale unchanged",preload("res://scripts/core/world_scale.gd").HUMAN==1.4)
	minute(480)
	player.position=area.position+Vector2(580,290)
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
	var fixtures:Array=game.world.fixtures.filter(func(v):return str(v.asset_id).begins_with("workshop2_"))
	var solids:Array=[]
	for f in fixtures:
		if f.blocks_movement:solids.append_array(game.world.fixture_collision_rects(f))
	var overlaps:=false
	for i in range(solids.size()):
		for j in range(i+1,solids.size()):
			if solids[i].intersection(solids[j]).get_area()>.01:overlaps=true
	check("new furniture ground areas do not overlap",not overlaps)
	var first_gate:Dictionary=game.world.access_by_id("workshop-entry")
	var origin:Vector2=first_gate.rect.get_center()+Vector2(0,150)
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
		for candidate in [point,f.rect.get_center()+Vector2(0,f.rect.size.y/2+12),f.rect.get_center()+Vector2(f.rect.size.x/2+16,0),f.rect.get_center()-Vector2(f.rect.size.x/2+16,0),f.rect.get_center()-Vector2(0,f.rect.size.y/2+16)]:
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
	game.get_node("HUD").hide()
	game.map_camera.center_on(area.get_center()+Vector2(0,-20));game.map_camera.force_update_scroll()
	game.room_visibility.tick(0,true);game.presentation.tick(0)
	for i in range(4):
		var table=game.presentation.volumes.filter(func(v):return v.kind=="fixture" and game.world.fixtures[v.wall_index].id=="bench_"+str(i))[0]
		var attachment=game.presentation.volumes.filter(func(v):return v.kind=="fixture" and game.world.fixtures[v.wall_index].id=="detail44-bench-tools-"+str(i))[0]
		var top:Rect2=Rect2(table.display_rect.position+Vector2(6,4),Vector2(table.display_rect.size.x-12,table.display_rect.size.y*.72))
		check("attachment lies on wooden top "+str(i),top.encloses(attachment.display_rect))
	await frame();await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+"runtime-interior-v2.png")
	for layer in game.presentation.scene_layers:
		if layer.kind=="information":layer.hide()
	game.presentation.tick(0);await frame();await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+"runtime-interior-v2-clean.png")
	for layer in game.presentation.scene_layers:
		if layer.kind=="information":layer.show()
	var cover=game.room_visibility.covers.filter(func(v):return v.room.id=="workshop")[0]
	check("roof hidden inside",not cover.visible)
	check("roof follows compact room",cover.roof.size.x<=area.size.x+40 and cover.roof.encloses(Rect2(area.position,Vector2(area.size.x,480))))
	minute(550)
	check("both doors close for labour",game.world.access_by_id("workshop-entry").closed and game.world.access_by_id("workshop-entry-east").closed)
	check("closed gate blocks whole body",not game.world.motion_clear(origin,first_gate.rect.get_center()-Vector2(0,140),player,false,true))
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
	for id in ["workshop2_workbench","workshop2_west_tools","workshop2_bench_drill","workshop_corner_nw","doorway_workshop_open_v2","doorway_workshop_closed_v2"]:check("editor includes "+id,catalog.entries.any(func(v):return v.id==id))
	check("QA leaves saved map untouched",text==FileAccess.get_file_as_string("res://data/rooms/r04.json"))
	var failed:Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks-v2.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	game.queue_free();await frame();quit(0 if failed.is_empty() else 1)
