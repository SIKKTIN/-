extends SceneTree
const OUT := "res://docs/art/office-restoration/"
var game
var checks := {}
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
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://office-restoration-qa.cfg")
	root.size=Vector2i(1280,900)
	root.content_scale_size=root.size
	var map_path := "res://data/rooms/r04.json"
	var disk := FileAccess.get_sha256(map_path)
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"last-input-map.json"))
	var after: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"last-output-map.json"))
	var unrelated := true
	for key in before:
		if key not in ["walls","architecture","fixtures","floor_regions","visibility_rooms","zones","concept_plan","office_restoration_version"] and before[key]!=after[key]: unrelated=false
	check("all unrelated map fields preserved",unrelated)
	for key in ["zones","visibility_rooms"]:
		check("other "+key+" preserved",before[key].filter(func(v):return v.id!="office")==after[key].filter(func(v):return v.id!="office"))
	var old_ids := ["campus-admin-desk-1","campus-admin-cabinet-1","campus-admin-board-1"]
	check("other fixtures preserved",before.fixtures.filter(func(v):return v.id not in old_ids and not v.get("office_generated",false))==after.fixtures.filter(func(v):return not v.get("office_generated",false)))
	check("other floors preserved",before.floor_regions.filter(func(v):return v.id not in ["campus-office","office-north-grass"])==after.floor_regions.filter(func(v):return v.id not in ["campus-office","office-north-grass"]))
	var registration: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"map-registration.json"))
	var walls_preserved := true
	for old_index in registration.wall_remap:
		if before.walls[int(old_index)]!=after.walls[int(registration.wall_remap[old_index])]: walls_preserved=false
	check("all unrelated wall rectangles preserved",walls_preserved)
	var record: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"asset-registration.json"))
	for asset in record.assets: check("original transparent PNG "+asset.key,FileAccess.get_sha256("res://"+asset.path)==asset.sha256)
	game=load("res://scenes/main.tscn").instantiate()
	game.room_id="r04"
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	var player=game.actors[0]
	var room: Dictionary=game.room_visibility.rooms.filter(func(v):return v.id=="office")[0]
	var area: Rect2=room.area
	check("compact square office",area.size==Vector2(460,440))
	check("office rear strip restores exterior grass",game.room_config.floor_regions.any(func(v):return v.id=="office-north-grass" and v.asset_id=="grass_base_v46" and v.get("natural_ground",false)))
	game.world.set_access_closed("office-entry",false)
	var inside := Vector2(4490,1060)
	var outside := Vector2(4490,1220)
	player.position=Vector2(area.position.x+275,area.position.y+270)
	game.guard.position=Vector2(3000,1500)
	game.dog.position=Vector2(3100,1500)
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)
	check("whole body passes office door both directions",game.world.motion_clear(outside,inside,player,false,true) and game.world.motion_clear(inside,outside,player,false,true))
	game.world.set_access_closed("office-entry",true)
	check("closed office door still blocks",not game.world.motion_clear(outside,inside,player,false,true))
	game.world.set_access_closed("office-entry",false)
	game.room_visibility.tick(0,true)
	var fixtures: Array=game.world.fixtures.filter(func(v):return v.get("office_generated",false))
	var overlaps := false
	for i in range(fixtures.size()):
		var a: Dictionary=fixtures[i]
		if not a.blocks_movement: continue
		check("blocking furniture inside office "+a.id,area.encloses(a.rect))
		for j in range(i+1,fixtures.size()):
			var b: Dictionary=fixtures[j]
			if b.blocks_movement and a.rect.intersection(b.rect).get_area()>0.01: overlaps=true
	check("furniture ground footprints never overlap",not overlaps)
	for fixture in fixtures:
		if not fixture.has("loot_profile"):continue
		var point: Vector2=Vector2(fixture.rect.get_center().x,fixture.rect.end.y+22)
		if fixture.id in ["campus-admin-cabinet-1","office-records-sideboard"]:point=Vector2(fixture.rect.position.x-25,fixture.rect.get_center().y)
		check("reachable search position "+fixture.id,not game.world.find_path(outside,point,player,false,true).is_empty())
		player.position=point
		game.room_visibility.tick(0,true)
		check("searchable from aisle "+fixture.id,game.looting.containers.has(fixture.id) and game.looting.reason(fixture.id).is_empty())
	player.position=Vector2(area.position.x+100,area.position.y+308)
	game.room_visibility.tick(0,true)
	check("new desk search opens",game.looting.open("campus-admin-desk-1"))
	game.looting.tick(60)
	var state: Dictionary=game.looting.containers["campus-admin-desk-1"]
	check("office search reveals items",not state.ids.is_empty() and state.ids.all(func(id):return state.revealed.get(id,false)))
	if not state.ids.is_empty():
		var item: String=state.ids[0]
		var source_cell: Vector2i=state.layout[item].position
		check("discovered item transfers into bag",game.looting.take(item).ok and game.inventory.owns(0,item))
		check("item drags back to office container",game.looting.move_item(item,"bag","source",source_cell).ok and state.ids.has(item) and not game.inventory.owns(0,item))
	game.looting.close()
	player.position=Vector2(area.position.x+275,area.position.y+270)
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)
	var cover=game.room_visibility.covers.filter(func(v):return v.room.id=="office")[0]
	check("office roof hides when inside",not cover.visible)
	check("existing character scale remains 1.4",preload("res://scripts/core/world_scale.gd").HUMAN==1.4)
	game.map_camera.center_on(area.get_center()+Vector2(0,-25))
	game.map_camera.force_update_scroll()
	game.presentation.tick(0)
	check("existing player sprite renders in office",game.presentation.visuals[0].visible)
	await shot("runtime-interior")
	game.get_node("HUD").hide()
	await shot("runtime-art")
	player.position=outside
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)
	check("office roof restores outdoors",cover.visible)
	game.queue_free()
	await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await frame()
	await frame()
	check("saved map validates and reloads",editor.document.validate().errors.is_empty())
	for asset in record.assets:
		var id: String="office_"+asset.key+"_v1"
		check("new furniture offered in editor "+asset.key,editor.catalog.entries.any(func(v):return v.id==id))
		var texture: Texture2D=editor.canvas.textures[id]
		check("bounded runtime texture "+asset.key,maxf(texture.get_width(),texture.get_height())<=512)
	editor.canvas.zoom=1.02
	editor.canvas.origin=editor.canvas.size/2-(area.get_center()+Vector2(0,-25))*editor.canvas.zoom
	editor.canvas.queue_redraw()
	await shot("editor-layout")
	check("QA never overwrites saved map",FileAccess.get_sha256(map_path)==disk)
	var failed: Array=checks.keys().filter(func(label):return not checks[label])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"office_checks":checks.size(),"failed":failed}))
	editor.queue_free()
	await frame()
	quit(0 if failed.is_empty() else 1)
