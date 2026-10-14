extends SceneTree
const OUT := "res://docs/art/laundry-restoration/"
var checks := {}
var game
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
func check(label: String, passed: bool) -> void: checks[label]=passed
func shot(name: String) -> void:
	await frame()
	await frame()
	if DisplayServer.get_name()!="headless": root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://laundry-restoration-qa.cfg")
	root.size=Vector2i(1280,900)
	root.content_scale_size=root.size
	var map_path := "res://data/rooms/r04.json"
	var disk := FileAccess.get_sha256(map_path)
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(map_path))
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"last-input-map.json"))
	var after: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"last-output-map.json"))
	var registration: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"map-registration.json"))
	var untouched := true
	for key in before:
		if key not in ["architecture","fixtures","floor_regions","visibility_rooms","ground_details","laundry_restoration_version"] and before[key]!=after[key]: untouched=false
	check("unrelated map fields, all gates and wall geometry preserved",untouched)
	check("cafeteria and other visibility rooms preserved",before.visibility_rooms.filter(func(v):return v.id!="laundry")==after.visibility_rooms.filter(func(v):return v.id!="laundry"))
	var old_ids: Array=registration.removed_fixture_ids
	check("other furniture and all side/north doors preserved",before.fixtures.filter(func(v):return v.id not in old_ids and v.id!="campus-laundry-south" and not v.get("laundry_generated",false))==after.fixtures.filter(func(v):return v.id!="campus-laundry-south" and not v.get("laundry_generated",false)))
	var surfaces_ok := true
	for i in range(before.architecture.wall_surfaces.size()):
		var a: Dictionary=before.architecture.wall_surfaces[i]
		if not registration.selected_walls.any(func(v):return int(v)==int(a.wall_index)) and a!=after.architecture.wall_surfaces[i]: surfaces_ok=false
	check("shared cafeteria wall and unrelated wall skins preserved",surfaces_ok)
	var record: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"asset-registration.json"))
	for asset in record.assets:check("original PNG preserved "+asset.key,FileAccess.get_sha256("res://"+asset.path)==asset.sha256)
	game=load("res://scenes/main.tscn").instantiate()
	game.room_id="r04"
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.get_node("HUD").hide()
	var player=game.actors[0]
	var room: Dictionary=game.room_visibility.rooms.filter(func(v):return v.id=="laundry")[0]
	var area: Rect2=room.area
	check("laundry footprint remains 900 by 480",area.size==Vector2(900,480))
	check("existing character scale remains 1.4",preload("res://scripts/core/world_scale.gd").HUMAN==1.4)
	check("four matching washers",game.world.fixtures.filter(func(v):return v.asset_id=="laundry_washer_v1").size()==4)
	var outside := Vector2(1130,3710)
	var inside := Vector2(1130,3450)
	player.position=Vector2(1310,3300)
	game.guard.position=Vector2(3000,1500)
	game.dog.position=Vector2(3100,1500)
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)
	var cover=game.room_visibility.covers.filter(func(v):return v.room.id=="laundry")[0]
	check("roof hidden inside laundry",not cover.visible)
	check("metal roof with two skylights and extractor",cover.style=="laundry" and cover.get_child_count()==3)
	check("full body passes main door both directions",game.world.motion_clear(outside,inside,player,false,true) and game.world.motion_clear(inside,outside,player,false,true))
	var fixtures: Array=game.world.fixtures.filter(func(v):return v.get("laundry_generated",false))
	var overlaps := false
	for i in range(fixtures.size()):
		var a: Dictionary=fixtures[i]
		if not a.blocks_movement:continue
		check("ground footprint inside room "+a.id,area.encloses(a.rect))
		for j in range(i+1,fixtures.size()):
			var b: Dictionary=fixtures[j]
			if b.blocks_movement and a.rect.intersection(b.rect).get_area()>0.01:overlaps=true
	check("furniture has no overlapping ground footprints",not overlaps)
	for f in fixtures:
		if not f.has("loot_profile"):continue
		var point: Vector2=Vector2(f.rect.get_center().x,f.rect.end.y+22)
		check("reachable search aisle "+f.id,not game.world.find_path(outside,point,player,false,true).is_empty())
		player.position=point
		game.room_visibility.tick(0,true)
		check("searchable linen storage "+f.id,game.looting.containers.has(f.id) and game.looting.reason(f.id).is_empty())
	game.world.set_access_closed("laundry-equipment",false)
	check("east maintenance passage preserved",not game.world.find_path(inside,Vector2(1830,3470),player,false,true).is_empty())
	check("west corridor passage preserved",not game.world.find_path(inside,Vector2(745,3360),player,false,true).is_empty())
	player.position=Vector2(1410,3467)
	game.room_visibility.tick(0,true)
	check("folding table search opens",game.looting.open("laundry-folding-table"))
	game.looting.tick(60)
	var loot: Dictionary=game.looting.containers["laundry-folding-table"]
	check("linen search reveals items",not loot.ids.is_empty() and loot.ids.all(func(id):return loot.revealed.get(id,false)))
	if not loot.ids.is_empty():
		var item: String=loot.ids[0]
		var cell: Vector2i=loot.layout[item].position
		check("new storage transfers item into backpack",game.looting.take(item).ok)
		check("item drags back into new storage",game.looting.move_item(item,"bag","source",cell).ok)
	game.looting.close()
	player.position=Vector2(1310,3300)
	game.room_visibility.tick(0,true)
	game.map_camera.center_on(area.get_center()+Vector2(0,-30))
	game.map_camera.force_update_scroll()
	game.presentation.tick(0)
	await shot("runtime-interior")
	var port: Dictionary=game.world.door_passage.by_id("fixture:campus-laundry-south")
	var door=game.room_visibility.doorways.by_id("fixture:campus-laundry-south")
	check("both steel door states registered",door.custom_texture!=null and door.closed_custom_texture!=null and door.closed_patches.size()==4)
	check("closed state reuses identical header and jamb artwork",door.closed_patches.slice(1).all(func(p):return p.texture==door.custom_texture))
	check("main door threshold remains below actors",door.get_node("ThresholdFloor").z_index<player.z_index and not door.get_node("ThresholdFloor").z_as_relative)
	var clinic_door=game.room_visibility.doorways.by_id("clinic-entry")
	check("existing clinic sliding leaves preserved",clinic_door.leaf_texture!=null and clinic_door.has_node("SlidingTrack"))
	check("clinic floor still draws below actors",clinic_door.has_node("ThresholdFloor") and clinic_door.get_node("ThresholdFloor").z_index<player.z_index)
	port.closed=true
	game.world._changed()
	check("closed steel leaf blocks whole body",not game.world.motion_clear(outside,inside,player,false,true))
	door.style="grille"
	door.gate.closed=true
	door.refresh(true)
	await shot("runtime-closed-door")
	port.closed=false
	game.world._changed()
	door.gate.closed=false
	door.refresh(true)
	player.position=outside
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)
	check("opaque roof restored outside",cover.visible and cover.modulate.a==1)
	for id in ["laundry-sign","laundry-downpipe"]:
		var index: int=game.world.fixtures.find(game.world.fixtures.filter(func(f):return f.id==id)[0])
		check("exterior attachment stays visible with roof "+id,game.presentation.volumes.any(func(v):return v.kind=="fixture" and v.wall_index==index and v.visible))
	await shot("runtime-roof")
	game.queue_free()
	await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await frame()
	await frame()
	editor.open_now(map_path)
	await frame()
	check("editor saved map validates",editor.document.validate().errors.is_empty())
	for id in record.definition_ids:
		check("new asset offered in editor "+id,editor.catalog.entries.any(func(v):return v.id==id))
		if editor.canvas.textures.has(id) and not id.begins_with("laundry_wall") and not id.begins_with("laundry_corner") and not id.begins_with("laundry_lintel") and id!="laundry_t_e":
			var texture: Texture2D=editor.canvas.textures[id]
			check("bounded runtime sprite "+id,maxf(texture.get_width(),texture.get_height())<=512)
	editor.canvas.zoom=0.84
	editor.canvas.origin=editor.canvas.size/2-(area.get_center()+Vector2(0,-30))*editor.canvas.zoom
	editor.canvas.queue_redraw()
	await shot("editor-layout")
	var latest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(map_path))
	check("QA leaves saved laundry layout intact",saved.fixtures.filter(func(v):return v.get("laundry_generated",false))==latest.fixtures.filter(func(v):return v.get("laundry_generated",false)))
	var external_update := FileAccess.get_sha256(map_path)!=disk
	var failed: Array=checks.keys().filter(func(label):return not checks[label])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"external_map_update":external_update},"\t"))
	print(JSON.stringify({"laundry_checks":checks.size(),"failed":failed}))
	editor.queue_free()
	await frame()
	quit(0 if failed.is_empty() else 1)
