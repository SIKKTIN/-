extends SceneTree
var OUT := OS.get_environment("KIOSK_QA_OUTPUT") if not OS.get_environment("KIOSK_QA_OUTPUT").is_empty() else "res://docs/art/campus-kiosk-front-entry/"
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
func kiosk_data(data: Dictionary) -> Dictionary:
	var result={}
	for group in ["fixtures","visibility_rooms","zones","floor_regions","merchants"]:
		var selected={}
		for item in data.get(group,[]):
			if str(item.get("id","")).begins_with("kiosk-") or item.get("id","") in ["campus-kiosk","campus_kiosk"]:selected[item.id]=item
		result[group]=selected
	return result
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://kiosk-front-entry-qa.cfg")
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var stamp:=FileAccess.get_sha256("res://data/rooms/r04.json")
	var initial_saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/rooms/r04.json"))
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"before.json"))
	var after: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"after.json"))
	var registration: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"registration.json"))
	for key in before:
		if key not in ["fixtures","visibility_rooms","zones","merchants","floor_regions"]:check("preserved "+key,before[key]==after[key])
	check("other fixtures preserved",before.fixtures.filter(func(f):return not str(f.id).begins_with("kiosk-"))==after.fixtures.filter(func(f):return not str(f.id).begins_with("kiosk-")))
	check("other rooms preserved",before.visibility_rooms.filter(func(r):return r.id!="campus-kiosk")==after.visibility_rooms.filter(func(r):return r.id!="campus-kiosk"))
	check("other zones preserved",before.zones.filter(func(r):return r.id!="campus-kiosk")==after.zones.filter(func(r):return r.id!="campus-kiosk"))
	check("other floors preserved",before.floor_regions.filter(func(f):return not str(f.id).begins_with("kiosk-"))==after.floor_regions.filter(func(f):return not str(f.id).begins_with("kiosk-")))
	check("other merchants preserved",before.merchants.filter(func(m):return m.id!="campus_kiosk")==after.merchants.filter(func(m):return m.id!="campus_kiosk"))
	check("single vendor",after.merchants.filter(func(m):return m.id=="campus_kiosk").size()==1)
	check("same stock and prices",before.merchants.filter(func(m):return m.id=="campus_kiosk")[0].stock==after.merchants.filter(func(m):return m.id=="campus_kiosk")[0].stock)
	check("side doorway removed",not after.fixtures.any(func(f):return f.id in ["kiosk-side-entry","kiosk-entry-north-return"]))
	if OUT.contains("shell-repair"):
		check("only shell art changed",before.fixtures.filter(func(f):return f.id!="kiosk-shell")==after.fixtures.filter(func(f):return f.id!="kiosk-shell"))
		for key in before:
			if key!="fixtures":check("shell repair preserves "+key,before[key]==after[key])
		var shell_before: Dictionary=before.fixtures.filter(func(f):return f.id=="kiosk-shell")[0].duplicate(true)
		var shell_after: Dictionary=after.fixtures.filter(func(f):return f.id=="kiosk-shell")[0].duplicate(true)
		shell_before.erase("asset_id");shell_after.erase("asset_id")
		check("shell collision and placement unchanged",shell_before==shell_after)
	var catalog=preload("res://scripts/editor/editor_catalog.gd").new()
	for entry in registration.assets:check(str(entry.key)+" original PNG unchanged",FileAccess.get_sha256("res://"+entry.path)==entry.sha256)
	for id in registration.definition_ids:check(str(id)+" editor available",catalog.entries.any(func(e):return e.id==id))
	var doc=preload("res://scripts/editor/map_document.gd").new()
	check("saved map opens",doc.open_file("res://data/rooms/r04.json"))
	check("saved map validates",doc.validate().errors.is_empty())
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.get_node("HUD").hide();game.world.admission_filter=Callable()
	var player=game.actors[0]
	var origin:=Vector2(registration.origin[0],registration.origin[1])
	var entrance:=Vector2(registration.door_center,origin.y+520)
	var interior:=Vector2(entrance.x,origin.y+220)
	player.position=entrance;game.room_visibility.tick(0,true)
	var roof=game.room_visibility.covers.filter(func(c):return c.room.id=="campus-kiosk")[0]
	var front=game.presentation.volumes.filter(func(v):return v.kind=="fixture" and v.world.fixtures[v.wall_index].id=="kiosk-front-counter")[0]
	var canopy=game.presentation.volumes.filter(func(v):return v.kind=="fixture" and v.world.fixtures[v.wall_index].id=="kiosk-front-canopy")[0]
	var island=game.presentation.volumes.filter(func(v):return v.kind=="fixture" and v.world.fixtures[v.wall_index].id=="kiosk-goods-island")[0]
	check("complete rectangular roof",roof.cutouts.is_empty() and roof.panels.size()==1 and roof.roof==Rect2(origin,Vector2(640,340)))
	check("outside roof and awning visible",roof.visible and canopy.visible)
	check("awning is above roof",canopy.z_index>roof.z_index)
	check("outside stock island hidden",not island.visible)
	check("exterior window vendor visible",game.items_view.merchant_visuals.campus_kiosk.visible)
	check("front door artwork matches geometry",front.display_rect==Rect2(origin+Vector2(0,340),Vector2(640,160)))
	for p in [entrance,entrance+Vector2(0,-40),entrance+Vector2(0,-120),interior,origin+Vector2(510,300)]:
		check("walkable "+str(p),game.world.can_place_circle(p,game.ACTOR_RADIUS,player,false))
		check("door route to "+str(p),not game.world.find_path(entrance,p,player,false,true).is_empty())
	for p in [origin+Vector2(20,230),origin+Vector2(20,290),origin+Vector2(320,20),origin+Vector2(620,200),origin+Vector2(45,440),origin+Vector2(350,430),origin+Vector2(365,300)]:
		check("boundary blocks "+str(p),not game.world.can_place_circle(p,game.ACTOR_RADIUS,player,false))
	game.map_camera.center_on(origin+Vector2(290,270));await shot("runtime-exterior")
	var crossed:=true
	for i in range(75):
		var movement: Vector2=game.world.move_actor(player,Vector2(0,-4))
		if movement.y> -3.9:crossed=false
		game.room_visibility.tick(.02,true)
		if i==8:
			check("door step reveals interior",game.room_visibility.active_id=="campus-kiosk" and not roof.visible)
			await shot("runtime-threshold")
	check("real actor crosses front door",crossed and player.position.distance_to(interior)<1)
	check("inside roof and awning hidden",game.room_visibility.active_id=="campus-kiosk" and not roof.visible and not canopy.visible)
	check("inside goods island visible",island.visible)
	check("inside retains vendor",game.items_view.merchant_visuals.campus_kiosk.visible)
	await shot("runtime-interior")
	if OUT.contains("shell-repair"):
		var shell=game.presentation.volumes.filter(func(v):return v.kind=="fixture" and v.world.fixtures[v.wall_index].id=="kiosk-shell")[0]
		check("latest continuous shell is actually rendered",shell.prop_id()=="kiosk_continuous_shell_v6")
		check("wall shell rendered at authored dimensions",shell.display_rect==Rect2(origin,Vector2(640,340)))
		var definition: Dictionary=shell.definitions[shell.prop_id()]
		var texture: Texture2D=game.world.art_textures[shell.prop_id()]
		check("wall shell texture bounded",maxi(texture.get_width(),texture.get_height())<=1024)
		check("old side-door artwork is no longer sampled",str(definition.texture).ends_with("continuous-shell-v6.png"))
		if DisplayServer.get_name()!="headless":
			var samples: Dictionary={}
			for zoom in [.55,1.0,1.4]:
				game.map_camera.zoom=Vector2(zoom,zoom)
				game.map_camera.position=origin+Vector2(320,250)-Vector2(root.size)/zoom/2
				game.map_camera.force_update_scroll()
				await frame();await frame()
				var pixels: Image=root.get_texture().get_image()
				var transform: Transform2D=root.get_canvas_transform()
				for side in ["west","east"]:
					var cream_rows:=0;var colors=[]
					for offset in [130,150,170,190,210,230,250,270,290]:
						var point:=Vector2i(transform*(origin+Vector2(18 if side=="west" else 622,offset)))
						var color:=pixels.get_pixelv(point)
						colors.append([offset,color.to_html(false)])
						if color.r>.5 and color.g>.45 and color.b>.3 and color.r>color.b:cream_rows+=1
					check("continuous cream wall without old green gap "+side+" zoom "+str(zoom),cream_rows>=8)
					samples[side+"_"+str(zoom)]={"cream_rows":cream_rows,"samples":colors}
				await shot("runtime-walls-"+str(zoom).replace(".","-"))
			FileAccess.open(OUT+"wall-pixel-checks.json",FileAccess.WRITE).store_string(JSON.stringify(samples,"\t"))
			game.map_camera.zoom=Vector2.ONE;game.map_camera.center_on(origin+Vector2(290,270));game.map_camera.force_update_scroll()
	check("route from island side to exit",not game.world.find_path(origin+Vector2(510,300),entrance,player,false,true).is_empty())
	var left: float=registration.door_clearance[0];var right: float=registration.door_clearance[1]
	for x in [left+20,(left+right)/2,right-20]:check("jamb clearance "+str(x),game.world.motion_clear(Vector2(x,origin.y+520),Vector2(x,origin.y+400),player))
	for i in range(75):
		var movement: Vector2=game.world.move_actor(player,Vector2(0,4))
		if movement.y<3.9:crossed=false
		game.room_visibility.tick(.02,true)
	game.presentation.tick(0)
	check("real actor exits front door",crossed and player.position.distance_to(entrance)<1)
	check("exit restores roof and awning",roof.visible and canopy.visible)
	var service:=Vector2(registration.service_point[0],registration.service_point[1])
	check("shop approach is physically walkable",game.world.can_place_circle(service,game.ACTOR_RADIUS,player,false))
	check("shop can be reached from door",not game.world.find_path(entrance,service,player,false,true).is_empty())
	player.position=service;game.room_visibility.tick(0,true)
	check("window purchase allowed",game.trade.reason(0,"campus_kiosk").is_empty())
	game.inventory.wallet=100;var item: String=game.trade.merchants.campus_kiosk.stock[0]
	check("purchase commits correct price",game.trade.try_buy(0,"campus_kiosk",item).ok and game.inventory.wallet==96)
	game.queue_free();await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor);await frame();await frame()
	editor.canvas.zoom=.70;editor.canvas.origin=editor.canvas.size/2-(origin+Vector2(290,270))*.70;editor.canvas.queue_redraw();await shot("editor")
	if OUT.contains("shell-repair"):
		var final_saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/rooms/r04.json"))
		check("QA preserves latest saved kiosk data",kiosk_data(initial_saved)==kiosk_data(final_saved))
		var other_changes: Array=[]
		for key in initial_saved:
			if initial_saved[key]!=final_saved.get(key):other_changes.append(key)
		FileAccess.open(OUT+"continuation-map-audit.json",FileAccess.WRITE).store_string(JSON.stringify({"initial_sha256":stamp,"final_sha256":FileAccess.get_sha256("res://data/rooms/r04.json"),"concurrent_changed_fields":other_changes,"kiosk_unchanged":kiosk_data(initial_saved)==kiosk_data(final_saved)},"\t"))
	else:check("QA preserves latest saved map",stamp==FileAccess.get_sha256("res://data/rooms/r04.json"))
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}));quit(0 if failed.is_empty() else 1)
