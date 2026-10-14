extends SceneTree
const OUT := "res://docs/art/warehouse-redesign-v01/"
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
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://warehouse-qa.cfg")
	root.size=Vector2i(1100,2500)
	root.content_scale_size=root.size
	var path := "res://data/rooms/r04.json"
	var disk := FileAccess.get_sha256(path)
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"last-input-map.json"))
	var initial: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"initial-input-map.json"))
	var after: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"last-output-map.json"))
	var reg: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"map-registration.json"))
	var record: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"asset-registration.json"))
	var intact := true
	for k in before:
		if k not in ["architecture","fixtures","floor_regions","visibility_rooms","ground_details","zones","warehouse_restoration_version","warehouse_boundary_repair_version","walls","crate","items"] and before[k]!=after[k]:intact=false
	check("unrelated map fields and access rules preserved",intact)
	var walls_ok: bool = before.walls.size()==after.walls.size()
	for i in range(before.walls.size()):
		if not reg.modified_wall_indices.any(func(v):return int(v)==i) and before.walls[i]!=after.walls[i]:walls_ok=false
	check("wall geometry outside repaired warehouse corner preserved",walls_ok)
	check("ground supply definitions preserved",before.items.map(func(v):return v.definition_id)==after.items.map(func(v):return v.definition_id))
	check("other room covers preserved",before.visibility_rooms.filter(func(v):return v.id!="warehouse")==after.visibility_rooms.filter(func(v):return v.id!="warehouse"))
	check("other floors preserved",before.floor_regions.filter(func(v):return v.id!="campus-warehouse")==after.floor_regions.filter(func(v):return v.id!="campus-warehouse"))
	var ids: Array=reg.replaced_fixture_ids+reg.door_fixture_ids
	check("other furniture preserved",before.fixtures.filter(func(v):return v.id not in ids and not v.get("warehouse_generated",false))==after.fixtures.filter(func(v):return v.id not in ids and not v.get("warehouse_generated",false)))
	check("unrelated wall art preserved",before.architecture.wall_surfaces.filter(func(v):return not reg.selected_walls.any(func(i):return int(i)==int(v.wall_index)))==after.architecture.wall_surfaces.filter(func(v):return not reg.selected_walls.any(func(i):return int(i)==int(v.wall_index))))
	for f in initial.fixtures:
		if f.id in reg.replaced_fixture_ids and f.has("loot_profile"):check("container ID preserved "+f.id,after.fixtures.any(func(v):return v.id==f.id and v.get("loot_profile","")==f.loot_profile))
	for a in record.assets:check("original sprite unchanged "+a.key,FileAccess.get_sha256("res://"+a.path)==a.sha256)
	game=load("res://scenes/main.tscn").instantiate()
	game.room_id="r04"
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.get_node("HUD").hide()
	var player=game.actors[0]
	var center := Vector2(4690,2330)
	player.position=center
	game.guard.position=Vector2(3000,2000)
	game.dog.position=Vector2(3050,2000)
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)
	var cover=game.room_visibility.covers.filter(func(v):return v.room.id=="warehouse")[0]
	var area: Rect2=cover.area
	check("west boundary follows physical wall",area.position.x==4280 and area.end.x==5120)
	check("warehouse roof hides inside",not cover.visible)
	check("warehouse metal roof has vents and skylights",cover.style=="warehouse" and cover.get_child_count()==4)
	check("character scale unchanged",preload("res://scripts/core/world_scale.gd").HUMAN==1.4)
	var fixtures: Array=game.world.fixtures.filter(func(v):return v.get("warehouse_generated",false))
	check("four long central racks",fixtures.filter(func(v):return v.asset_id in ["warehouse_rack_parts_v1","warehouse_rack_goods_v1"]).size()==4)
	check("seven peripheral rack runs",fixtures.filter(func(v):return v.asset_id=="warehouse_wall_rack_v1").size()==7)
	var overlaps := false
	for i in range(fixtures.size()):
		var a: Dictionary=fixtures[i]
		if not a.blocks_movement:continue
		check("ground footprint in room "+a.id,area.encloses(a.rect))
		for j in range(i+1,fixtures.size()):
			var b: Dictionary=fixtures[j]
			if b.blocks_movement and a.rect.intersection(b.rect).get_area()>.01:overlaps=true;print("overlap ",a.id," / ",b.id)
	check("no ground overlap",not overlaps)
	check("pushable crate does not overlap storage",fixtures.all(func(f):return not f.blocks_movement or f.rect.intersection(game.world.crate).get_area()<.01))
	check("southwest wall closes former bypass",not game.world.motion_clear(Vector2(4200,3070),Vector2(4390,3070),player,false,true))
	check("central north south aisle clear",game.world.motion_clear(Vector2(4690,1185),Vector2(4690,3185),player,false,true))
	var crossings := {}
	for side in ["west","east-north","east-south"]:
		var id: String="fixture:campus-warehouse-"+side
		var port: Dictionary=game.world.door_passage.by_id(id)
		var door=game.room_visibility.doorways.by_id(id)
		var gate: Rect2=port.rect
		var west: bool=side=="west"
		var entry_y := -1.0
		var outside_x := 4165.0 if west else 5190.0
		var inside_x := 4400.0 if west else 4960.0
		for y in range(int(gate.position.y)+20,int(gate.end.y)+31,5):
			if game.world.motion_clear(Vector2(outside_x,y),Vector2(inside_x,y),player,false,true):entry_y=float(y);break
		crossings[side]=[Vector2(outside_x,entry_y),Vector2(inside_x,entry_y)]
		print(side," full body entry y=",entry_y)
	crossings.south=[Vector2(4690,3360),Vector2(4690,3080)]
	for side in crossings:
		var pair: Array=crossings[side]
		var id: String="fixture:campus-warehouse-"+side
		var port: Dictionary=game.world.door_passage.by_id(id)
		var door=game.room_visibility.doorways.by_id(id)
		check(side+" common steel frame and leaves",door.open_patches.size()==3 and door.closed_patches.size()==2 and door.open_patches[-1].texture==door.closed_patches[-1].texture)
		check(side+" full body two way crossing",game.world.motion_clear(pair[0],pair[1],player,false,true) and game.world.motion_clear(pair[1],pair[0],player,false,true))
		check(side+" entrance connected to central aisle",not game.world.find_path(center,pair[0],player,false,true).is_empty())
		port.closed=true
		game.world._changed()
		check(side+" closed blocks full body",not game.world.motion_clear(pair[0],pair[1],player,false,true))
		port.closed=false
		game.world._changed()
	var points := {}
	for f in fixtures:
		if not f.has("loot_profile"):continue
		var r: Rect2=f.rect
		var candidates := [Vector2(r.position.x-30,r.get_center().y+30),Vector2(r.end.x+30,r.get_center().y+30),Vector2(r.get_center().x,r.end.y+30),Vector2(r.get_center().x,r.position.y-30)]
		var found := false
		for point in candidates:
			if not area.has_point(point) or game.world.find_path(center,point,player,false,true).is_empty():continue
			player.position=point
			game.room_visibility.tick(0,true)
			if game.looting.reason(f.id).is_empty():found=true;points[f.id]=point;break
		check("reachable searchable storage "+f.id,found)
	var id := "warehouse-rack-0"
	if points.has(id):
		player.position=points[id]
		game.room_visibility.tick(0,true)
		check("new rack opens search",game.looting.open(id))
		game.looting.tick(60)
		var loot: Dictionary=game.looting.containers[id]
		check("search discovers rack supplies",not loot.ids.is_empty() and loot.ids.all(func(i):return loot.revealed.get(i,false)))
		if not loot.ids.is_empty():
			var item: String=loot.ids[0]
			var cell: Vector2i=loot.layout[item].position
			check("rack loot transfers to bag",game.looting.take(item).ok)
			check("rack loot drags back",game.looting.move_item(item,"bag","source",cell).ok)
		game.looting.close()
	player.position=center
	game.room_visibility.tick(0,true)
	game.items_view.queue_redraw()
	game.map_camera.zoom=Vector2(.95,.95)
	game.map_camera.center_on(Vector2(4700,2110))
	game.map_camera.force_update_scroll()
	game.presentation.tick(0)
	await shot("runtime-interior")
	for side in crossings:
		var door=game.room_visibility.doorways.by_id("fixture:campus-warehouse-"+side)
		door.style="grille"
		door.gate.closed=true
		door.refresh(true)
	await shot("runtime-doors-closed")
	player.position=Vector2(4200,2130)
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)
	check("opaque roof restored outside",cover.visible and cover.modulate.a==1)
	await shot("runtime-roof")
	game.queue_free()
	await frame()
	root.size=Vector2i(1280,800)
	root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await frame()
	editor.open_now(path)
	await frame()
	check("editor map validation",editor.document.validate().errors.is_empty())
	for asset in record.definition_ids:
		check("asset registered in palette "+asset,editor.catalog.entries.any(func(v):return v.id==asset))
		if editor.canvas.textures.has(asset):
			var texture: Texture2D=editor.canvas.textures[asset]
			check("bounded runtime sprite "+asset,maxf(texture.get_width(),texture.get_height())<=1024)
	var index: int=editor.document.data.fixtures.find(editor.document.data.fixtures.filter(func(v):return v.id=="warehouse-rack-0")[0])
	var ref := {"group":"fixtures","index":index}
	var original: Dictionary=editor.document.data.fixtures[index].duplicate(true)
	editor.document.mirror_fixture(ref,true)
	check("rack mirror supported",editor.document.data.fixtures[index]!=original)
	editor.document.undo()
	check("mirror undo restores original",editor.document.data.fixtures[index]==original)
	var transform=preload("res://scripts/editor/map_transform.gd")
	var snapshot: Dictionary=transform.capture(editor.document,[ref],false)
	editor.document.begin()
	transform.apply(editor.document,snapshot,1)
	editor.document.commit()
	check("rack rotation swaps ground size",editor.document.data.fixtures[index].rect[2]==original.rect[3])
	editor.document.undo()
	check("rotation undo restores original",editor.document.data.fixtures[index]==original)
	editor.canvas.zoom=.24
	editor.canvas.origin=editor.canvas.size/2-Vector2(4700,2110)*editor.canvas.zoom
	editor.resource_search.text="仓库"
	editor.rebuild_palette()
	editor.canvas.queue_redraw()
	await shot("editor-layout")
	check("QA leaves saved map intact",FileAccess.get_sha256(path)==disk)
	var failed: Array=checks.keys().filter(func(label):return not checks[label])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"entrances":crossings},"\t"))
	print(JSON.stringify({"warehouse_checks":checks.size(),"failed":failed}))
	editor.queue_free()
	await frame()
	quit(0 if failed.is_empty() else 1)
