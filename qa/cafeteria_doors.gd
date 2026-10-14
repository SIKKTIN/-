extends SceneTree
const OUT="res://docs/art/cafeteria-doors-v3/"
const Geometry=preload("res://scripts/presentation/doorway_geometry.gd")
var checks={}
var game
func _initialize():
	create_timer(120).timeout.connect(func():quit(124));call_deferred("run")
func raw(path: String) -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(path))
func check(label: String,ok: bool):
	checks[label]=ok
	if not ok:print("FAIL: ",label)
func frame():
	await process_frame;await RenderingServer.frame_post_draw
func shot(name: String):
	await frame();await frame();root.get_texture().get_image().save_png(OUT+name+".png")
func stand(point: Vector2):
	game.actors[0].position=point;game.orders.clear();game.skills.clear_all()
	game.room_visibility.tick(0,true);game.presentation.tick(0)
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://cafeteria-doors-qa.cfg")
	root.size=Vector2i(1400,1000);root.content_scale_size=root.size
	var before=raw(OUT+"map-before.json");var after=raw(OUT+"map-after.json");var reg=raw(OUT+"registration.json")
	for key in before:
		if key not in ["access_doors","fixtures","walls","architecture"]:check("unrelated map field preserved "+str(key),before[key]==after[key])
	var ignored: Array=reg.changed_fixture_ids+reg.removed_fixture_ids
	check("all other fixtures preserved",before.fixtures.filter(func(f):return f.id not in ignored)==after.fixtures.filter(func(f):return f.id not in ignored))
	for gate in after.access_doors:
		var old: Dictionary=before.access_doors.filter(func(g):return g.id==gate.id)[0]
		var normalized: Dictionary=gate.duplicate(true)
		if gate.id in reg.gate_ids:
			normalized.asset_id=old.asset_id
			if old.has("rotation_door_visual_rect"):normalized.rotation_door_visual_rect=old.rotation_door_visual_rect
			else:normalized.erase("rotation_door_visual_rect")
		check("gate permissions and foot line preserved "+gate.id,normalized==old)
	for i in reg.wall_indices:
		var old_surface: Dictionary=before.architecture.wall_surfaces.filter(func(s):return int(s.wall_index)==int(i))[0]
		var new_surface: Dictionary=after.architecture.wall_surfaces.filter(func(s):return int(s.wall_index)==int(i))[0]
		var original: Array=before.walls[int(i)];var changed: Array=after.walls[int(i)]
		var original_solids=[];var changed_solids=[]
		for p in old_surface.collision_parts:original_solids.append([original[0]+p[0],original[1]+p[1],p[2],p[3]])
		for p in new_surface.collision_parts:changed_solids.append([changed[0]+p[0],changed[1]+p[1],p[2],p[3]])
		check("wall solid foot line preserved "+str(i),original_solids==changed_solids)
	game=load("res://scenes/main.tscn").instantiate();game.room_id="r04";root.add_child(game);await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.get_node("HUD").hide()
	game.world.admission_filter=Callable()
	var player=game.actors[0]
	for actor in game.world.actors:
		if actor!=player:actor.position=Vector2(3000,1200)
	game.world.crate.position=Vector2(3100,1200)
	var cover=game.room_visibility.covers.filter(func(c):return c.room.id=="canteen")[0]
	var reference: Dictionary=Geometry.art_spec(game.world.access_by_id("energy-entry"))
	for id in reg.gate_ids:
		var gate: Dictionary=game.world.access_by_id(id)
		var door=game.room_visibility.doorways.by_id(id)
		var point: Vector2=gate.rect.get_center()
		check("front uses equipment frame recipe "+id,door.gate.door_open_patches==reference.door_open_patches and door.gate.door_closed_patches==reference.door_closed_patches)
		check("frame bottom aligned to threshold "+id,is_equal_approx(door.visual_rect.end.y,gate.rect.end.y))
		check("north frame aligned to coping "+id,door.visual_rect.position.y==1820 if id!="cafeteria-south" else door.visual_rect.position.y==2400)
		var from:=point-Vector2(0,60 if id=="cafeteria-south" else 160);var to:=point+Vector2(0,150)
		stand(to);game.world.set_access_closed(id,true);game.room_visibility.doorways.tick(true)
		check("closed door blocks body "+id,not game.world.motion_clear(from,to,player,false,true) and door.closed)
		game.world.set_access_closed(id,false);game.room_visibility.doorways.tick(true)
		check("open door passes both ways "+id,game.world.motion_clear(from,to,player,false,true) and game.world.motion_clear(to,from,player,false,true))
		check("open door navigation finds route "+id,not game.world.find_path(from,to,player,false,true).is_empty())
		stand(point);game.world.set_access_closed(id,true)
		check("occupied doorway prevents closure "+id,not gate.closed)
		stand(from)
		var passed=true
		for i in range(roundi((to.y-from.y)/2)):
			if game.world.move_actor(player,Vector2(0,2)).y<1.9:passed=false
			game.room_visibility.tick(.02,true)
		check("actual whole-body movement passes "+id,passed and player.position.distance_to(to)<1)
		for x in [-65,65]:
			var p:=Vector2(point.x+x,gate.rect.end.y+5)
			stand(p)
			check("person in front sorts above frame "+id+str(x),player.z_index>=door.z_index)
	var side=game.room_visibility.doorways.by_id("fixture:campus-life-west-meal")
	var warehouse=game.room_visibility.doorways.by_id("fixture:campus-warehouse-west")
	check("side uses warehouse assembly and rotation",side.gate.rotation_quarters==warehouse.gate.rotation_quarters and side.gate.door_open_patches==warehouse.gate.door_open_patches)
	check("west entrance keeps free access",side.style=="free" and not side.closed)
	var candidates=[]
	for y in range(2020,2161,5):
		if game.world.motion_clear(Vector2(810,y),Vector2(1070,y),player,false,true):candidates.append(y)
	check("side entrance has body-safe path",not candidates.is_empty())
	check("side route adjusts to clear leaf opening",not game.world.find_path(Vector2(810,2090),Vector2(1070,2090),player,false,true).is_empty())
	if not candidates.is_empty():
		var y: float=candidates[candidates.size()/2];stand(Vector2(810,y));var passed=true
		for i in range(130):
			if game.world.move_actor(player,Vector2(2,0)).x<1.9:passed=false
			game.room_visibility.tick(.02,true)
		check("side real motion crosses both jambs",passed and player.position.distance_to(Vector2(1070,y))<1)
		check("side entry reveals canteen",game.room_visibility.active_id=="canteen" and not cover.visible)
	game.map_camera.zoom=Vector2.ONE*.92;game.map_camera.center_on(Vector2(1500,2130));game.map_camera.force_update_scroll()
	stand(Vector2(1500,2180))
	for id in reg.gate_ids:game.world.set_access_closed(id,true)
	game.room_visibility.doorways.tick(true);await shot("interior-closed")
	for id in reg.gate_ids:game.world.set_access_closed(id,false)
	game.room_visibility.doorways.tick(true);await shot("interior-open")
	stand(Vector2(820,1740));check("outside roof opaque",cover.visible and cover.modulate.a==1)
	for id in reg.gate_ids:game.world.set_access_closed(id,true)
	game.room_visibility.doorways.tick(true);await shot("exterior-closed")
	for id in reg.gate_ids:game.world.set_access_closed(id,false)
	game.room_visibility.doorways.tick(true);await shot("exterior-open")
	game.queue_free();await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor);await frame()
	editor.open_now("res://data/rooms/r04.json");await frame()
	check("saved map validates",editor.document.validate().errors.is_empty())
	editor.canvas.zoom=.7;editor.canvas.origin=editor.canvas.size/2-Vector2(1500,2150)*.7;editor.canvas.queue_redraw();await shot("editor")
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"count":checks.size(),"failed":failed,"checks":checks,"side_walk_y":candidates},"\t"))
	print("Cafeteria doors: ",checks.size()," checks; failures=",failed)
	quit(0 if failed.is_empty() else 1)
