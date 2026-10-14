extends SceneTree
const OUT := "res://docs/art/laundry-redesign-v01/"
var checks := {}
var game
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
func check(label: String, passed: bool) -> void:
	checks[label]=passed
	if not passed: print("FAILED: "+label)
func shot(name: String) -> void:
	await frame()
	await frame()
	if DisplayServer.get_name()!="headless": root.get_texture().get_image().save_png(OUT+name+".png")
func raw(path: String) -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(path))
func finish() -> void:
	var failed: Array=checks.keys().filter(func(label):return not checks[label])
	FileAccess.open(OUT+("checks-headless.json" if DisplayServer.get_name()=="headless" else "checks-native.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"laundry_redesign_checks":checks.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)
func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://laundry-redesign-qa.cfg")
	OS.set_environment("ESCAPE_FRAME_MODE","60")
	root.size=Vector2i(1280,900)
	root.content_scale_size=root.size
	var doc=load("res://scripts/editor/map_document.gd").new()
	if "--candidate" in OS.get_cmdline_user_args():
		check("candidate opens in map document",doc.open_file(OUT+"candidate-map.json"))
		check("candidate validates",doc.validate().errors.is_empty())
		finish()
		return
	var path := "res://data/rooms/r04.json"
	var disk := FileAccess.get_sha256(path)
	var before := raw(OUT+"last-input-map.json")
	var after := raw(OUT+"last-output-map.json")
	var registration := raw(OUT+"map-registration.json")
	var changed: Array=registration.changed_fixture_ids
	check("other furniture preserved",before.fixtures.filter(func(v):return v.id not in changed)==after.fixtures.filter(func(v):return v.id not in changed))
	check("other gate rules preserved",before.access_doors.filter(func(v):return v.id!="cafeteria-rear")==after.access_doors.filter(func(v):return v.id!="cafeteria-rear"))
	check("all roof and room regions preserved",before.visibility_rooms==after.visibility_rooms)
	var untouched := true
	for key in before:
		if key not in ["architecture","walls","fixtures","access_doors","ground_details","floor_regions","concept_plan"] and before[key]!=after[key]:untouched=false
	check("other map fields preserved",untouched)
	var walls_ok := true
	var new_surfaces := {}
	for s in after.architecture.wall_surfaces:new_surfaces[int(s.wall_index)]=s
	for s in before.architecture.wall_surfaces:
		var old := int(s.wall_index)
		if registration.selected_walls.any(func(v):return int(v)==old):continue
		var next := int(registration.index_remap[str(old)])
		var copy: Dictionary=new_surfaces[next].duplicate(true)
		copy.wall_index=s.wall_index
		if before.walls[old]!=after.walls[next] or copy!=s:walls_ok=false
	check("unrelated walls and shared junctions preserved",walls_ok)
	var assets := raw(OUT+"production-assets.json")
	for a in assets.assets:check("original PNG preserved "+a.key,FileAccess.get_sha256("res://"+a.path)==a.sha256)
	game=load("res://scenes/main.tscn").instantiate()
	game.room_id="r04"
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.get_node("HUD").hide()
	var player=game.actors[0]
	game.guard.position=Vector2(3000,1500)
	game.dog.position=Vector2(3100,1500)
	var area := Rect2(900,3420,900,480)
	check("four equal industrial washers",game.world.fixtures.filter(func(v):return v.asset_id=="laundry_washer_v2" and v.rect.size==Vector2(80,66)).size()==4)
	var north: Dictionary=game.world.access_by_id("cafeteria-rear")
	check("north gate retains lunchtime permissions",north.kind=="timed" and float(north.hours[0])==720.0 and float(north.hours[1])==840.0)
	player.position=Vector2(1060,3250)
	check("laundry admission blocked outside opening hours",not game.room_access.movement_allowed(player,Vector2(1060,3540),8))
	game.schedule.clock_elapsed=(750.0-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.room_access.tick()
	check("laundry admission allowed at 12:30",game.room_access.movement_allowed(player,Vector2(1060,3540),8))
	var n_out := Vector2(1060,3250)
	var n_in := Vector2(1060,3540)
	game.world.set_access_closed("cafeteria-rear",true)
	check("closed north door blocks whole body",not game.world.motion_clear(n_out,n_in,player,false,true))
	game.world.set_access_closed("cafeteria-rear",false)
	check("open north door passes both ways",game.world.motion_clear(n_out,n_in,player,false,true) and game.world.motion_clear(n_in,n_out,player,false,true))
	var south_out := Vector2(1610,4040)
	var south_in := Vector2(1610,3730)
	check("south doorway passes whole body both ways",game.world.motion_clear(south_out,south_in,player,false,true) and game.world.motion_clear(south_in,south_out,player,false,true))
	check("new entrance to exit route connected",not game.world.find_path(n_out,south_out,player,false,true).is_empty())
	check("old north hole filled with solid wall",not game.world.motion_clear(Vector2(1390,3350),Vector2(1390,3440),player,false,true))
	check("old south hole filled with solid wall",not game.world.motion_clear(Vector2(1210,3860),Vector2(1210,3990),player,false,true))
	check("west doorway preserved and clear",game.world.motion_clear(Vector2(840,3710),Vector2(970,3710),player,false,true))
	game.world.set_access_closed("laundry-equipment",true)
	check("maintenance door locked collision preserved",not game.world.motion_clear(Vector2(1740,3770),Vector2(1870,3770),player,false,true))
	game.world.set_access_closed("laundry-equipment",false)
	check("maintenance door unlocked crossing preserved",game.world.motion_clear(Vector2(1740,3770),Vector2(1870,3770),player,false,true))
	check("maintenance linked identity preserved",game.world.access_by_id("laundry-equipment").linked_to=="maintenance-entry")
	var fixtures: Array=game.world.fixtures.filter(func(v):return v.get("laundry_generated",false))
	var overlaps := false
	for i in range(fixtures.size()):
		var a: Dictionary=fixtures[i]
		if not a.blocks_movement:continue
		check("furniture footprint inside room "+a.id,area.encloses(a.rect))
		for j in range(i+1,fixtures.size()):
			var b: Dictionary=fixtures[j]
			if b.blocks_movement and a.rect.intersection(b.rect).get_area()>0.01:overlaps=true
	check("no overlapping furniture footprints",not overlaps)
	for f in fixtures:
		if not f.has("loot_profile"):continue
		var point := Vector2(f.rect.get_center().x,f.rect.end.y+22)
		var search_path: PackedVector2Array=game.world.find_path(south_in,point,player,false,true)
		if search_path.is_empty():
			print("Search path diagnostic: ",f.id," point=",point," free=",game.world.can_place_circle(point,8,player,false,false)," phase=",game.phase," door body clear=",game.world.door_body_clear(point))
			for solid in game.world.solid_rects(false):
				if preload("res://scripts/core/actor_footprint.gd").hits_rect(point,8,solid): print("Ground blocker: ",solid)
			for solid in game.world.body_solids:
				if solid.has_point(point): print("Body blocker: ",solid)
		check("reachable search aisle "+f.id,not search_path.is_empty())
		player.position=point
		game.room_visibility.tick(0,true)
		check("linen storage searchable "+f.id,game.looting.containers.has(f.id) and game.looting.reason(f.id).is_empty())
	player.position=Vector2(1312,3757)
	game.room_visibility.tick(0,true)
	check("metal folding table search opens",game.looting.open("laundry-folding-table"))
	game.looting.tick(60)
	var loot: Dictionary=game.looting.containers["laundry-folding-table"]
	check("linen contents revealed",not loot.ids.is_empty() and loot.ids.all(func(id):return loot.revealed.get(id,false)))
	if not loot.ids.is_empty():
		var item: String=loot.ids[0]
		var cell: Vector2i=loot.layout[item].position
		check("new table transfers item to backpack",game.looting.take(item).ok)
		check("item can move back into new table",game.looting.move_item(item,"bag","source",cell).ok)
	game.looting.close()
	player.position=Vector2(1400,3650)
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)
	var cover=game.room_visibility.covers.filter(func(v):return v.room.id=="laundry")[0]
	check("roof hidden while inside",not cover.visible)
	check("laundry metal roof and three details registered",cover.style=="laundry" and cover.get_child_count()==3)
	var north_door=game.room_visibility.doorways.by_id("cafeteria-rear")
	check("north door is horizontal shallow facade",not north_door.vertical and north_door.visual_rect.size==Vector2(140,120))
	check("north open and closed states registered",north_door.custom_texture!=null and north_door.closed_custom_texture!=null and north_door.closed_patches.size()==4)
	check("north frame identical between states",north_door.closed_patches.slice(1).all(func(p):return p.texture==north_door.custom_texture))
	var east_door=game.room_visibility.doorways.by_id("laundry-equipment")
	check("east side door stays edge-on",east_door.vertical and east_door.visual_rect.size.x<=24)
	game.map_camera.center_on(area.get_center()+Vector2(0,-40))
	game.map_camera.force_update_scroll()
	await frame()
	game.presentation.tick(0)
	await shot("runtime-interior")
	game.world.set_access_closed("cafeteria-rear",true)
	north_door.refresh(true)
	await shot("runtime-north-closed")
	player.position=Vector2(1450,4050)
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)
	check("roof fully opaque outside",cover.visible and cover.modulate.a==1)
	var plaque=game.world.fixtures.filter(func(f):return f.id=="laundry-sign")[0]
	var plaque_index: int=game.world.fixtures.find(plaque)
	check("exterior plaque visible with roof",game.presentation.volumes.any(func(v):return v.kind=="fixture" and v.wall_index==plaque_index and v.visible))
	await shot("runtime-roof")
	game.queue_free()
	await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await frame()
	await frame()
	editor.open_now(path)
	await frame()
	check("saved map opens and validates in editor",editor.document.validate().errors.is_empty())
	for id in assets.definition_ids:check("new asset offered in editor "+id,editor.catalog.entries.any(func(v):return v.id==id))
	for id in ["laundry_folding_table_v2","laundry_dirty_station_v2","laundry_washer_v2","doorway_laundry_north_open_v2"]:
		var texture: Texture2D=preload("res://scripts/presentation/world_texture.gd").load_asset(editor.canvas.definitions[id])
		check("bounded runtime sprite "+id,texture!=null and maxf(texture.get_width(),texture.get_height())<=512)
	editor.canvas.zoom=0.8
	editor.canvas.origin=editor.canvas.size/2-(area.get_center()+Vector2(0,-40))*editor.canvas.zoom
	editor.canvas.queue_redraw()
	await shot("editor-layout")
	if DisplayServer.get_name()!="headless":
		var performance := {}
		for pair in [["before",OUT+"last-input-map.json"],["after",path]]:
			editor.open_now(pair[1])
			editor.canvas.zoom=0.8
			editor.canvas.origin=editor.canvas.size/2-(area.get_center()+Vector2(0,-40))*editor.canvas.zoom
			await frame()
			var rebuilds: int=editor.canvas.architecture_preview.full_refreshes
			var geometry_builds: int=editor.canvas.architecture_preview.doorways.geometry_builds
			var samples: Array[float]=[]
			for i in range(40):
				var start := Time.get_ticks_usec()
				editor.canvas.origin+=Vector2(2 if i<20 else -2,0)
				editor.canvas.queue_redraw()
				await frame()
				samples.append((Time.get_ticks_usec()-start)/1000.0)
			samples.sort()
			performance[pair[0]]={"median_pan_frame_ms":samples[20],"p95_pan_frame_ms":samples[38],"samples":40,"zoom":0.8,"viewport":editor.canvas.size}
			check("pan retains architecture geometry "+pair[0],editor.canvas.architecture_preview.full_refreshes==rebuilds and editor.canvas.architecture_preview.doorways.geometry_builds==geometry_builds)
		FileAccess.open(OUT+"editor-pan-performance.json",FileAccess.WRITE).store_string(JSON.stringify(performance,"\t"))
	var index: int=editor.document.data.fixtures.find(editor.document.data.fixtures.filter(func(f):return f.id=="laundry-folding-table")[0])
	check("eraser removes metal table from map",editor.document.remove_many([{"group":"fixtures","index":index}])==1 and not editor.document.data.fixtures.any(func(f):return f.id=="laundry-folding-table"))
	editor.document.undo()
	check("undo restores table and asset",editor.document.data.fixtures.any(func(f):return f.id=="laundry-folding-table" and f.asset_id=="laundry_folding_table_v2"))
	var scratch := "res://data/rooms/qa_laundry_redesign_%d.json" % Time.get_ticks_usec()
	check("redesigned map saves to scratch",editor.document.save_file(scratch,true))
	var reloaded=load("res://scripts/editor/map_document.gd").new()
	check("saved scratch reloads",reloaded.open_file(scratch))
	check("scratch preserves fixtures and door layout",reloaded.data.get("fixtures",[])==after.fixtures and reloaded.data.get("access_doors",[])==after.access_doors)
	if FileAccess.file_exists(scratch): DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
	check("QA never writes live map",FileAccess.get_sha256(path)==disk)
	editor.queue_free()
	await frame()
	finish()
