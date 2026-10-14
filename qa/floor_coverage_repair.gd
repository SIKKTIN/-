extends SceneTree
const OUT := "res://docs/tests/floor-coverage-repair/"
const Terrain = preload("res://scripts/presentation/region_terrain.gd")
const Transform = preload("res://scripts/editor/map_transform.gd")
var checks := {}
var native := false
class FloorProbe extends Node2D:
	var config: Dictionary
	var clip:=Rect2(2150,1200,1100,100)
	func _draw():Terrain.paint(self,config,clip,-clip.position+Vector2(100,100))
func check(label: String, passed: bool):checks[label]=passed
func _initialize():call_deferred("run")
func frame():
	await process_frame
	if native:await RenderingServer.frame_post_draw
func shot(name: String):
	await frame();await frame()
	if native:root.get_texture().get_image().save_png(OUT+name+".png")
func top_floor(data: Dictionary, point: Vector2) -> Dictionary:
	var result: Dictionary={}
	for spec in data.floor_regions:
		var r: Array=spec.rect
		if Rect2(r[0],r[1],r[2],r[3]).has_point(point):result=spec
	return result
func run():
	native=DisplayServer.get_name()!="headless"
	root.size=Vector2i(1600,1000);root.content_scale_size=root.size
	var saved:=FileAccess.get_sha256("res://data/rooms/r04.json")
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"map-before.json"))
	var after: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"map-after.json"))
	var geometry_preserved:=true
	for key in before:
		if key!="floor_regions":geometry_preserved=geometry_preserved and before[key]==after[key]
	check("saved repair changes floor data only",geometry_preserved)
	for old in before.floor_regions:
		var current: Dictionary=after.floor_regions.filter(func(f):return f.id==old.id)[0]
		for key in ["asset_id","manifest","tile_size","natural_ground","tint"]:check(str(old.id)+" preserves "+key,old.get(key)==current.get(key))
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor);await frame();await frame()
	var doc=editor.document
	check("saved map opens",not doc.data.is_empty());check("saved map validates",doc.validate().errors.is_empty())
	for pair in [[Vector2(1500,2000),"cafeteria_floor_v1"],[Vector2(950,1950),"cafeteria_floor_v1"],[Vector2(1500,2350),"cafeteria_floor_v1"],[Vector2(4220,1200),"toolroom_floor_v1"],[Vector2(4210,1500),"toolroom_floor_v1"],[Vector2(2600,1980),"workshop_floor_v46"],[Vector2(2990,2200),"workshop_floor_v46"],[Vector2(870,2100),"loading_floor_v46"],[Vector2(2160,1980),"loading_floor_v46"],[Vector2(2160,2700),"loading_floor_v46"],[Vector2(3950,1700),"loading_floor_v46"],[Vector2(2600,1870),"loading_floor_v46"],[Vector2(400,3500),"grass_base_v46"],[Vector2(3200,2000),"grass_base_v46"],[Vector2(4800,3400),"grass_base_v46"]]:
		check("ground material at "+str(pair[0]),top_floor(doc.data,pair[0]).get("asset_id")==pair[1])
	var original_doc: Dictionary=doc.data.duplicate(true)
	var room_index: int=-1
	for index in doc.data.visibility_rooms.size():
		if doc.data.visibility_rooms[index].id=="tools":room_index=index
	var copy_refs: Array=[]
	for surface in doc.data.architecture.wall_surfaces:
		if str(surface.get("grid_tile_asset","")).begins_with("toolroom_"):copy_refs.append({"group":"walls","index":int(surface.wall_index)})
	copy_refs.append({"group":"visibility_rooms","index":room_index})
	editor.canvas.choose_group(copy_refs)
	editor.duplicate_selected()
	var cloned: Array=doc.data.floor_regions.filter(func(f):return str(f.id).begins_with("campus-tools_copy"))
	check("duplicate carries linked room floor",cloned.size()==1)
	if cloned.size()==1:
		check("copied floor links to copied room",str(cloned[0].room_id)!="tools" and doc.data.visibility_rooms.any(func(r):return r.id==cloned[0].room_id))
	doc.undo();check("duplicate undo restores floor metadata",doc.data==original_doc);editor.canvas.choose({})
	var preview=editor.canvas.architecture_preview
	var gate: Dictionary=preview.world.access_by_id("tools-rear")
	var door_rect:=preload("res://scripts/presentation/doorway_geometry.gd").projected_rect(preview.world,gate)
	var threshold:=preload("res://scripts/presentation/doorway_geometry.gd").floor_for(doc.data,door_rect)
	check("door threshold uses matching room material",threshold.asset_id=="toolroom_floor_v1")
	var outdoor:=preload("res://scripts/presentation/doorway_geometry.gd").floor_for({"floor_regions":[{"rect":[700,200,200,3420],"asset_id":"loading_floor_v46","tile_size":[320,320],"tile_origin":[0,0]}]},Rect2(720,400,160,24))
	check("doorway honors shared outdoor UV origin",outdoor.origin==Vector2.ZERO)
	# Reproduce a tight selection: the floor has a 20-pixel apron beyond the
	# selected wall bounds. Move, rotate, copy and undo must keep it attached.
	var sample=preload("res://scripts/editor/map_document.gd").new()
	sample.data={"walls":[[100,100,20,100],[280,100,20,100]],"architecture":{"wall_surfaces":[]},"fixtures":[],"floor_regions":[{"id":"room-floor","rect":[80,80,240,140],"asset_id":"common_floor_v46","tile_size":[320,320]},{"id":"unrelated-road","rect":[0,0,6000,4500],"asset_id":"loading_floor_v46","tile_size":[320,320],"tile_origin":[0,0]}]}
	var initial: Dictionary=sample.data.duplicate(true)
	var refs: Array=[{"group":"walls","index":0},{"group":"walls","index":1}]
	var snapshot:=Transform.capture(sample,refs)
	check("tight wall selection captures floor apron",snapshot.extras.size()==1 and snapshot.extras[0].value.id=="room-floor")
	sample.begin();Transform.apply(sample,snapshot,0,Vector2(80,120));sample.commit()
	check("move carries complete floor apron",sample.data.floor_regions[0].rect==[160.0,200.0,240.0,140.0])
	check("shared outdoor floor stays in place",sample.data.floor_regions[1]==initial.floor_regions[1])
	sample.undo();check("one undo restores floor and walls",sample.data==initial)
	var owned=initial.duplicate(true);owned.visibility_rooms=[{"id":"sample-room","rect":[100,100,200,100]}];owned.floor_regions[0].room_id="sample-room";owned.floor_regions[0].rect=[80,20,240,180];sample.data=owned
	var owned_refs: Array=refs+[{"group":"visibility_rooms","index":0}]
	check("linked room floor survives extended threshold",Transform.capture(sample,owned_refs).extras.size()==1)
	# Compare the actual neighbouring road pieces against a single uninterrupted
	# piece. Equal native pixels demonstrate there is no UV reset at the join.
	if native:
		editor.hide()
		var probe:=FloorProbe.new();probe.config={"terrain_manifest":doc.data.terrain_manifest,"floor_regions":doc.data.floor_regions.filter(func(f):return f.id in ["north-life-plaza","yard-main-loop","north-admin-loop"])};root.add_child(probe)
		await frame();await frame();var split:=root.get_texture().get_image()
		probe.config={"terrain_manifest":doc.data.terrain_manifest,"floor_regions":[{"asset_id":"loading_floor_v46","rect":[2150,1200,1100,100],"tile_size":[320,320],"tile_origin":[0,0]}]};probe.queue_redraw();await frame();await frame();var unified:=root.get_texture().get_image()
		var differences:=0
		for y in range(102,198):
			for x in range(102,1198):
				var delta:=split.get_pixel(x,y)-unified.get_pixel(x,y)
				if absf(delta.r)+absf(delta.g)+absf(delta.b)>.015:differences+=1
		check("native road joins match one continuous floor",differences<20)
		probe.queue_free();editor.show();await frame()
	for target in [["after-canteen",Vector2(1660,2290),.8],["after-tools",Vector2(4000,1300),1.0],["after-overview",Vector2(3000,2180),.2]]:
		editor.canvas.zoom=target[2];editor.canvas.origin=editor.canvas.size/2-target[1]*target[2];editor.canvas.queue_redraw();await shot(target[0])
	editor.queue_free();await frame()
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off");OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://floor-coverage-qa.cfg")
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frame();game.set_process(false);game.fullscreen_ui.set_process(false);game.get_node("HUD").hide()
	game.map_camera.center_on(Vector2(1650,2240));game.map_camera.force_update_scroll()
	game.actors[0].position=Vector2(1500,2200)
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)
	check("runtime kitchen floor visible in current room",game.room_visibility.active_id=="canteen")
	await shot("runtime-floor")
	check("runtime consumes the saved repaired floor coverage",game.room_config.floor_regions==doc.data.floor_regions)
	var latest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/rooms/r04.json"))
	check("tests preserve saved floor edits",latest.floor_regions==original_doc.floor_regions)
	check("tests preserve saved wall and gate geometry",latest.walls==original_doc.walls and latest.access_doors==original_doc.access_doors)
	var concurrent_changes: Array=[]
	for key in latest:
		if latest.get(key)!=original_doc.get(key):concurrent_changes.append(key)
	var failed: Array=checks.keys().filter(func(k):return not checks[k]);FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"concurrent_changes":concurrent_changes},"\t"));print(JSON.stringify({"checks":checks.size(),"failed":failed}));quit(0 if failed.is_empty() else 1)