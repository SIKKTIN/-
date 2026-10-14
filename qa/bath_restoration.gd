extends SceneTree
const OUT := "res://docs/art/bath-restoration/"
var game
var checks := {}
func _initialize(): call_deferred("run")
func check(label: String, passed: bool):checks[label]=passed
func frame():
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func shot(name: String):
	await frame()
	await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+name+".png")
func outside_walls(map: Dictionary) -> Array:
	var bath: Array=map.visibility_rooms.filter(func(r):return r.id=="bath")[0].rect
	var result: Array=[]
	for s in map.architecture.wall_surfaces:
		var rect: Array=map.walls[int(s.wall_index)]
		if rect[0]>=bath[0]-20 and rect[1]>=bath[1]-120 and rect[0]+rect[2]<=bath[0]+bath[2]+20 and rect[1]+rect[3]<=bath[1]+bath[3]+40:continue
		var copy: Dictionary=s.duplicate(true);copy.erase("wall_index")
		result.append([rect,copy])
	return result
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://bath-art-qa.cfg")
	root.size=Vector2i(1280,900);root.content_scale_size=root.size
	var disk:=FileAccess.get_file_as_string("res://data/rooms/r04.json")
	var map: Dictionary=JSON.parse_string(disk)
	var prior: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"last-input-map.json"))
	# Compare the exact registration input/output pair. Other rooms may be
	# edited independently after this restoration; live gameplay uses map.
	var applied: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"last-output-map.json"))
	check("registration retained outside wall geometry and surfaces",outside_walls(applied)==outside_walls(prior))
	for group in ["zones","visibility_rooms"]:
		check("other "+group+" unchanged",applied[group].filter(func(r):return r.id!="bath")==prior[group].filter(func(r):return r.id!="bath"))
	check("other fixtures unchanged",applied.fixtures.filter(func(f):return not str(f.id).begins_with("campus-bath"))==prior.fixtures.filter(func(f):return not str(f.id).begins_with("campus-bath")))
	check("other floors unchanged",applied.floor_regions.filter(func(f):return f.id!="campus-bath" and not str(f.id).begins_with("bath-"))==prior.floor_regions.filter(func(f):return f.id!="campus-bath" and not str(f.id).begins_with("bath-")))
	for key in prior:
		if key not in ["walls","architecture","zones","visibility_rooms","fixtures","floor_regions","concept_plan"]:check("other map field "+key+" retained",applied.get(key)==prior[key])
	var registration: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"registration.json"))
	for entry in registration.assets:check(entry.key+" PNG unchanged",FileAccess.get_sha256("res://"+entry.path)==entry.sha256)
	var doc=preload("res://scripts/editor/map_document.gd").new()
	check("editor opens restored bath",doc.open_file("res://data/rooms/r04.json"))
	check("map validation passes",doc.validate().errors.is_empty())
	var catalog=preload("res://scripts/editor/editor_catalog.gd").new()
	for id in ["bath_shower_single","bath_changing_lockers","bath_sign","bath_floor_drain","bath_corner_nw","bath_corner_se","bath_wall_v_long"]:
		check(id+" in editor palette",catalog.entries.any(func(e):return e.id==id))
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.world.admission_filter=Callable()
	var room: Dictionary=game.room_visibility.rooms.filter(func(r):return r.id=="bath")[0]
	var area: Rect2=room.area
	check("compact approved room",area.size==Vector2(440,540))
	var showers: Array=game.world.fixtures.filter(func(f):return f.asset_id=="bath_shower_single")
	check("six individual showers",showers.size()==6)
	var actor=game.actors[0]
	var door=game.room_visibility.doorways.by_id("fixture:campus-bath")
	var origin:=Vector2(door.visual_rect.get_center().x,area.end.y+100)
	for f in showers:
		var target: Vector2=f.rect.position+Vector2(f.rect.size.x/2,50)
		check(f.id+" standing floor clear",game.world.can_place_circle(target,game.ACTOR_RADIUS,actor,false))
		check(f.id+" accessible from entrance",not game.world.find_path(origin,target,actor,false,true).is_empty())
		check(f.id+" partition solid",not game.world.can_place_circle(f.rect.get_center(),game.ACTOR_RADIUS,actor,false))
	for y in range(int(area.position.y+60),int(area.end.y),20):
		check("central aisle clear "+str(y),game.world.can_place_circle(Vector2(door.visual_rect.get_center().x,y),game.ACTOR_RADIUS,actor,false))
	check("open threshold clear",game.world.can_place_circle(Vector2(door.visual_rect.get_center().x,area.end.y+20),game.ACTOR_RADIUS,actor,false))
	var lane_x: float=door.visual_rect.get_center().x
	var lane_start:=Vector2(lane_x,area.end.y-110)
	var lane_end:=origin+Vector2(0,30)
	check("entire character can cross entrance",game.world.motion_clear(lane_start,lane_end,actor,false,true) and game.world.motion_clear(lane_end,lane_start,actor,false,true))
	actor.position=lane_start
	game.world.move_actor(actor,lane_end-lane_start)
	check("actual movement exits bathroom",actor.position.distance_to(lane_end)<.01)
	game.world.move_actor(actor,lane_start-lane_end)
	check("actual movement enters bathroom",actor.position.distance_to(lane_start)<.01)
	check("entrance jamb stops head overlap",not game.world.door_body_clear(Vector2(door.visual_rect.position.x+15,door.visual_rect.end.y+60)))
	check("door uses bath tile bridge",door.floor_asset=="bath_dry_tiles")
	check("entrance frame has no crossbar",door.gate.get("frame_only",false) and door.style=="free")
	var cabinet: Dictionary=game.world.fixtures.filter(func(f):return f.id=="campus-bath-locker-0")[0]
	actor.position=cabinet.rect.get_center()+Vector2(cabinet.rect.size.x/2+24,0)
	game.room_visibility.tick(0,true)
	check("locker interaction standing space",game.world.can_place_circle(actor.position,game.ACTOR_RADIUS,actor,false))
	check("changing locker accessible for search",game.looting.reason(cabinet.id).is_empty())
	check("changing locker opens",game.looting.open(cabinet.id))
	game.looting.tick(30)
	var state: Dictionary=game.looting.containers[cabinet.id]
	if not state.ids.is_empty():
		var item: String=state.ids[0]
		check("locker item can be taken",game.looting.take(item).ok)
		var point=preload("res://scripts/items/grid_packing.gd").first_space(state.layout,Vector2i(4,4),game.inventory.item_size(game.inventory.instances[item].definition_id))
		check("locker item can be dragged back",game.looting.move_item(item,"bag","source",point).ok)
	game.looting.close()
	actor.position=Vector2(door.visual_rect.get_center().x,area.position.y+370)
	game.room_visibility.tick(0,true);game.presentation.tick(0)
	var cover=game.room_visibility.covers.filter(func(c):return c.room.id=="bath")[0]
	check("bath roof hidden inside",not cover.visible)
	check("dedicated bathroom roof selected",cover.style=="bath" and cover.roof_tile==cover.roof.size)
	check("two new exhaust caps loaded",cover.get_children().filter(func(c):return str(c.name).begins_with("bath_roof_vent")).size()==2)
	game.map_camera.center_on(Vector2(area.get_center().x,area.position.y+220));game.map_camera.force_update_scroll()
	await frame();game.presentation.tick(0);await frame()
	check("indoor character visible at actual scale",game.presentation.visuals[0].visible)
	await shot("bath-runtime")
	game.get_node("HUD").hide();game.mobile_controls.pad.hide()
	await shot("bath-runtime-clear")
	actor.position=origin;game.room_visibility.tick(0,true);game.presentation.tick(0)
	check("bath roof visible outside",cover.visible and cover.modulate.a==1)
	await frame()
	var builds: int=cover.draw_builds
	for i in range(30):game.presentation.tick(0)
	await frame()
	check("static roof commands retained",cover.draw_builds==builds)
	await shot("bath-exterior")
	game.hide();game.map_camera.enabled=false;root.canvas_transform=Transform2D.IDENTITY
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await frame();await frame()
	var index: int=editor.document.data.visibility_rooms.find(editor.document.data.visibility_rooms.filter(func(r):return r.id=="bath")[0])
	editor.layers.set_visible("visibility",true);editor.layers.set_locked("visibility",false)
	editor.canvas.choose({"group":"visibility_rooms","index":index})
	await frame()
	editor.canvas.zoom=.70;editor.canvas.origin=editor.canvas.size/2-Vector2(area.get_center().x,area.position.y+220)*editor.canvas.zoom;editor.canvas.queue_redraw()
	var selector=editor.inspector.find_child("RoofStyle",true,false)
	check("editor recognizes bathroom roof",selector!=null and selector.get_item_text(selector.selected).contains("浴室"))
	await shot("bath-editor")
	editor.queue_free();await frame()
	check("QA leaves saved map intact",disk==FileAccess.get_file_as_string("res://data/rooms/r04.json"))
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	game.queue_free();await frame();quit(0 if failed.is_empty() else 1)
