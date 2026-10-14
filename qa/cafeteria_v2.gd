extends SceneTree
const OUT="res://docs/art/cafeteria-redesign-v2/"
var checks: Dictionary={}
var game
func _initialize():
	create_timer(150).timeout.connect(func():quit(124))
	call_deferred("run")
func check(label: String,passed: bool):checks[label]=passed
func frame():
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func shot(label: String):
	await frame();await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+label+".png")
func point(a: Array)->Vector2:return Vector2(a[0],a[1])
func minute(value: float):
	game.schedule.clock_elapsed=(value-480)/1440.0*game.schedule.day_seconds
	game.schedule.tick(false);game.room_access.tick()
	game.routines.tick();game.resident_staff.tick(0)
func stand(p: Vector2):
	game.actors[0].position=p;game.actors[0].moved_this_frame=false
	game.orders.clear()
	game.room_visibility.tick(0,true);game.resident_staff.tick(0);game.presentation.tick(0)
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://cafeteria-v2-qa.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://cafeteria-v2-qa-buttons.cfg")
	root.size=Vector2i(1600,950);root.content_scale_size=root.size
	root.title="食堂还原验收"
	var disk: String=FileAccess.get_file_as_string("res://data/rooms/r04.json")
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"restoration-input.json"))
	var latest_before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"refinement-input.json"))
	var after: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"restoration-output.json"))
	var registration: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"layout-registration.json"))
	var allowed: Array=["architecture","walls","fixtures","floor_regions","visibility_rooms","zones","cafeteria","routine_points","resident_staff","lamps","access_doors","cafeteria_restoration_version"]
	for key in latest_before:
		if key not in allowed:check("latest unrelated map field "+key,latest_before[key]==after[key])
	for group in ["visibility_rooms","zones"]:
		check("other "+group+" retained",before[group].filter(func(r):return r.id!="canteen")==after[group].filter(func(r):return r.id!="canteen"))
	var changed: Array=registration.changed_fixture_ids
	check("unrelated fixtures preserved",before.fixtures.filter(func(f):return f.id not in changed)==after.fixtures.filter(func(f):return f.id not in changed))
	var exempt: Array=["cafeteria-entry","cafeteria-entry-east","cafeteria-rear","cafeteria-south"]
	check("other actual doors retained",before.access_doors.filter(func(g):return g.id not in exempt)==after.access_doors.filter(func(g):return g.id not in exempt))
	var doc=preload("res://scripts/editor/map_document.gd").new()
	check("map opens",doc.open_file("res://data/rooms/r04.json"))
	check("editor validates",doc.validate().errors.is_empty())
	var catalog=preload("res://scripts/editor/editor_catalog.gd").new()
	for id in ["cafeteria_table_vertical_v2","cafeteria_counter_v2","cafeteria_fridge_v2","cafeteria_bowl_cupboard_v2","cafeteria_sink_v2","cafeteria_bowl_rack_v2","cafeteria_corner_nw_v2","cafeteria_corner_se_v2","doorway_cafeteria_closed_v2"]:
		var entries: Array=catalog.entries.filter(func(e):return e.id==id)
		check(id+" editor palette",not entries.is_empty())
		check(id+" preview image",not entries.is_empty() and catalog.icon(entries[0])!=null)
	var artreg: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"asset-registration.json"))
	for a in artreg.assets:
		check(a.key+" original PNG",FileAccess.get_sha256("res://"+a.path)==a.sha256)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.schedule.set_time_speed(0)
	minute(750)
	var actor=game.actors[0]
	var desks: Array=game.world.fixtures.filter(func(f):return str(f.id).begins_with("dine-table-"))
	check("five vertical tables",desks.size()==5 and desks.all(func(f):return f.rect.size.y>f.rect.size.x))
	var room: Dictionary=game.room_visibility.rooms.filter(func(r):return r.id=="canteen")[0]
	check("compact room at saved location",room.area==Rect2(900,1940,1200,560))
	check("no overlap with adjacent rooms",game.room_visibility.rooms.filter(func(r):return r.id!="canteen").all(func(r):return not r.area.intersects(room.area)))
	var floor: Dictionary=game.room_config.floor_regions.filter(func(f):return f.id=="canteen")[0]
	check("interior floor fully covered",Rect2(floor.rect[0],floor.rect[1],floor.rect[2],floor.rect[3]).encloses(room.area))
	var origin:=Vector2(1140,1980)
	for key in ["meal","dine"]:
		for i in range(game.room_config.routine_points[key].size()):
			var target:=point(game.room_config.routine_points[key][i])
			check(key+str(i)+" within new cafeteria",room.area.has_point(target))
			check(key+str(i)+" standing clear",game.world.can_place_circle(target,game.ACTOR_RADIUS,actor,false))
			check(key+str(i)+" path from entry",not game.world.find_path(origin,target,actor,false,true).is_empty())
	for i in range(4):
		var x: float=(desks[i].rect.end.x+desks[i+1].rect.position.x)/2
		for y in [2180,2260,2330,2400]:check("table aisle "+str(i)+"/"+str(y),game.world.can_place_circle(Vector2(x,y),game.ACTOR_RADIUS,actor,false))
	var cook=game.resident_staff.actors.get("canteen-cook")
	check("existing cook reused",is_instance_valid(cook) and cook.definition.id=="canteen_cook")
	check("cook stands clear",game.world.can_place_circle(cook.position,game.ACTOR_RADIUS,actor,false))
	check("staff aisle reachable",not game.world.find_path(origin,cook.position,actor,false,true).is_empty())
	var volumes: Dictionary={}
	for v in game.presentation.volumes:
		if v.kind=="fixture":volumes[game.world.fixtures[v.wall_index].id]=v
	for i in range(5):
		var t=volumes["dine-table-"+str(i)];var tray=volumes["dine-tray-"+str(i)];var cup=volumes["canteen-redesign-cup-"+str(i)]
		check("tray on table "+str(i),t.display_rect.grow(-20).encloses(tray.display_rect))
		check("cup on table "+str(i),t.display_rect.grow(-20).encloses(cup.display_rect))
		check("tableware in front "+str(i),tray.z_index>t.z_index and cup.z_index>t.z_index)
	for id in ["cafeteria-entry","cafeteria-entry-east","cafeteria-south"]:
		var gate: Dictionary=game.world.access_by_id(id)
		var center: Vector2=gate.rect.get_center()
		check(id+" opens at lunch",not gate.closed)
		var approach: float=75 if id=="cafeteria-south" else 150
		check(id+" cross gate",not game.world.find_path(center-Vector2(0,approach),center+Vector2(0,140),actor,false,true).is_empty())
		var door=game.room_visibility.doorways.door_by_id[id]
		check(id+" shared frame two states",door.open_patches[-1]==door.closed_patches[-1])
		var foreground: float=110 if id!="cafeteria-south" else 35
		for dx in [-85,85]:check(id+" no foreground air wall "+str(dx),game.world.can_place_circle(Vector2(center.x+dx,gate.rect.end.y+foreground),game.ACTOR_RADIUS,actor,false))
	var cover=game.room_visibility.covers.filter(func(c):return c.room.id=="canteen")[0]
	check("roof touches south coping",is_equal_approx(cover.roof.end.y,2420))
	var return_point:=Vector2(2085,2340)
	check("return area standing clear",game.world.can_place_circle(return_point,game.ACTOR_RADIUS,actor,false))
	check("return area reachable",not game.world.find_path(origin,return_point,actor,false,true).is_empty())
	stand(point(game.room_config.routine_points.meal[0]))
	check("lunch interaction available",game.routines.meal_reason(0).is_empty())
	game.routines.start_meal(0);game.orders.stop(0);game.routines.tick()
	check("meal moves to own new seat",game.routines.records.has(0) and game.routines.records[0].goal==point(game.room_config.routine_points.dine[0]))
	stand(point(game.room_config.routine_points.dine[0]));game.routines.tick()
	check("eating happens at new seat",game.routines.is_eating(0))
	game.routines.finish_player_action(0)
	check("inside hides matching roof",not cover.visible and cook.visible and cover.style=="cafeteria")
	game.map_camera.center_on(Vector2(1500,2160));game.map_camera.force_update_scroll()
	game.get_node("HUD").hide();await frame();game.presentation.tick(0)
	await shot("runtime-interior")
	var builds: int=cover.draw_builds
	for i in range(20):game.room_visibility.tick(0)
	check("roof not rebuilt on idle",cover.draw_builds==builds)
	stand(Vector2(1560,2630));check("outside restores roof",cover.visible and not cook.visible)
	await shot("runtime-roof")
	minute(900)
	check("lunch closes after 14",["cafeteria-entry","cafeteria-entry-east","cafeteria-south"].all(func(id):return game.world.access_by_id(id).closed))
	stand(Vector2(1560,2630))
	for id in ["cafeteria-entry","cafeteria-entry-east","cafeteria-south"]:
		check(id+" closed leaf blocks passage",not game.world.can_place_circle(game.world.access_by_id(id).rect.get_center(),game.ACTOR_RADIUS,actor,false))
	await shot("runtime-closed")
	check("test does not write map",disk==FileAccess.get_file_as_string("res://data/rooms/r04.json"))
	game.queue_free();await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor);await frame();await frame()
	editor.canvas.zoom=.68;editor.canvas.origin=editor.canvas.size/2-Vector2(1500,2190)*editor.canvas.zoom;editor.canvas.queue_redraw()
	await shot("editor-cafeteria")
	check("editor loads latest layout",editor.document.data==JSON.parse_string(disk))
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	editor.queue_free();await frame();quit(0 if failed.is_empty() else 1)
