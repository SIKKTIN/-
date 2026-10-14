extends SceneTree
const OUT := "res://docs/art/canteen-side-door-v3/"
var game
var checks: Dictionary={}
func _initialize() -> void:
	create_timer(70).timeout.connect(func():quit(124));call_deferred("run")
func frame() -> void:
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func check(k:String,v:bool)->void:
	checks[k]=v
	if not v:print("FAIL: ",k)
func shot(file:String)->void:
	game.presentation.tick(0);await frame();await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+file+".png")
func run()->void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://canteen-side-door-qa.cfg")
	root.size=Vector2i(1200,720);root.content_scale_size=root.size;Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(OUT)
	var path:="res://data/rooms/r04.json";var sha:=FileAccess.get_sha256(path)
	game=load("res://scenes/main.tscn").instantiate();game.room_id="r04";root.add_child(game);await frame();await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.get_node("HUD").hide()
	game.guard.position=Vector2(3000,1500);game.dog.position=Vector2(3000,1550)
	var player=game.actors[0];player.position=Vector2(840,2090)
	for l in game.presentation.scene_layers:
		if l.kind=="information":l.hide()
	game.room_visibility.tick(0,true)
	game.map_camera.zoom=Vector2.ONE
	game.map_camera.position=Vector2(1010,2130)-Vector2(root.size)/2;game.map_camera.force_update_scroll()
	game.presentation.tick(0)
	var id:="fixture:campus-life-west-meal"
	var gate:Dictionary=game.world.door_passage.by_id(id)
	var door=game.room_visibility.doorways.by_id(id)
	var room:Dictionary=game.room_visibility.rooms.filter(func(r):return r.id=="canteen")[0]
	var cover=game.room_visibility.covers.filter(func(c):return c.room.id=="canteen")[0]
	var report:={"visual":str(door.visual_rect),"logical":str(gate.rect),"panels":str(cover.panels),"crossings":{}}
	for y in [2080,2090,2100,2110,2120,2130,2140]:
		var clear:bool=game.world.motion_clear(Vector2(820,y),Vector2(1100,y),player,false,true)
		report.crossings[str(y)]=clear
	if OS.get_cmdline_user_args().has("--before"):
		await shot("before-outside")
		FileAccess.open(OUT+"before-geometry.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
		print("BEFORE: ",JSON.stringify(report));game.queue_free();await frame();quit();return
	check("door allows whole body crossing at intuitive center",game.world.motion_clear(Vector2(820,2090),Vector2(1100,2090),player,false,true))
	check("door allows reverse crossing",game.world.motion_clear(Vector2(1100,2090),Vector2(820,2090),player,false,true))
	for y in [2090,2100,2110]:check("comfortable approach "+str(y),game.world.motion_clear(Vector2(820,y),Vector2(1100,y),player,false,true))
	check("original outside-hours admission preserved",not game.room_access.movement_allowed(player,Vector2(1100,2090),game.world.RADIUS))
	game.schedule.clock_elapsed=(720.0-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.tick(false);game.room_access.tick();game.room_visibility.tick(0,true)
	check("actual actor can enter at opening time",game.world.can_place_circle(Vector2(1100,2090),game.world.RADIUS,player,false,false))
	player.position=Vector2(820,2090)
	check("actual forward walking crosses doorway",game.world.move_actor(player,Vector2(280,0)).is_equal_approx(Vector2(280,0)))
	check("actual reverse walking crosses doorway",game.world.move_actor(player,Vector2(-280,0)).is_equal_approx(Vector2(-280,0)))
	check("existing door asset reused",door.custom_texture!=null and door.closed_custom_texture!=null)
	check("sealed roof has no door holes",room.roof_plan.membrane_cutouts.is_empty() and room.get("roof_sealed",false))
	check("roof sorts above side door",door.z_index<cover.z_index)
	var inside:Rect2=door.visual_rect.intersection(Rect2(900,0,2000,4500))
	check("roof membrane covers inward door artwork",cover.panels.any(func(p):return p.encloses(inside)))
	check("outside roof visible",cover.visible and cover.modulate.a>.9)
	await shot("after-outside")
	var selected:Dictionary=preload("res://scripts/presentation/doorway_geometry.gd").art_spec(gate)
	var turns:int=int(selected.rotation_quarters)
	var closed_parts:Array=selected.closed_visual_solid_parts
	# Static managed gate state still enforces its full closed door silhouette.
	gate.closed=true;game.world._changed();door.refresh(true)
	check("closed enlarged door blocks passage",not game.world.motion_clear(Vector2(820,2090),Vector2(1100,2090),player,false,true))
	gate.closed=false;game.world._changed();door.refresh(true)
	player.position=Vector2(1060,2090);game.room_visibility.tick(1,true);game.presentation.tick(0)
	check("entry reveals correct room",game.room_visibility.active_id=="canteen")
	check("roof clears inside",cover.modulate.a<.1)
	await shot("after-inside")
	player.position=Vector2(820,2090);game.room_visibility.tick(1,true);game.presentation.tick(0)
	check("exit restores roof",game.room_visibility.active_id!="canteen" and cover.modulate.a>.9)
	var before:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"before-map.json"))
	var now:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var report_map:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"map-registration.json"))
	var preserve:=true
	for k in before:
		if k not in ["fixtures","walls","architecture","visibility_rooms","access_doors"] and before[k]!=now[k]:preserve=false
	check("unrelated map rules preserved",preserve)
	var old_furniture:Array=before.fixtures.filter(func(f):return f.id!="campus-life-west-meal").duplicate(true)
	var new_furniture:Array=now.fixtures.filter(func(f):return f.id!="campus-life-west-meal").duplicate(true)
	for f in old_furniture+new_furniture:f.erase("roof_occludes_door")
	check("furniture and all other door geometry preserved",old_furniture==new_furniture)
	check("wall coordinates and indices preserved",before.walls==now.walls)
	var doc=preload("res://scripts/editor/map_document.gd").new();doc.data=now
	var old=preload("res://scripts/editor/map_document.gd").new();old.data=before
	check("map validates",doc.validate().errors.is_empty())
	check("no new map warnings",doc.validate().warnings==old.validate().warnings)
	check("QA leaves map unchanged",FileAccess.get_sha256(path)==sha)
	for a in JSON.parse_string(FileAccess.get_file_as_string("res://art/architecture/canteen_side_v3/manifest.json")).assets:
		check("existing baked pixels reused "+a.id,preload("res://scripts/presentation/runtime_texture_store.gd").texture(a)!=null)
	FileAccess.open(OUT+"after-geometry.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	var failed:Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	game.queue_free();await frame();quit(0 if failed.is_empty() else 1)
