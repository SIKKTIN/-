extends SceneTree
const OUT="res://docs/art/duty-room-restoration/"
var checks={}
var game
func check(label:String,passed:bool):checks[label]=passed
func _initialize():call_deferred("run")
func frame():
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://duty-room-qa.cfg")
	root.size=Vector2i(1280,900);root.content_scale_size=root.size
	var text:=FileAccess.get_file_as_string("res://data/rooms/r04.json")
	var map:Dictionary=JSON.parse_string(text)
	var before:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"last-input-map.json"))
	var after:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"last-output-map.json"))
	for key in before:
		if key not in ["walls","architecture","fixtures","floor_regions","visibility_rooms","zones","concept_plan","resident_staff"]:check("unrelated map field "+key,before[key]==after[key])
	for key in ["zones","visibility_rooms"]:check("other "+key+" preserved",before[key].filter(func(v):return v.id!="duty")==after[key].filter(func(v):return v.id!="duty"))
	check("other fixtures preserved",before.fixtures.filter(func(v):return v.id not in ["campus-duty","campus-admin-desk-0","campus-admin-cabinet-0","campus-admin-board-0"] and not v.get("duty_generated",false))==after.fixtures.filter(func(v):return v.id not in ["campus-duty","campus-admin-desk-0","campus-admin-cabinet-0","campus-admin-board-0"] and not v.get("duty_generated",false)))
	check("other floors preserved",before.floor_regions.filter(func(v):return v.id not in ["campus-duty","duty-north-grass"])==after.floor_regions.filter(func(v):return v.id not in ["campus-duty","duty-north-grass"]))
	check("existing residents preserved",before.resident_staff==after.resident_staff.filter(func(v):return v.id!="duty_guard"))
	var registration:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"map-registration.json"))
	for key in registration.wall_remap:
		var old_index:int=int(key)
		if registration.selected_walls.any(func(v):return int(v)==old_index):continue
		check("unrelated wall "+key,before.walls[old_index]==after.walls[int(registration.wall_remap[key])])
	var record:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"asset-registration.json"))
	for a in record.assets:check("original PNG "+a.key,FileAccess.get_sha256("res://"+a.path)==a.sha256)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false)
	var room=game.room_visibility.rooms.filter(func(v):return v.id=="duty")[0]
	var area:Rect2=room.area
	check("compact interior",area.size==Vector2(380,440))
	var player=game.actors[0]
	player.position=Vector2(area.get_center().x-10,area.end.y-65)
	game.guard.position=Vector2(3000,1500);game.dog.position=Vector2(3100,1500)
	game.room_visibility.tick(0,true);game.resident_staff.tick(0);game.presentation.tick(0)
	var door=game.room_visibility.doorways.by_id("fixture:campus-duty")
	check("duty doorway art loaded",door.custom_texture!=null and door.visual_rect.size==Vector2(200,120))
	check("original doorway stays in place",map.fixtures.filter(func(v):return v.id=="campus-duty")[0].rect==before.fixtures.filter(func(v):return v.id=="campus-duty")[0].rect)
	var outside:=Vector2(door.visual_rect.get_center().x,door.visual_rect.end.y+95)
	var inside:=Vector2(door.visual_rect.get_center().x,door.visual_rect.position.y+95)
	check("whole body passes through open doorway",game.world.motion_clear(outside,inside,player,false,true) and game.world.motion_clear(inside,outside,player,false,true))
	var fixtures:Array=game.world.fixtures.filter(func(v):return v.get("duty_generated",false))
	var desk:Dictionary=fixtures.filter(func(v):return v.id=="campus-admin-desk-0")[0]
	check("L desk retains two solid arms",desk.solid_parts.size()==2 and game.world.fixture_collision_rects(desk).size()==2)
	var recess:Vector2=desk.rect.position+desk.rect.size*Vector2(.30,.30)
	check("desk recess is walkable",game.world.can_place_circle(recess,game.ACTOR_RADIUS,player,false,false))
	check("desktop is solid",not game.world.can_place_circle(desk.rect.position+desk.rect.size*Vector2(.4,.8),game.ACTOR_RADIUS,player,false,false))
	var solids:Array=[]
	for f in fixtures:
		if f.blocks_movement:solids.append_array(game.world.fixture_collision_rects(f))
	var overlaps:=false
	for i in range(solids.size()):
		for j in range(i+1,solids.size()):
			if solids[i].intersection(solids[j]).get_area()>.01:overlaps=true
	check("furniture ground parts do not overlap",not overlaps)
	for point in [Vector2(area.position.x+115,area.position.y+260),Vector2(area.position.x+135,area.position.y+150),Vector2(area.position.x+140,area.position.y+330),recess]:
		check("reachable station "+str(point),not game.world.find_path(outside,point,player,false,true).is_empty())
	for id in ["campus-admin-desk-0","campus-admin-cabinet-0","duty-communications","duty-shelf","duty-keybox"]:check("searchable "+id,game.looting.containers.has(id))
	player.position=Vector2(area.position.x+130,area.position.y+325)
	check("registration desk search reachable",game.looting.reason("campus-admin-desk-0")=="")
	player.position=Vector2(area.position.x+260,area.position.y+85)
	check("wall key storage searchable from inside",game.looting.reason("duty-keybox")=="")
	check("wall key cabinet can open",game.looting.open("duty-keybox"))
	game.looting.tick(30)
	var state:Dictionary=game.looting.containers["duty-keybox"]
	var keys:Array=state.ids.filter(func(id):return game.inventory.instances[id].definition_id=="door_key")
	check("key cabinet guarantees a key",not keys.is_empty())
	check("key cabinet guarantees duty roster",state.ids.any(func(id):return game.inventory.instances[id].definition_id=="duty_roster"))
	if not keys.is_empty():
		var id:String=keys[0]
		var cell:Vector2i=state.layout[id].position
		check("key can transfer to bag",game.looting.take(id).ok and game.inventory.owns(0,id))
		check("key can be put back at original cell",game.looting.move_item(id,"bag","source",cell).ok and state.ids.has(id) and not game.inventory.owns(0,id))
	game.looting.close()
	player.position=Vector2(area.position.x+130,area.position.y+325)
	var staff=game.resident_staff.actors.duty_guard
	check("existing patrol guard art and walk frames reused",staff.definition.id=="patrol_guard" and staff.motion.walk.size()==8)
	check("human scale unchanged",preload("res://scripts/core/world_scale.gd").HUMAN==1.4)
	check("whole resident uses feet depth",staff.z_index==preload("res://scripts/presentation/world_depth.gd").for_y(staff.position.y,game.world.bounds.end.y))
	check("resident foot point clear",game.world.can_place_circle(staff.position,game.ACTOR_RADIUS,null,false))
	var cover=game.room_visibility.covers.filter(func(v):return v.room.id=="duty")[0]
	check("roof hidden inside",not cover.visible)
	game.get_node("HUD").hide();staff.caption.hide()
	game.map_camera.center_on(area.get_center()+Vector2(0,-30));game.map_camera.force_update_scroll()
	game.room_visibility.tick(0,true);game.presentation.tick(0);await frame();await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+"runtime-interior.png")
	player.position=outside;game.room_visibility.tick(0,true);game.resident_staff.tick(0)
	check("roof restored outdoors",cover.visible and cover.modulate.a==1)
	var initial:Vector2=staff.position
	for i in range(300):game.resident_staff.tick(.1)
	check("duty guard can walk between work stations",staff.position.distance_to(initial)>30 and area.has_point(staff.position))
	var doc=preload("res://scripts/editor/map_document.gd").new()
	check("editor map validates",doc.open_file("res://data/rooms/r04.json") and doc.validate().errors.is_empty())
	var catalog=preload("res://scripts/editor/editor_catalog.gd").new()
	for id in ["duty_desk_v1","duty_keybox_v1","duty_locker_v1","doorway_duty_open_v1","doorway_duty_closed_v1","duty_corner_nw"]:check("editor asset "+id,catalog.entries.any(func(v):return v.id==id))
	check("saved map unchanged by QA",text==FileAccess.get_file_as_string("res://data/rooms/r04.json"))
	var failed:Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	game.queue_free();await frame();quit(0 if failed.is_empty() else 1)
