extends SceneTree
const OUT := "res://docs/art/tool-room-redesign/"
var checks := {}
func check(label: String, passed: bool):checks[label]=passed
func _initialize():call_deferred("run")
func frame():
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func shot(name: String):
	await frame();await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+name+".png")
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://tool-room-qa.cfg")
	root.size=Vector2i(1280,900);root.content_scale_size=root.size
	var saved:=FileAccess.get_sha256("res://data/rooms/r04.json")
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"registration-input.json"))
	var after: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"registration-output.json"))
	var registration: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"asset-registration.json"))
	for key in before:
		if key not in ["fixtures","visibility_rooms","zones","lamps","floor_regions","architecture","access_doors","ground_details"]:check("unchanged "+key,before[key]==after[key])
	check("unrelated furniture preserved",before.fixtures.filter(func(f):return f.id not in registration.removed_fixture_ids and not str(f.id).begins_with("campus-tools-"))==after.fixtures.filter(func(f):return not str(f.id).begins_with("toolroom-") and not str(f.id).begins_with("campus-tools-")))
	check("other rooms unchanged",before.visibility_rooms.filter(func(r):return r.id!="tools")==after.visibility_rooms.filter(func(r):return r.id!="tools"))
	var unchanged_gates := true
	for old in before.access_doors:
		var current: Dictionary=after.access_doors.filter(func(g):return g.id==old.id)[0]
		for key in old:unchanged_gates=unchanged_gates and old[key]==current[key]
	check("all prior gate positions and rules preserved",unchanged_gates)
	var unchanged_collisions := true
	var unchanged_other_walls := true
	for old in before.architecture.wall_surfaces:
		var current: Dictionary=after.architecture.wall_surfaces.filter(func(s):return s.wall_index==old.wall_index)[0]
		for key in old:
			if key!="grid_tile_asset":unchanged_collisions=unchanged_collisions and old[key]==current[key]
		if old.wall_index not in registration.wall_indices:unchanged_other_walls=unchanged_other_walls and old==current
	check("all wall collision shapes preserved",unchanged_collisions)
	check("unrelated wall art unchanged",unchanged_other_walls)
	var polish_before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"polish-input.json"))
	var polish_after: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"polish-output.json"))
	check("polish preserves unrelated fixtures",polish_before.fixtures.filter(func(f):return not str(f.id).begins_with("toolroom-"))==polish_after.fixtures.filter(func(f):return not str(f.id).begins_with("toolroom-")))
	for key in polish_before:
		if key not in ["fixtures","ground_details"]:check("polish preserves "+key,polish_before[key]==polish_after[key])
	var catalog=preload("res://scripts/editor/editor_catalog.gd").new()
	var assets=preload("res://scripts/presentation/prop_catalog.gd").assets()
	for entry in registration.assets:check(str(entry.key)+" original preserved",FileAccess.get_sha256("res://"+entry.path)==entry.sha256)
	for id in registration.definition_ids:
		if not assets[id].get("editor_hidden",false) and assets[id].get("render_mode","")!="architecture_material":check(str(id)+" editor registered",catalog.entries.any(func(e):return e.id==id))
	var doc=preload("res://scripts/editor/map_document.gd").new();check("editor map opens",doc.open_file("res://data/rooms/r04.json"));check("map validates",doc.validate().errors.is_empty())
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.get_node("HUD").hide();game.world.admission_filter=Callable()
	var player=game.actors[0]
	var r: Array=doc.data.visibility_rooms.filter(func(v):return v.id=="tools")[0].rect
	var origin:=Vector2(r[0],r[1])
	var front: Dictionary=game.world.access_by_id("tools-rear")
	var side: Dictionary=game.world.access_by_id("tools-entry")
	var exterior:=Vector2(front.rect.get_center().x,front.rect.end.y+60)
	var interior:=Vector2(front.rect.get_center().x,front.rect.position.y-140)
	game.world.set_access_closed("tools-entry",true)
	check("front closes with side",front.closed)
	check("closed front blocks",not game.world.motion_clear(exterior,interior,player,false,true))
	game.world.set_access_closed("tools-entry",false)
	check("front opens with side",not front.closed)
	check("front full body passage",game.world.motion_clear(exterior,interior,player,false,true) and game.world.motion_clear(interior,exterior,player,false,true))
	var side_y: float=side.rect.end.y-32
	var side_out:=Vector2(side.rect.position.x-70,side_y)
	var side_in:=Vector2(side.rect.end.x+110,side_y)
	check("side full body passage",game.world.motion_clear(side_out,side_in,player,false,true) and game.world.motion_clear(side_in,side_out,player,false,true))
	game.world.set_access_closed("tools-entry",true)
	check("closed side blocks",not game.world.motion_clear(side_out,side_in,player,false,true))
	game.world.set_access_closed("tools-entry",false)
	var front_view=game.room_visibility.doorways.by_id("tools-rear")
	check("door states retain identical header and jambs",front_view.gate.door_open_patches.slice(-3)==front_view.gate.door_closed_patches.slice(-3))
	check("front threshold below actors",front_view.get_node("ThresholdFloor").z_index<player.z_index)
	var side_view=game.room_visibility.doorways.by_id("tools-entry")
	check("side sprite stays upright",side_view.gate.door_open_patches[0].rotation_quarters==3 and is_equal_approx(side_view.rotation,PI/2))
	var furniture: Array=game.world.fixtures.filter(func(f):return str(f.id).begins_with("toolroom-") and f.get("blocks_movement",false))
	for f in furniture:
		check(str(f.id)+" blocks footprint",not game.world.can_place_circle(f.rect.get_center(),game.ACTOR_RADIUS,null,false))
		for peer in furniture:
			if f.id<peer.id:check(str(f.id)+" separated from "+str(peer.id),not f.rect.intersects(peer.rect))
	for point in [Vector2(170,150),Vector2(180,290),Vector2(170,430),Vector2(95,415),Vector2(275,350)]:
		var target: Vector2=origin+point
		check("approach clear "+str(point),game.world.can_place_circle(target,game.ACTOR_RADIUS,player,false))
		check("entrance reaches "+str(point),not game.world.find_path(exterior,target,player,false,true).is_empty())
	for pair in [["locker",Vector2(75,115)],["drawers",Vector2(270,145)],["rack_short",Vector2(272,153)],["rack",Vector2(273,330)],["chest",Vector2(282,400)]]:
		player.position=origin+pair[1];game.room_visibility.tick(0,true)
		check(str(pair[0])+" physical approach clear",game.world.can_place_circle(player.position,game.ACTOR_RADIUS,player,false))
		check(str(pair[0])+" approach path",not game.world.find_path(exterior,player.position,player,false,true).is_empty())
		check(str(pair[0])+" search reachable",game.looting.reason("toolroom-"+pair[0]).is_empty())
		check(str(pair[0])+" search opens",game.looting.open("toolroom-"+pair[0]));game.looting.tick(30);game.looting.close()
	player.position=origin+Vector2(170,290);game.room_visibility.tick(0,true)
	var cover=game.room_visibility.covers.filter(func(c):return c.room.id=="tools")[0]
	check("inside tools active",game.room_visibility.active_id=="tools");check("inside roof hidden",not cover.visible);check("dedicated roof active",cover.style=="tool_room")
	game.map_camera.center_on(origin+Vector2(180,220));game.map_camera.force_update_scroll();game.presentation.tick(0)
	await shot("runtime-interior")
	game.presentation.lighting.set_period("night");await shot("runtime-night");game.presentation.lighting.set_period("day")
	player.position=exterior;game.room_visibility.tick(0,true);game.presentation.tick(0);check("outside roof restored",cover.visible and cover.modulate.a==1);await shot("runtime-exterior")
	game.world.set_access_closed("tools-entry",true);game.room_visibility.doorways.tick(true);await shot("runtime-closed")
	game.queue_free();await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor);await frame();await frame()
	editor.canvas.zoom=.9;editor.canvas.origin=editor.canvas.size/2-(origin+Vector2(180,220))*.9;editor.canvas.queue_redraw();await shot("editor")
	check("saved map untouched by tests",saved==FileAccess.get_sha256("res://data/rooms/r04.json"))
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"));print(JSON.stringify({"checks":checks.size(),"failed":failed}));quit(0 if failed.is_empty() else 1)