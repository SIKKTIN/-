extends SceneTree
const OUT="res://docs/art/laundry-roof-seal-v1/"
const Geometry=preload("res://scripts/presentation/roof_geometry.gd")
var game
var checks={}
func _initialize():
	create_timer(90).timeout.connect(func():quit(124))
	call_deferred("run")
func check(label: String,ok: bool):
	checks[label]=ok
	if not ok:print("FAIL: ",label)
func frame():
	await process_frame
	await RenderingServer.frame_post_draw
func stand(point: Vector2):
	game.actors[0].position=point
	game.orders.clear();game.skills.clear_all()
	game.room_visibility.tick(0,true);game.presentation.tick(0)
func shot(name: String):
	await frame();await frame()
	root.get_texture().get_image().save_png(OUT+name+".png")
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://laundry-roof-seal-qa.cfg")
	root.size=Vector2i(1400,960);root.content_scale_size=root.size
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"before.json"))
	var after: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"after.json"))
	var normalized: Dictionary=after.duplicate(true)
	normalized.visibility_rooms.filter(func(r):return r.id=="laundry")[0].erase("roof_sealed")
	check("only laundry roof flag changed",normalized==before)
	var map_sha=FileAccess.get_sha256("res://data/rooms/r04.json")
	game=load("res://scenes/main.tscn").instantiate();game.room_id="r04";root.add_child(game);await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.get_node("HUD").hide()
	game.guard.position=Vector2(3000,1500);game.dog.position=Vector2(3100,1500)
	# Keep unrelated NPC/crate traffic out of the isolated doorway motion check.
	for actor in game.world.actors:
		if actor!=game.actors[0]:actor.position=Vector2(3000,1200)
	game.world.crate.position=Vector2(3100,1200)
	var room: Dictionary=game.room_visibility.rooms.filter(func(r):return r.id=="laundry")[0]
	var cover=game.room_visibility.covers.filter(func(c):return c.room.id=="laundry")[0]
	var original: Dictionary=room.duplicate(true);original.erase("roof_sealed")
	var plan: Dictionary=Geometry.plan(game.world,original)
	check("door ports unchanged",room.roof_plan.ports==plan.ports)
	check("wall edge cuts unchanged",room.roof_plan.cutouts==plan.cutouts)
	check("roof envelope unchanged",room.roof_plan.roof==plan.roof)
	check("one complete roof panel",cover.panels.size()==1 and room.roof_plan.membrane_cutouts.is_empty())
	var gate: Dictionary=game.world.access_by_id("cafeteria-rear")
	var center: Vector2=gate.rect.get_center()
	var outside:=center+Vector2(0,-180);var inside:=center+Vector2(0,140)
	game.map_camera.zoom=Vector2(.92,.92)
	game.map_camera.position=Vector2(room.area.get_center().x,cover.roof.get_center().y)-Vector2(root.size)/.92/2
	game.map_camera.force_update_scroll()
	stand(outside)
	check("outside roof opaque",cover.visible and cover.modulate.a==1)
	check("door face lies under roof",cover.panels[0].has_point(center+Vector2(0,-60)))
	var doorway=game.room_visibility.doorways.door_by_id["cafeteria-rear"]
	check("roof draws above north door",cover.z_index>doorway.z_index)
	game.world.set_access_closed("cafeteria-rear",true);game.room_visibility.doorways.tick()
	await shot("runtime-exterior-closed")
	var closed: Image=root.get_texture().get_image()
	check("closed door still blocks movement",not game.world.motion_clear(outside,inside,game.actors[0],false,true))
	game.schedule.clock_elapsed=(750.0-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.tick(false);game.room_access.tick()
	game.world.set_access_closed("cafeteria-rear",false);game.room_visibility.doorways.tick()
	await shot("runtime-exterior-open")
	var opened: Image=root.get_texture().get_image()
	var transform: Transform2D=root.get_canvas_transform()
	var samples=[]
	for dx in [-50,0,50]:
		var pos:=Vector2i(transform*(center+Vector2(dx,-60)))
		check("closed and open door hidden beneath roof "+str(dx),closed.get_pixelv(pos).is_equal_approx(opened.get_pixelv(pos)))
		samples.append({"point":[pos.x,pos.y],"covered":opened.get_pixelv(pos).to_html(false)})
	cover.hide();await frame();await frame()
	var exposed: Image=root.get_texture().get_image()
	for sample in samples:
		var color:=exposed.get_pixelv(Vector2i(sample.point[0],sample.point[1]))
		check("roof visibly masks entrance "+str(sample.point),color.to_html(false)!=sample.covered)
	cover.show()
	check("open door allows body both ways",game.world.motion_clear(outside,inside,game.actors[0],false,true) and game.world.motion_clear(inside,outside,game.actors[0],false,true))
	var player=game.actors[0];var crossed=true
	for i in range(160):
		if game.world.move_actor(player,Vector2(0,2)).y<1.9:crossed=false
		game.room_visibility.tick(.02,true)
	check("real entry movement passes",crossed and player.position.distance_to(inside)<1)
	check("inside roof hidden",game.room_visibility.active_id=="laundry" and not cover.visible)
	game.presentation.tick(0);await shot("runtime-interior")
	for i in range(160):
		if game.world.move_actor(player,Vector2(0,-2)).y> -1.9:crossed=false
		game.room_visibility.tick(.02,true)
	check("real exit movement passes",crossed and player.position.distance_to(outside)<1)
	check("exit restores roof",cover.visible and cover.modulate.a==1)
	check("door opening hours unchanged",gate.hours==before.access_doors.filter(func(d):return d.id=="cafeteria-rear")[0].hours)
	check("bath remains sealed",game.room_visibility.rooms.any(func(r):return r.id=="bath" and r.get("roof_sealed",false)))
	game.queue_free();await frame()
	var doc=load("res://scripts/editor/map_document.gd").new()
	check("editor map opens",doc.open_file("res://data/rooms/r04.json"))
	check("map validation passes",doc.validate().errors.is_empty())
	check("QA does not modify saved map",map_sha==FileAccess.get_sha256("res://data/rooms/r04.json"))
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"count":checks.size(),"checks":checks,"failed":failed},"\t"))
	print("Laundry roof seal: ",checks.size()," checks; failures=",failed)
	quit(0 if failed.is_empty() else 1)
