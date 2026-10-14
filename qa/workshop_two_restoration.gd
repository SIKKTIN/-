extends SceneTree
const OUT := "res://docs/art/workshop-two-redesign-v01/"
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
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://workshop-two-qa.cfg")
	root.size=Vector2i(1600,1000)
	root.content_scale_size=root.size
	var path := "res://data/rooms/r04.json"
	var disk := FileAccess.get_sha256(path)
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"last-input-map.json"))
	var after: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"last-output-map.json"))
	var registration: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"map-registration.json"))
	var record: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"asset-registration.json"))
	var intact := true
	for k in before:
		if k not in ["architecture","fixtures","floor_regions","visibility_rooms","ground_details","zones","workshop_two_restoration_version"] and before[k]!=after[k]:
			print("changed field: ",k)
			intact=false
	check("unrelated fields and all access rules preserved",intact)
	check("wall geometry unchanged",before.walls==after.walls)
	check("other ground details preserved",before.ground_details.filter(func(v):return not v.get("workshop_two_generated",false))==after.ground_details.filter(func(v):return not v.get("workshop_two_generated",false)))
	check("other room covers preserved",before.visibility_rooms.filter(func(v):return v.id!="workshop-two")==after.visibility_rooms.filter(func(v):return v.id!="workshop-two"))
	var changed: Array=registration.replaced_fixture_ids+registration.door_fixture_ids+registration.moved_fixture_ids
	check("unrelated furniture preserved",before.fixtures.filter(func(v):return v.id not in changed and not v.get("workshop_two_generated",false))==after.fixtures.filter(func(v):return v.id not in changed and not v.get("workshop_two_generated",false)))
	for a in record.assets: check("unchanged source PNG "+a.key,FileAccess.get_sha256("res://"+a.path)==a.sha256)
	game=load("res://scenes/main.tscn").instantiate()
	game.room_id="r04"
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.get_node("HUD").hide()
	var player=game.actors[0]
	var room: Dictionary=game.room_visibility.rooms.filter(func(v):return v.id=="workshop-two")[0]
	var area: Rect2=room.area
	var center := Vector2(3030,1430)
	player.position=center
	game.guard.position=Vector2(2000,2000)
	game.dog.position=Vector2(1900,2000)
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)
	check("character scale remains 1.4",preload("res://scripts/core/world_scale.gd").HUMAN==1.4)
	var cover=game.room_visibility.covers.filter(func(v):return v.room.id=="workshop-two")[0]
	check("roof hides inside",not cover.visible)
	check("blue gray roof and three rooftop details",cover.style=="workshop_two" and cover.get_child_count()==3)
	var fixtures: Array=game.world.fixtures.filter(func(v):return v.get("workshop_two_generated",false))
	var machines: Array=fixtures.filter(func(v):return v.id.begins_with("campus-work-two-bench-"))
	check("four machines installed",machines.size()==4)
	var overlaps := false
	for i in range(fixtures.size()):
		var a: Dictionary=fixtures[i]
		if not a.blocks_movement:continue
		check("footprint contained "+a.id,area.encloses(a.rect))
		for j in range(i+1,fixtures.size()):
			var b: Dictionary=fixtures[j]
			if b.blocks_movement and a.rect.intersection(b.rect).get_area()>0.01:overlaps=true
	check("no furniture ground overlaps",not overlaps)
	check("patrol starting point clear",game.world.motion_clear(Vector2(3420,1180),Vector2(3420,1182),player,false,true))
	var crossings := {"north":[Vector2(3210,900),Vector2(3210,1200)],"south":[Vector2(2610,1900),Vector2(2610,1660)]}
	var east_y := -1.0
	for y in range(1510,1631,5):
		if game.world.motion_clear(Vector2(3650,y),Vector2(3870,y),player,false,true):east_y=float(y);break
	crossings.east=[Vector2(3870,east_y),Vector2(3650,east_y)]
	print("east full body crossing y=",east_y)
	for side in crossings:
		var pair: Array=crossings[side]
		var id: String="fixture:campus-workshop-two-"+side
		var port: Dictionary=game.world.door_passage.by_id(id)
		var door=game.room_visibility.doorways.by_id(id)
		check(side+" reuses workshop one shared frame and leaves",door.custom_texture!=null and door.open_patches.size()==3 and door.closed_patches.size()==2 and door.open_patches[-1].texture==door.closed_patches[-1].texture)
		check(side+" open full body crossing",game.world.motion_clear(pair[0],pair[1],player,false,true) and game.world.motion_clear(pair[1],pair[0],player,false,true))
		check(side+" central aisle path",not game.world.find_path(center,pair[0],player,false,true).is_empty())
		port.closed=true
		game.world._changed()
		check(side+" closed blocks body",not game.world.motion_clear(pair[0],pair[1],player,false,true))
		port.closed=false
		game.world._changed()
	for f in fixtures:
		if not f.has("loot_profile"):continue
		var point: Vector2=Vector2(f.rect.get_center().x,f.rect.end.y+28)
		if f.id=="workshop-two-stock-rack":point=Vector2(f.rect.end.x+35,f.rect.get_center().y)
		check("search reachable "+f.id,not game.world.find_path(center,point,player,false,true).is_empty())
		player.position=point
		game.room_visibility.tick(0,true)
		check("search available "+f.id,game.looting.containers.has(f.id) and game.looting.reason(f.id).is_empty())
	var chest: Dictionary=fixtures.filter(func(v):return v.id=="campus-work-two-parts")[0]
	player.position=Vector2(chest.rect.get_center().x,chest.rect.end.y+28)
	game.room_visibility.tick(0,true)
	check("parts drawer search opens",game.looting.open(chest.id))
	game.looting.tick(60)
	var loot: Dictionary=game.looting.containers[chest.id]
	check("parts search reveals loot",not loot.ids.is_empty() and loot.ids.all(func(id):return loot.revealed.get(id,false)))
	if not loot.ids.is_empty():
		var item: String=loot.ids[0]
		var cell: Vector2i=loot.layout[item].position
		check("loot taken to bag",game.looting.take(item).ok)
		check("loot dragged back",game.looting.move_item(item,"bag","source",cell).ok)
	game.looting.close()
	player.position=center
	game.room_visibility.tick(0,true)
	game.map_camera.center_on(area.get_center()+Vector2(0,-10))
	game.map_camera.force_update_scroll()
	game.presentation.tick(0)
	await shot("runtime-interior")
	for side in crossings:
		var door=game.room_visibility.doorways.by_id("fixture:campus-workshop-two-"+side)
		door.style="grille"
		door.gate.closed=true
		door.refresh(true)
	await shot("runtime-doors-closed")
	player.position=Vector2(2850,1900)
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)
	check("opaque roof outside",cover.visible and cover.modulate.a==1)
	await shot("runtime-roof")
	game.queue_free()
	await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await frame()
	editor.open_now(path)
	await frame()
	check("map validates in editor",editor.document.validate().errors.is_empty())
	for id in record.definition_ids:check("palette asset "+id,editor.catalog.entries.any(func(v):return v.id==id))
	for id in record.definition_ids:
		if editor.canvas.textures.has(id):
			var texture: Texture2D=editor.canvas.textures[id]
			check("bounded texture "+id,maxf(texture.get_width(),texture.get_height())<=768)
	var index: int=editor.document.data.fixtures.find(editor.document.data.fixtures.filter(func(v):return v.id=="campus-work-two-bench-0")[0])
	var ref := {"group":"fixtures","index":index}
	var original: Dictionary=editor.document.data.fixtures[index].duplicate(true)
	editor.document.mirror_fixture(ref,true)
	check("machine mirror changes orientation",editor.document.data.fixtures[index]!=original)
	editor.document.undo()
	check("machine mirror undo restores",editor.document.data.fixtures[index]==original)
	editor.document.redo()
	check("machine mirror redo works",editor.document.data.fixtures[index]!=original)
	editor.document.undo()
	var transform=preload("res://scripts/editor/map_transform.gd")
	var snapshot: Dictionary=transform.capture(editor.document,[ref],false)
	editor.document.begin()
	transform.apply(editor.document,snapshot,1)
	editor.document.commit()
	check("machine quarter turn changes bounds",editor.document.data.fixtures[index].rect[2]==original.rect[3] and editor.document.data.fixtures[index].rect[3]==original.rect[2])
	editor.document.undo()
	check("machine rotation undo restores",editor.document.data.fixtures[index]==original)
	editor.canvas.zoom=0.65
	editor.resource_search.text="二号车间"
	editor.rebuild_palette()
	editor.canvas.origin=editor.canvas.size/2-(area.get_center()+Vector2(0,-10))*editor.canvas.zoom
	editor.canvas.queue_redraw()
	await shot("editor-layout")
	check("QA does not write map",FileAccess.get_sha256(path)==disk)
	var failed: Array=checks.keys().filter(func(label):return not checks[label])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"workshop_two_checks":checks.size(),"failed":failed}))
	editor.queue_free()
	await frame()
	quit(0 if failed.is_empty() else 1)
