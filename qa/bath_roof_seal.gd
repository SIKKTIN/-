extends SceneTree
const OUT="res://docs/art/bath-roof-seal-v1/"
const Geometry=preload("res://scripts/presentation/roof_geometry.gd")
var game
var checks={}
func _initialize():
	create_timer(120).timeout.connect(func():quit(124))
	call_deferred("run")
func raw(path: String) -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(path))
func check(label: String,ok: bool):
	checks[label]=ok
	if not ok:print("FAIL: ",label)
func frame():
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func shot(name: String):
	await frame();await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+name+".png")
func stand(point: Vector2):
	game.actors[0].position=point;game.actors[0].moved_this_frame=false
	game.orders.clear();game.skills.clear_all()
	game.room_visibility.tick(0,true);game.resident_staff.tick(0);game.presentation.tick(0)
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://bath-roof-seal-qa.cfg")
	root.size=Vector2i(1280,960);root.content_scale_size=root.size
	var before=raw(OUT+"before.json");var after=raw(OUT+"after.json")
	for key in before:
		if key!="visibility_rooms":check("map field preserved "+str(key),before[key]==after[key])
	check("other room roofs preserved",before.visibility_rooms.filter(func(r):return r.id!="bath")==after.visibility_rooms.filter(func(r):return r.id!="bath"))
	var old_spec: Dictionary=before.visibility_rooms.filter(func(r):return r.id=="bath")[0].duplicate(true)
	var new_spec: Dictionary=after.visibility_rooms.filter(func(r):return r.id=="bath")[0].duplicate(true)
	new_spec.erase("roof_sealed")
	check("bath interior region and style unchanged",new_spec==old_spec)
	game=load("res://scenes/main.tscn").instantiate();game.room_id="r04";root.add_child(game);await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.get_node("HUD").hide()
	game.guard.position=Vector2(3000,1500);game.dog.position=Vector2(3100,1500)
	var room: Dictionary=game.room_visibility.rooms.filter(func(r):return r.id=="bath")[0]
	var cover=game.room_visibility.covers.filter(func(c):return c.room.id=="bath")[0]
	var original: Dictionary=room.duplicate(true);original.erase("roof_sealed")
	var original_plan=Geometry.plan(game.world,original)
	check("physical roof envelope unchanged",room.roof_plan.roof==original_plan.roof)
	check("original door ports retained",room.roof_plan.ports==original_plan.ports and not room.roof_plan.ports.is_empty())
	check("collision and wall-trim cuts unchanged",room.roof_plan.cutouts==original_plan.cutouts)
	check("roof has one complete rectangle",cover.panels.size()==1 and room.roof_plan.membrane_cutouts.is_empty())
	var expected:=Rect2(cover.roof.position+Vector2(20,20),cover.roof.size-Vector2(40,20))
	check("roof fills exactly inside north and side coping",cover.panels[0]==expected)
	var fixture: Dictionary=game.world.fixtures.filter(func(f):return f.id=="campus-bath")[0]
	var center: Vector2=fixture.rect.get_center()
	var outside:=center+Vector2(0,-160);var inside:=center+Vector2(0,130)
	var player=game.actors[0]
	check("whole body enters and exits existing door",game.world.motion_clear(outside,inside,player,false,true) and game.world.motion_clear(inside,outside,player,false,true))
	stand(outside)
	check("outside roof fully opaque",cover.visible and cover.modulate.a==1)
	game.map_camera.zoom=Vector2(1.05,1.05)
	game.map_camera.position=Vector2(room.area.get_center().x,cover.roof.get_center().y+30)-Vector2(root.size)/1.05/2
	game.map_camera.force_update_scroll()
	await shot("runtime-exterior")
	check("former north-door notch now covered",cover.panels[0].has_point(center+Vector2(0,-60)))
	if DisplayServer.get_name()!="headless":
		var pixels: Image=root.get_texture().get_image();var transform: Transform2D=root.get_canvas_transform()
		var colors=[];var filled=0
		for p in [center+Vector2(-35,-60),center+Vector2(0,-60),center+Vector2(35,-60)]:
			var color:=pixels.get_pixelv(Vector2i(transform*p));colors.append(color.to_html(false))
			if color.r>.4 and color.g>.4 and absf(color.r-color.g)<.08:filled+=1
		check("rendered roof covers all three entrance-gap samples",filled==3)
		FileAccess.open(OUT+"roof-pixels.json",FileAccess.WRITE).store_string(JSON.stringify(colors,"\t"))
	var crossed=true
	for i in range(145):
		if game.world.move_actor(player,Vector2(0,2)).y<1.9:crossed=false
		game.room_visibility.tick(.02,true)
	check("real entry motion unchanged",crossed and player.position.distance_to(inside)<1)
	game.resident_staff.tick(0)
	game.presentation.tick(0)
	check("inside hides complete roof",not cover.visible and cover.modulate.a==0 and game.room_visibility.active_id=="bath")
	await shot("runtime-interior")
	var bath=game.bath_service
	stand(bath.counter_point());game.inventory.wallet=10
	check("recharge still works inside",bath.try_recharge(0,10).ok)
	bath.refresh_stations();check("six shower stations preserved",bath.stations.size()==6)
	for id in bath.stations:
		var point: Vector2=bath.station_point(id)
		check("shower aisle reachable "+id,not game.world.find_path(inside,point,player,false,true).is_empty())
		stand(point);check("shower service works "+id,bath.start_shower(0,id).ok);bath.cancel(0)
	stand(inside)
	for i in range(145):
		if game.world.move_actor(player,Vector2(0,-2)).y> -1.9:crossed=false
		game.room_visibility.tick(.02,true)
	check("real exit motion unchanged",crossed and player.position.distance_to(outside)<1)
	check("exit restores sealed roof",cover.visible and cover.modulate.a==1)
	game.queue_free();await frame()
	var doc=load("res://scripts/editor/map_document.gd").new()
	check("saved map opens",doc.open_file("res://data/rooms/r04.json"))
	check("saved map validates",doc.validate().errors.is_empty())
	var scratch="res://data/rooms/qa_bath_roof_%d.json" % Time.get_ticks_usec()
	check("roof flag saves in editor",doc.save_file(scratch,true))
	var reloaded=load("res://scripts/editor/map_document.gd").new();reloaded.open_file(scratch)
	check("roof flag survives reload",reloaded.data.visibility_rooms.any(func(r):return r.id=="bath" and r.get("roof_sealed",false)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"count":checks.size(),"checks":checks,"failed":failed},"\t"))
	print("Bath roof seal: ",checks.size()," checks; failures=",failed)
	quit(0 if failed.is_empty() else 1)
