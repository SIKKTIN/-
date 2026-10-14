extends SceneTree
const OUT="res://docs/art/cafeteria-redesign-v1/"
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
	game.actors[0].position=p
	game.actors[0].moved_this_frame=false
	game.orders.clear()
	game.room_visibility.tick(0,true);game.resident_staff.tick(0);game.presentation.tick(0)
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://cafeteria-redesign-qa.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://cafeteria-redesign-qa-buttons.cfg")
	root.size=Vector2i(1600,950);root.content_scale_size=root.size
	var disk:=FileAccess.get_file_as_string("res://data/rooms/r04.json")
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"registration-input.json"))
	var after: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"registration-output.json"))
	var registration: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"asset-registration.json"))
	check("wall geometry retained",before.walls==after.walls)
	check("all actual doors retained",before.access_doors==after.access_doors)
	for key in before:
		if key not in ["architecture","fixtures","floor_regions","visibility_rooms","zones","cafeteria","routine_points","resident_staff","ground_details"]:
			check("map field retained "+key,before[key]==after[key])
	for group in ["visibility_rooms","zones","floor_regions"]:
		check("other "+group+" retained",before[group].filter(func(r):return r.id!="canteen")==after[group].filter(func(r):return r.id!="canteen"))
	check("other residents retained",before.resident_staff==after.resident_staff.filter(func(s):return s.id!="canteen-cook"))
	var changed: Array=registration.changed_fixture_ids
	check("unrelated fixtures retained",before.fixtures.filter(func(f):return f.id not in changed)==after.fixtures.filter(func(f):return f.id not in changed and not str(f.id).begins_with("canteen-redesign-") and not str(f.id).begins_with("dine-")))
	var collision_retained := true
	var outside_retained := true
	for i in range(before.architecture.wall_surfaces.size()):
		var old: Dictionary=before.architecture.wall_surfaces[i]
		var new: Dictionary=after.architecture.wall_surfaces[i]
		if registration.wall_indices.any(func(index):return int(index)==int(old.wall_index)):
			var expected: Dictionary=old.duplicate(true);expected.grid_tile_asset=new.grid_tile_asset
			collision_retained = collision_retained and new==expected
		else:outside_retained = outside_retained and old==new
	check("all food wall collisions retained",collision_retained)
	check("all outside wall surfaces retained",outside_retained)
	var doc=preload("res://scripts/editor/map_document.gd").new()
	check("map opens",doc.open_file("res://data/rooms/r04.json"))
	check("editor validates",doc.validate().errors.is_empty())
	var catalog=preload("res://scripts/editor/editor_catalog.gd").new()
	for id in ["cafeteria_table_vertical_v1","cafeteria_counter_v1","cafeteria_backline_v1","cafeteria_service_food_v1","cafeteria_water_urn_v1","cafeteria_return_v1","cafeteria_enamel_cup_v1","cafeteria_junction_e","cafeteria_junction_s","cafeteria_corner_nw","cafeteria_corner_se"]:
		check(id+" palette",catalog.entries.any(func(e):return e.id==id))
		check(id+" preview icon",catalog.icon(catalog.entries.filter(func(e):return e.id==id)[0])!=null)
	for asset in registration.assets:
		check(asset.key+" original PNG retained",FileAccess.get_sha256("res://"+asset.path)==asset.sha256)
		var pixels: Image=load("res://"+asset.path).get_image()
		if asset.key not in ["floor","roof"]:check(asset.key+" transparent",pixels.get_pixel(0,0).a<.05)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false)
	game.schedule.set_time_speed(0)
	minute(750)
	var actor=game.actors[0]
	var desks: Array=game.world.fixtures.filter(func(f):return str(f.id).begins_with("dine-table-"))
	check("exactly five tables",desks.size()==5)
	check("old lamp icons removed from tables, lighting retained",game.room_config.lamps.filter(func(l):return Rect2(820,2520,1360,480).has_point(point(l.position))).all(func(l):return not l.get("draw_fixture",true)))
	var origin:=Vector2(1060,2340)
	for desk in desks:
		check(desk.id+" north-south footprint",desk.rect.size.y>desk.rect.size.x)
		check(desk.id+" physically solid",not game.world.can_place_circle(desk.rect.get_center(),game.ACTOR_RADIUS,actor,false))
	for key in ["meal","dine"]:
		for i in range(game.room_config.routine_points[key].size()):
			var target:=point(game.room_config.routine_points[key][i])
			check(key+str(i)+" standing floor clear",game.world.can_place_circle(target,game.ACTOR_RADIUS,actor,false))
			check(key+str(i)+" reachable from north gate",not game.world.find_path(origin,target,actor,false,true).is_empty())
	for i in range(4):
		var lane_x: float=desks[i].rect.end.x+47.5
		for y in [2708,2800,2870,2970]:
			check("lane "+str(i)+"/"+str(y)+" clear",game.world.can_place_circle(Vector2(lane_x,y),game.ACTOR_RADIUS,actor,false))
	var service:=Vector2(1750,2608)
	check("cook work corridor clear",game.world.can_place_circle(service,game.ACTOR_RADIUS,actor,false))
	check("cook work corridor reachable",not game.world.find_path(origin,service,actor,false,true).is_empty())
	var cook=game.resident_staff.actors.get("canteen-cook")
	check("existing cook appearance reused",is_instance_valid(cook) and cook.definition.id=="canteen_cook")
	check("cook stands on accessible floor",game.world.can_place_circle(cook.position,game.ACTOR_RADIUS,actor,false))
	var meal:=point(game.room_config.routine_points.meal[0])
	stand(meal)
	check("lunch can be collected",game.routines.meal_reason(0).is_empty())
	game.routines.start_meal(0);game.orders.stop(0);game.routines.tick()
	check("meal transitions to own dining place",game.routines.records.has(0) and game.routines.records[0].meal_stage=="dine" and game.routines.records[0].goal==point(game.room_config.routine_points.dine[0]))
	stand(point(game.room_config.routine_points.dine[0]));game.routines.tick()
	check("dining credit only at seat",game.routines.is_eating(0))
	game.routines.finish_player_action(0)
	var volumes: Dictionary={}
	for v in game.presentation.volumes:
		if v.kind=="fixture":volumes[game.world.fixtures[v.wall_index].id]=v
	for i in range(5):
		var table=volumes["dine-table-"+str(i)]
		var tray=volumes["dine-tray-"+str(i)]
		var cup=volumes["canteen-redesign-cup-"+str(i)]
		check("tray"+str(i)+" on tabletop",table.display_rect.grow(-30).encloses(tray.display_rect))
		check("cup"+str(i)+" on tabletop",table.display_rect.grow(-30).encloses(cup.display_rect))
		check("tableware"+str(i)+" above table",tray.z_index>table.z_index and cup.z_index>table.z_index)
		check("table"+str(i)+" uniform source scale",is_equal_approx(table.display_rect.size.x/table.world.art_textures[table.prop_id()].get_width(),table.display_rect.size.y/table.world.art_textures[table.prop_id()].get_height()))
	var cover=game.room_visibility.covers.filter(func(c):return c.room.id=="canteen")[0]
	check("cafeteria roof style",cover.style=="cafeteria")
	check("cafeteria roof has separate material",cover.roof_texture!=null and preload("res://scripts/presentation/room_cover.gd").definitions()["cafeteria_roof_surface"].texture=="res://art/architecture/cafeteria_v1/roof.png")
	check("roof has kitchen flue and fan",cover.has_node("roof_kitchen_flue") and cover.has_node("roof_fan"))
	stand(Vector2(895,2890))
	check("inside hides roof",not cover.visible and cook.visible)
	game.map_camera.center_on(Vector2(1500,2780));game.map_camera.force_update_scroll()
	await frame();game.presentation.tick(0)
	check("player rendered in cafeteria",game.presentation.visuals[0].visible)
	game.get_node("HUD").hide()
	await shot("runtime-interior")
	var builds: int=cover.draw_builds
	for i in range(20):game.room_visibility.tick(0)
	check("roof geometry not rebuilt by idle ticks",cover.draw_builds==builds)
	stand(Vector2(740,2860))
	check("outside restores roof and hides cook",cover.visible and not cook.visible)
	await shot("runtime-roof")
	game.world.set_access_closed("maintenance-entry",false)
	game.world.admission_filter=Callable()
	for id in ["cafeteria-entry","cafeteria-entry-east","cafeteria-rear","maintenance-entry"]:
		var gate: Dictionary=game.world.access_by_id(id)
		var start: Vector2=gate.rect.get_center()+Vector2(0,-150)
		var end: Vector2=gate.rect.get_center()+Vector2(0,180)
		check(id+" path crosses threshold",not game.world.find_path(start,end,actor,false,true).is_empty())
	minute(900)
	check("lunch still closes at 14",game.world.access_by_id("cafeteria-entry").closed and game.routines.meal_reason(0).contains("12:00"))
	check("test leaves map untouched",disk==FileAccess.get_file_as_string("res://data/rooms/r04.json"))
	game.queue_free();await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor);await frame();await frame()
	editor.canvas.zoom=.72;editor.canvas.origin=editor.canvas.size/2-Vector2(1500,2750)*editor.canvas.zoom;editor.canvas.queue_redraw()
	await shot("editor-cafeteria")
	check("editor opens latest layout",editor.document.data==JSON.parse_string(disk))
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	editor.queue_free();await frame();quit(0 if failed.is_empty() else 1)
