extends SceneTree
const OUT := "res://docs/art/dorm-restoration/"
var game
var checks := {}
func _initialize() -> void: call_deferred("run")
func check(label: String, passed: bool) -> void: checks[label]=passed
func dorm_light(lamp: Dictionary, rooms: Array) -> bool:
	return rooms.any(func(r):return str(r.id).begins_with("dorm") and Rect2(r.rect[0],r.rect[1],r.rect[2],r.rect[3]).has_point(Vector2(lamp.position[0],lamp.position[1])))
func frame() -> void:
	await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
func shot(name: String) -> void:
	await frame()
	await frame()
	if DisplayServer.get_name()!="headless": root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://dorm-art-qa.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://dorm-art-buttons.cfg")
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	var disk := FileAccess.get_file_as_string("res://data/rooms/r04.json")
	var map: Dictionary=JSON.parse_string(disk)
	var baseline: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"last-input-map.json"))
	var registration: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"registration.json"))
	for key in baseline:
		if key not in ["fixtures","lamps"]: check("preserved "+key,map.get(key)==baseline[key])
	var changed: Array=registration.replaced_fixture_ids
	check("all other fixtures preserved",map.fixtures.filter(func(f):return f.id not in changed)==baseline.fixtures.filter(func(f):return f.id not in changed))
	check("other room lights preserved",map.lamps.filter(func(l):return not dorm_light(l,map.visibility_rooms))==baseline.lamps.filter(func(l):return not dorm_light(l,baseline.visibility_rooms)))
	check("five counter light sources",map.lamps.filter(func(l):return l.has("dorm_decor_room_id") and not l.draw_fixture).size()==5)
	var assets: Dictionary=preload("res://scripts/presentation/prop_catalog.gd").assets()
	var catalog=preload("res://scripts/editor/editor_catalog.gd").new()
	for entry in registration.assets:
		check(entry.key+" original unchanged",FileAccess.get_sha256("res://"+entry.path)==entry.sha256)
	for id in ["dorm_bunk_h_v1","dorm_personal_locker_v1","dorm_toilet_v1","dorm_wash_counter_ns_v1","dorm_cushion_stool_v1"]:
		check(id+" game/editor registration",assets.has(id) and catalog.entries.any(func(e):return e.id==id))
		var texture: Texture2D=preload("res://scripts/presentation/world_texture.gd").load_asset(assets[id])
		check(id+" transparent texture loaded",texture!=null and texture.get_image().get_pixel(0,0).a<0.03)
		check(id+" proportion locked",assets[id].proportion_locked)
	var doc=preload("res://scripts/editor/map_document.gd").new()
	check("editor opens",doc.open_file("res://data/rooms/r04.json"))
	check("map validates",doc.validate().errors.is_empty())
	var placement: Dictionary=doc.add("fixtures",Vector2(3000,3000),"dorm_bunk_h_v1")
	check("editor places new bed",doc.value(placement).asset_id=="dorm_bunk_h_v1")
	doc.undo()
	check("placement undo",doc.data.fixtures==map.fixtures)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.reset_round(["chat","backpack","strong"],139)
	game.world.admission_filter=Callable()
	check("human scale retained",preload("res://scripts/core/world_scale.gd").HUMAN==1.4)
	for room in map.visibility_rooms.filter(func(r):return r.id in registration.room_ids):
		var area:=Rect2(room.rect[0],room.rect[1],room.rect[2],room.rect[3])
		var furniture: Array=game.world.fixtures.filter(func(f):return f.id in registration.new_fixture_ids and area.has_point(f.rect.get_center()))
		check(room.id+" five furnishings",furniture.size()==5)
		for i in furniture.size():
			check(furniture[i].id+" floor collision",not game.world.can_place_circle(furniture[i].rect.get_center(),game.ACTOR_RADIUS,null,false))
			for j in range(i+1,furniture.size()): check(furniture[i].id+" / "+furniture[j].id+" distinct footprint",not furniture[i].rect.intersects(furniture[j].rect))
		var origin:=area.position+Vector2(308,194)
		game.actors[0].position=origin
		game.room_visibility.tick(0,true)
		check(room.id+" centre clear",game.world.can_place_circle(origin,game.ACTOR_RADIUS,game.actors[0],false))
		check(room.id+" full-body side entrance",game.world.can_place_circle(area.position+Vector2(570,200),game.ACTOR_RADIUS,game.actors[0],false))
		check(room.id+" route to corridor",not game.world.find_path(origin,area.position+Vector2(610,200),game.actors[0],false,true).is_empty())
		var cabinet: Dictionary=furniture.filter(func(f):return f.asset_id=="dorm_personal_locker_v1")[0]
		var approach: Vector2=cabinet.rect.get_center()+Vector2(0,cabinet.rect.size.y/2+32)
		check(room.id+" cabinet reachable",not game.world.find_path(origin,approach,game.actors[0],false,true).is_empty())
		game.actors[0].position=approach
		game.room_visibility.tick(0,true)
		check(room.id+" cupboard search accessible",game.looting.reason(cabinet.id).is_empty())
		check(room.id+" cupboard opens",game.looting.open(cabinet.id))
		game.looting.tick(30)
		var state: Dictionary=game.looting.containers[cabinet.id]
		if not state.ids.is_empty():
			var item: String=state.ids[0]
			check(room.id+" take item",game.looting.take(item).ok)
			var destination:=preload("res://scripts/items/grid_packing.gd").first_space(state.layout,Vector2i(4,4),game.inventory.item_size(game.inventory.instances[item].definition_id))
			check(room.id+" put item back",game.looting.move_item(item,"bag","source",destination).ok)
		game.looting.close()
	var selected: Dictionary=map.visibility_rooms.filter(func(r):return r.id=="dorm-0")[0]
	var center:=Vector2(selected.rect[0]+280,selected.rect[1]+150)
	game.actors[0].position=center+Vector2(90,44)
	game.room_visibility.tick(0,true)
	game.map_camera.center_on(center)
	game.map_camera.force_update_scroll()
	game.presentation.tick(0)
	game.mobile_controls.pad.hide()
	await shot("dorm-runtime")
	game.get_node("HUD").hide()
	await shot("dorm-runtime-clear")
	game.actors[0].position=Vector2(selected.rect[0]+610,selected.rect[1]+200)
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)
	await shot("dorm-exterior")
	var cover=game.room_visibility.covers.filter(func(c):return c.room.id=="dorm-0")[0]
	check("roof returns outside",cover.visible and cover.modulate.a==1)
	check("saved map untouched by QA",disk==FileAccess.get_file_as_string("res://data/rooms/r04.json"))
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	game.queue_free()
	await frame()
	await frame()
	quit(0 if failed.is_empty() else 1)
