extends SceneTree
var OUT := OS.get_environment("KIOSK_QA_OUTPUT") if not OS.get_environment("KIOSK_QA_OUTPUT").is_empty() else "res://docs/art/campus-kiosk-v2/"
var checks := {}
var game
func _initialize():call_deferred("run")
func check(label: String, passed: bool):checks[label]=passed
func frame():
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func shot(name: String):
	if is_instance_valid(game):game.presentation.tick(0)
	await frame();await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+name+".png")
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://kiosk-entry-qa.cfg")
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var stamp:=FileAccess.get_sha256("res://data/rooms/r04.json")
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"before.json"))
	var after: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"after.json"))
	for key in before:
		if key not in ["fixtures","visibility_rooms","zones"]:
			if key=="floor_regions" and OUT.contains("west-recess"):
				check("other floors preserved",before.floor_regions.filter(func(f):return f.id!="kiosk-entry-shade")==after.floor_regions.filter(func(f):return f.id!="kiosk-entry-shade"))
			else:check("preserved "+key,before[key]==after[key])
	check("unrelated fixtures preserved",before.fixtures.filter(func(f):return not str(f.id).begins_with("kiosk-"))==after.fixtures.filter(func(f):return not str(f.id).begins_with("kiosk-")))
	check("one original merchant only",before.merchants==after.merchants and after.merchants.filter(func(m):return m.id=="campus_kiosk").size()==1)
	check("one front counter and no interior counter",after.fixtures.filter(func(f):return str(f.id).contains("kiosk") and str(f.asset_id).contains("counter")).size()==1)
	check("other rooms preserved",before.visibility_rooms.filter(func(r):return r.id!="campus-kiosk")==after.visibility_rooms.filter(func(r):return r.id!="campus-kiosk"))
	if OUT.contains("open-entry-d"):
		check("D replacement preserves all other fixtures",before.fixtures.filter(func(f):return f.id!="kiosk-side-entry")==after.fixtures.filter(func(f):return f.id!="kiosk-side-entry"))
		check("D replacement preserves roof geometry",before.visibility_rooms==after.visibility_rooms)
		var entry: Dictionary=after.fixtures.filter(func(f):return f.id=="kiosk-side-entry")[0]
		check("D open entry is nonblocking",entry.asset_id=="kiosk_open_entry_d_v3" and not entry.blocks_movement)
	if OUT.contains("west-recess"):
		check("other kiosk fixtures retained",before.fixtures.filter(func(f):return f.id not in ["kiosk-side-entry","kiosk-entry-north-return","kiosk-front-canopy","kiosk-back-shelf"])==after.fixtures.filter(func(f):return f.id not in ["kiosk-side-entry","kiosk-entry-north-return","kiosk-front-canopy","kiosk-back-shelf"]))
	var registration: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"registration.json"))
	var catalog=preload("res://scripts/editor/editor_catalog.gd").new()
	for entry in registration.assets:check(str(entry.key)+" original PNG unchanged",FileAccess.get_sha256("res://"+entry.path)==entry.sha256)
	for id in registration.definition_ids:check(str(id)+" available in editor",catalog.entries.any(func(e):return e.id==id))
	var doc=preload("res://scripts/editor/map_document.gd").new()
	check("editor opens saved map",doc.open_file("res://data/rooms/r04.json"))
	check("saved map validates",doc.validate().errors.is_empty())
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.get_node("HUD").hide();game.world.admission_filter=Callable()
	var player=game.actors[0]
	var entrance:=Vector2(2260,2150)
	player.position=entrance;game.room_visibility.tick(0,true)
	var roof=game.room_visibility.covers.filter(func(c):return c.room.id=="campus-kiosk")[0]
	check("outside roof visible",roof.visible and roof.modulate.a==1)
	for p in [Vector2(2260,2150),Vector2(2340,2150),Vector2(2390,2160),Vector2(2640,2200),Vector2(2850,2220)]:
		check("walkable point "+str(p),game.world.can_place_circle(p,game.ACTOR_RADIUS,player,false))
		check("west door path to "+str(p),not game.world.find_path(entrance,p,player,false,true).is_empty())
	for p in [Vector2(2640,1940),Vector2(2940,2160),Vector2(2340,2050),Vector2(2340,2245),Vector2(2640,2310),Vector2(2640,2100)]:
		check("wall counter shelf block "+str(p),not game.world.can_place_circle(p,game.ACTOR_RADIUS,player,false))
	check("north roof edge has physical boundary",not game.world.motion_clear(Vector2(2640,1880),Vector2(2640,1950),player))
	game.map_camera.center_on(Vector2(2610,2190));await shot("runtime-exterior")
	# Walk the real actor through the aperture rather than teleport into a room.
	var crossed:=true
	for i in range(40):
		var movement: Vector2=game.world.move_actor(player,Vector2(4,0))
		if movement.x<3.9:crossed=false
		game.room_visibility.tick(.02,true)
		if OUT.contains("west-recess") and i==22:
			check("threshold shows entrance before roof disappears",roof.visible and game.room_visibility.active_id!="campus-kiosk")
			await shot("runtime-threshold")
	check("actual movement crosses west door",crossed and player.position.x>=2420-1)
	check("entering hides roof",game.room_visibility.active_id=="campus-kiosk" and not roof.visible)
	game.presentation.tick(0)
	var shell=game.presentation.volumes.filter(func(v):return v.kind=="fixture" and v.world.fixtures[v.wall_index].id=="kiosk-shell")[0]
	var canopy=game.presentation.volumes.filter(func(v):return v.kind=="fixture" and v.world.fixtures[v.wall_index].id=="kiosk-front-canopy")[0]
	var shelf=game.presentation.volumes.filter(func(v):return v.kind=="fixture" and v.world.fixtures[v.wall_index].id=="kiosk-back-shelf")[0]
	if OUT.contains("west-recess"):
		var north=game.presentation.volumes.filter(func(v):return v.kind=="fixture" and v.world.fixtures[v.wall_index].id=="kiosk-entry-north-return")[0]
		var south=game.presentation.volumes.filter(func(v):return v.kind=="fixture" and v.world.fixtures[v.wall_index].id=="kiosk-side-entry")[0]
		var depth=preload("res://scripts/presentation/world_depth.gd").for_y(player.position.y,game.world.bounds.end.y)
		check("north return stays behind entering actor",north.z_index<depth)
		check("south return sorts in front of actor",south.z_index>depth)
		check("no detached portal outside side wall",north.footprint.position.x>=roof.roof.position.x and south.footprint.position.x>=roof.roof.position.x)
		check("roof recess limited to entrance depth",is_equal_approx(roof.cutouts[0].size.x,112))
		check("front awning clears west entrance",canopy.display_rect.position.x>=roof.cutouts[0].end.x-1)
		for y in [2110.0,2150.0,2190.0]:
			check("entrance clearance at "+str(y),game.world.motion_clear(Vector2(2280,y),Vector2(2390,y),player))
	if OUT.contains("open-entry-d"):
		var portal=game.presentation.volumes.filter(func(v):return v.kind=="fixture" and v.world.fixtures[v.wall_index].id=="kiosk-side-entry")[0]
		check("entry sign stays above canopy depth bucket",portal.z_index>canopy.z_index)
		var asset: Dictionary=portal.definitions[portal.prop_id()]
		var original_image:=Image.load_from_file(asset.texture)
		var crop: Array=asset.region
		check("open door aperture is alpha transparent",original_image.get_pixel(int(crop[0]+crop[2]*.45),int(crop[1]+crop[3]*.55)).a<.01)
	check("shell artwork matches physical perimeter",shell.display_rect.is_equal_approx(Rect2(2320,1920,640,340)))
	check("stock shelf keeps authored width",is_equal_approx(shelf.display_rect.size.x,350))
	check("inside walls stay visible",shell.visible)
	check("inside removes overhanging sign canopy",not canopy.visible)
	check("inside goods shelf revealed",shelf.visible)
	check("cashier remains single and visible",game.items_view.merchant_visuals.has("campus_kiosk") and game.items_view.merchant_visuals.campus_kiosk.visible)
	await shot("runtime-interior")
	player.position=Vector2(2820,2210);game.room_visibility.tick(0,true);await shot("runtime-interior-east")
	check("inside can route back to west lane",not game.world.find_path(player.position,entrance,player,false,true).is_empty())
	player.position=entrance;game.room_visibility.tick(0,true);game.presentation.tick(0)
	check("leaving restores roof and canopy",roof.visible and canopy.visible)
	check("shelf visibility supports recessed entrance",shelf.visible if OUT.contains("west-recess") else not shelf.visible)
	player.position=Vector2(2640,2470);game.room_visibility.tick(0,true)
	check("front purchase still allowed",game.trade.reason(0,"campus_kiosk").is_empty())
	game.inventory.wallet=100;var item: String=game.trade.merchants.campus_kiosk.stock[0]
	check("front purchase still commits",game.trade.try_buy(0,"campus_kiosk",item).ok and game.inventory.wallet==96)
	game.queue_free();await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor);await frame();await frame()
	editor.canvas.zoom=.70;editor.canvas.origin=editor.canvas.size/2-Vector2(2610,2190)*.70;editor.canvas.queue_redraw();await shot("editor")
	check("tests preserve saved map",stamp==FileAccess.get_sha256("res://data/rooms/r04.json"))
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}));quit(0 if failed.is_empty() else 1)
