extends SceneTree
const OUT := "res://docs/art/roof-door-coverage-v1/"
var game
var checks:Dictionary={}
func check(k:String,v:bool)->void:
	checks[k]=v
	if not v:print("FAIL: ",k)
func shot(name:String,center:Vector2,zoom:float=1.0)->void:
	game.map_camera.zoom=Vector2.ONE*zoom
	game.map_camera.position=center-Vector2(root.size)/zoom/2
	game.map_camera.force_update_scroll();game.presentation.tick(0)
	await frame();await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+name+".png")
func _initialize()->void:create_timer(80).timeout.connect(func():quit(124));call_deferred("run")
func frame()->void:
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func run()->void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://roof-door-coverage-qa.cfg")
	root.size=Vector2i(1200,720);root.content_scale_size=root.size;Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(OUT)
	game=load("res://scenes/main.tscn").instantiate();game.room_id="r04";root.add_child(game);await frame();await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.get_node("HUD").hide()
	var path:="res://data/rooms/r04.json"
	var digest:=FileAccess.get_sha256(path)
	var baseline_mode:bool=OS.get_cmdline_user_args().has("--before")
	var player=game.actors[0]
	player.position=Vector2(3450,2200);game.room_visibility.tick(0,true)
	for layer in game.presentation.scene_layers:
		if layer.kind=="information":layer.hide()
	var report:Array=[]
	for room in game.room_visibility.rooms:
		var roof=game.room_visibility.covers.filter(func(c):return c.room.id==room.id)[0]
		var entry:={"room":room.id,"roof":str(roof.roof),"panels":str(roof.panels),"sealed":room.get("roof_sealed",false),"z":roof.z_index,"ports":[]}
		for port in room.roof_plan.ports:
			var door=game.room_visibility.doorways.by_id(str(port.id))
			if door==null:continue
			var hit:Rect2=door.visual_rect.intersection(roof.roof.grow_individual(-20,-20,-20,0))
			var uncovered:float=0
			for r in preload("res://scripts/presentation/roof_geometry.gd").subtract_all(hit,roof.panels):uncovered+=r.get_area()
			var depth:int=door.z_index
			for part in door.patch_parts:depth=maxi(depth,part.z_index)
			entry.ports.append({"id":port.id,"visual":str(door.visual_rect),"intersection":str(hit),"inward_area":hit.get_area(),"uncovered_area":uncovered,"door_z":depth,"roof_occludes":door.gate.get("roof_occludes_door",false)})
			if not baseline_mode and hit.has_area():
				check("no inward roof hole "+str(room.id)+"/"+str(port.id),uncovered<.01)
				check("inward artwork below owning roof "+str(room.id)+"/"+str(port.id),depth<roof.z_index)
		report.append(entry)
	var suffix:="before" if baseline_mode else "after"
	FileAccess.open(OUT+suffix+"-audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	if baseline_mode:
		print(JSON.stringify(report));game.queue_free();await frame();quit();return
	var reg:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"map-registration.json"))
	var before:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"before-map.json"))
	var after:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var unrelated:=true
	for k in before:
		if k not in ["visibility_rooms","fixtures"] and before[k]!=after[k]:unrelated=false
	check("all collision, schedules, access rules and other map data preserved",unrelated)
	var old_fixtures:Array=before.fixtures.duplicate(true)
	var new_fixtures:Array=after.fixtures.duplicate(true)
	for f in old_fixtures+new_fixtures:
		if str(f.id) in reg.fixture_ids:f.erase("roof_occludes_door")
	check("all furniture and door coordinates preserved",old_fixtures==new_fixtures)
	var old_rooms:Array=before.visibility_rooms.duplicate(true)
	var new_rooms:Array=after.visibility_rooms.duplicate(true)
	for r in old_rooms+new_rooms:
		if str(r.id) in reg.rooms:r.erase("roof_sealed")
		# Another active authoring task updated the duty/office roof materials.
		# Their dimensions/outlines stay identical and the latest styling is kept.
		if str(r.id) in ["duty","office"]:r.erase("roof_style");r.erase("roof_asset_id")
	check("all room outlines and dimensions preserved",old_rooms==new_rooms)
	var room_rules=preload("res://scripts/core/room_visibility.gd")
	var geom=preload("res://scripts/presentation/roof_geometry.gd")
	var adapter=preload("res://scripts/editor/preview_geometry.gd").new()
	adapter.update(before,true)
	var old_plans:Dictionary={}
	for r in room_rules.rooms_for(before):
		r.area=adapter.rect(r.rect)
		old_plans[r.id]=geom.plan(adapter,r)
	for room in game.room_visibility.rooms:
		check("wall/door portal cuts unchanged "+str(room.id),old_plans[room.id].cutouts==room.roof_plan.cutouts)
		check("roof envelope unchanged "+str(room.id),old_plans[room.id].roof==room.roof_plan.roof)
	var motions:Dictionary={}
	var baseline_world=preload("res://scripts/world/prison_world.gd").new()
	baseline_world.configure(before,[])
	var baseline_rooms:Array=[]
	var baseline_cuts:Array=[]
	for r in room_rules.rooms_for(before):
		r.area=Rect2(r.rect[0],r.rect[1],r.rect[2],r.rect[3])
		r.roof_plan=geom.plan(baseline_world,r)
		baseline_rooms.append(r)
		for p in r.roof_plan.ports:
			if p.has("opening") and p.opening not in baseline_cuts:baseline_cuts.append(p.opening)
	var door_geometry=preload("res://scripts/presentation/doorway_geometry.gd")
	baseline_cuts.append_array(door_geometry.fixture_cuts(baseline_world))
	var boundary_clips:Dictionary=geom.wall_edge_clips(baseline_world,baseline_rooms,baseline_cuts)
	var projected:Dictionary={}
	for g in baseline_world.access_doors+baseline_world.dorm_doors:projected[g.rect]=door_geometry.projected_rect(baseline_world,g)
	projected[baseline_world.door]=door_geometry.projected_rect(baseline_world,door_geometry.primary_spec(baseline_world))
	baseline_world.door_passage.configure(baseline_world,baseline_rooms)
	baseline_world.set_wall_boundaries(boundary_clips,projected)
	var preexisting_blocked:Array=[]
	for room_id in reg.affected:
		var room:Dictionary=game.room_visibility.rooms.filter(func(r):return r.id==room_id)[0]
		var cover=game.room_visibility.covers.filter(func(c):return c.room.id==room_id)[0]
		for id in reg.affected[room_id]:
			var gate:Dictionary=game.world.door_passage.by_id(id)
			var door=game.room_visibility.doorways.by_id(id)
			var rect:Rect2=gate.rect
			var vertical:bool=rect.size.y>rect.size.x
			var pairs:Array=[]
			var linked:Dictionary=game.world.access_by_id("tools-entry")
			var previous_closed:bool=bool(linked.closed)
			var original_gate:Dictionary=baseline_world.door_passage.by_id(id)
			if id=="fixture:campus-workshop-two-east":
				# This passage leads into the locked tool room; test it unlocked.
				game.world.set_access_closed("tools-entry",false)
				baseline_world.set_access_closed("tools-entry",false)
			if vertical:
				for y in range(int(rect.position.y),int(rect.end.y)+1):
					pairs.append([Vector2(rect.position.x-40,y),Vector2(rect.end.x+40,y)])
			else:
				for x in range(int(rect.position.x)+30,int(rect.end.x)-29):
					pairs.append([Vector2(x,rect.position.y-30),Vector2(x,rect.end.y+40)])
			var usable:Array=[]
			var original_usable:Array=[]
			for pair in pairs:
				if game.world.motion_clear(pair[0],pair[1],player,false,true) and game.world.motion_clear(pair[1],pair[0],player,false,true):usable.append(pair)
				if baseline_world.motion_clear(pair[0],pair[1],null,false,true) and baseline_world.motion_clear(pair[1],pair[0],null,false,true):original_usable.append(pair)
			check("open full-body passage behavior unchanged "+id,usable==original_usable)
			if original_usable.is_empty():preexisting_blocked.append(id)
			if not usable.is_empty():motions[id]=[str(usable[usable.size()/2][0]),str(usable[usable.size()/2][1])]
			gate.closed=true;door.gate.closed=true;game.world._changed();door.refresh(true)
			original_gate.closed=true;baseline_world._changed()
			var closure_matches:=true
			for pair in pairs:
				if game.world.motion_clear(pair[0],pair[1],player,false,true)!=baseline_world.motion_clear(pair[0],pair[1],null,false,true):closure_matches=false
			check("closed collision behavior unchanged "+id,closure_matches)
			gate.closed=false;door.gate.closed=false;game.world._changed();door.refresh(true)
			original_gate.closed=false;baseline_world._changed()
			if id=="fixture:campus-workshop-two-east":game.world.set_access_closed("tools-entry",previous_closed,true)
		# Interior and exterior visibility transitions use the unchanged room bounds.
		player.position=room.area.get_center();game.room_visibility.tick(0,true)
		check("enter hides roof "+room_id,game.room_visibility.active_id==room_id and cover.modulate.a==0)
		player.position=Vector2(3450,2200);game.room_visibility.tick(0,true)
		check("leave restores roof "+room_id,game.room_visibility.active_id!=room_id and cover.modulate.a==1)
		var center:=Vector2(3210,1090) if room_id=="workshop-two" else Vector2(4310,2320)
		await shot("after-"+room_id+"-outside",center)
		player.position=room.area.get_center();game.room_visibility.tick(0,true)
		await shot("after-"+room_id+"-inside",center)
		player.position=Vector2(3450,2200);game.room_visibility.tick(0,true)
	var doc=preload("res://scripts/editor/map_document.gd").new();doc.data=after
	var old_doc=preload("res://scripts/editor/map_document.gd").new();old_doc.data=before
	check("map validates without errors",doc.validate().errors.is_empty())
	check("no added editor warnings",doc.validate().warnings==old_doc.validate().warnings)
	await frame();await frame()
	var builds:Array=game.room_visibility.covers.map(func(c):return c.draw_builds)
	for i in range(12):game.presentation.tick(0);await frame()
	check("roof rendering retained across static frames",builds==game.room_visibility.covers.map(func(c):return c.draw_builds))
	check("verification did not alter saved map",FileAccess.get_sha256(path)==digest)
	var failed:Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"passages":motions,"preexisting_blocked":preexisting_blocked},"\t"))
	print(JSON.stringify({"roof_door_checks":checks.size(),"failed":failed}))
	baseline_world.free();game.queue_free();await frame();quit(0 if failed.is_empty() else 1)
