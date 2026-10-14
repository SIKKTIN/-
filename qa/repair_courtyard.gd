extends SceneTree
const OUT := "res://docs/art/repair-courtyard-v1/"
const Catalog = preload("res://scripts/presentation/prop_catalog.gd")
const Textures = preload("res://scripts/presentation/world_texture.gd")
var checks := {}
var game
func _initialize():call_deferred("run")
func raw(path: String) -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(path))
func check(label: String,value: bool):
	checks[label]=value
	if not value:print("FAILED: ",label)
func frame():
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func shot(name: String):
	await frame();await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+name+".png")
func key(code: int,pressed: bool):
	var event:=InputEventKey.new();event.keycode=code;event.pressed=pressed;game.mobile_controls._input(event)
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://repair-courtyard-qa.cfg")
	root.size=Vector2i(1500,1050);root.content_scale_size=root.size;Engine.max_fps=60
	var path:="res://data/rooms/r04.json"
	var disk:=FileAccess.get_sha256(path)
	var before:=raw(OUT+"before-map.json")
	var after:=raw(path)
	var registration:=raw(OUT+"registration.json")
	var production:=raw(OUT+"production-assets.json")
	var parallel:=raw(OUT+"parallel-map-changes.json") if FileAccess.file_exists(OUT+"parallel-map-changes.json") else {"floor_changes":[]}
	var parallel_ids: Array=parallel.floor_changes.map(func(f):return f.id)
	for change in parallel.floor_changes:
		check("parallel floor edit retained "+change.id,after.floor_regions.filter(func(f):return f.id==change.id)[0]==change.after)
	for field in before:
		if field not in ["fixtures","floor_regions"]:check("other map data retained "+field,before[field]==after[field])
	check("other fixtures retained",before.fixtures.filter(func(f):return f.id not in registration.removed_fixture_ids)==after.fixtures.filter(func(f):return not f.get("repair_courtyard_generated",false)))
	check("other ground retained",before.floor_regions.filter(func(f):return f.id not in registration.removed_floor_ids+registration.changed_floor_ids+parallel_ids)==after.floor_regions.filter(func(f):return f.id not in registration.changed_floor_ids+parallel_ids))
	check("old tent removed",not after.fixtures.any(func(f):return f.id=="energy-court-parts-canopy"))
	var document=load("res://scripts/editor/map_document.gd").new()
	check("map loads",document.open_file(path))
	check("map validates",document.validate().errors.is_empty())
	var definitions:=Catalog.assets()
	var bytes:=0
	for source in production.pngs:
		check("original PNG retained "+source.key,FileAccess.get_sha256("res://"+source.path)==source.sha256)
		var image:=Image.load_from_file("res://"+source.path)
		check("transparent sprite "+source.key,image.detect_alpha()!=Image.ALPHA_NONE and image.get_pixel(0,0).a==0)
	for id in production.definition_ids:
		check("catalog asset "+id,definitions.has(id))
		var texture:=Textures.load_asset(definitions[id])
		check("runtime texture "+id,texture!=null)
		if texture!=null:
			bytes+=int(texture.get_width()*texture.get_height()*4*4.0/3)
			check("bounded texture "+id,maxi(texture.get_width(),texture.get_height())<=int(definitions[id].get("runtime_size_limit",1024)))
	game=load("res://scenes/main.tscn").instantiate();game.room_id="r04";root.add_child(game)
	await frame();await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.get_node("HUD").hide()
	game.phase="playing";game.selected_actor_id=0;game.schedule.close();game.orders.clear()
	for actor in game.room_access.dorm_occupants():
		actor.set_process(false);actor.set_physics_process(false);actor.position=Vector2(2800,3000)
	game.guard.position=Vector2(2800,3000);game.dog.position=Vector2(2800,3000)
	var player=game.actors[0]
	var world=game.world
	check("warehouse front apron clear",world.motion_clear(Vector2(4690,3330),Vector2(4790,3380),player,false,true))
	check("north south central passage clear",world.motion_clear(Vector2(4790,3380),Vector2(4790,4090),player,false,true))
	check("connection toward loading yard clear",world.motion_clear(Vector2(4770,3790),Vector2(5240,3790),player,false,true))
	check("south service road clear",world.motion_clear(Vector2(4290,4090),Vector2(5400,4090),player,false,true))
	check("open repair bay has no full canopy air wall",world.motion_clear(Vector2(4740,3655),Vector2(4565,3655),player,false,true))
	player.position=Vector2(4790,3380)
	key(KEY_S,true)
	for step in 240:
		game.mobile_controls.tick(1.0/60)
		if player.position.y>=4090:break
	key(KEY_S,false)
	check("actual controls reach south road",player.position.y>=4090)
	key(KEY_W,true)
	for step in 240:
		game.mobile_controls.tick(1.0/60)
		if player.position.y<=3380:break
	key(KEY_W,false)
	check("actual controls return to warehouse apron",player.position.y<=3380)
	player.position=Vector2(4790,3790)
	var goal:=Vector2(5240,3790)
	check("click route to loading area accepted",game.orders.issue(0,goal))
	for step in 300:game.orders.tick(1.0/60)
	check("click route reaches loading area",player.position.distance_to(goal)<5)
	game.orders.clear()
	for fixture in world.fixtures.filter(func(f):return f.get("repair_courtyard_generated",false)):
		if fixture.blocks_movement:
			check("physical obstacle "+fixture.id,not world.fixture_collision_rects(fixture).is_empty())
		if fixture.has("canopy_cover"):
			check("canopy only blocks posts "+fixture.id,fixture.solid_parts.size()>=1 and not world.fixture_collision_rects(fixture).has(fixture.rect))
	player.position=Vector2(4780,3730)
	game.map_camera.following=false;game.map_camera.zoom=Vector2(1,1)
	game.map_camera.position=Vector2(4550,3540)-Vector2(root.size)/2
	game.map_camera.force_update_scroll();game.room_visibility.tick(0,true);game.presentation.tick(0)
	game.presentation.interaction.hint.hide()
	await shot("runtime-restored")
	# Check that canopy transparency uses the existing game mechanism.
	var north=game.presentation.canopy_volumes.filter(func(v):return world.fixtures[v.wall_index].id=="repair-court-shed-north")[0]
	player.position=Vector2(4490,3420);game.presentation.tick(0)
	check("roof fades when standing under canopy",is_equal_approx(north.modulate.a,.32))
	player.position=Vector2(4780,3730);game.presentation.tick(0)
	check("roof opaque when outside canopy",is_equal_approx(north.modulate.a,1))
	game.queue_free();await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await frame();await frame();editor.open_now(path);await frame();await frame()
	for id in production.definition_ids:check("editor palette "+id,editor.catalog.entries.any(func(e):return e.id==id))
	for id in registration.added_fixture_ids:
		var fixture: Dictionary=editor.document.data.fixtures.filter(func(f):return f.id==id)[0]
		var ref: Dictionary={"group":"fixtures","index":editor.document.data.fixtures.find(fixture)}
		check("component selectable "+id,not editor.canvas.architecture_preview.visual_hit_areas(ref).is_empty())
		check("component removable "+id,editor.document.can_remove(ref))
		var original:=JSON.stringify(editor.document.data)
		editor.document.remove(ref);editor.document.undo()
		check("undo preserves component "+id,JSON.stringify(editor.document.data)==original)
	editor.canvas.zoom=.86;editor.canvas.origin=editor.canvas.size/2-Vector2(4490,3520)*editor.canvas.zoom
	editor.resource_search.text="维修小院";editor.rebuild_palette();editor.canvas.queue_redraw()
	await shot("editor-restored")
	check("QA does not save map",FileAccess.get_sha256(path)==disk)
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks-native.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"runtime_texture_mib":bytes/1048576.0},"\t"))
	print(JSON.stringify({"repair_courtyard_checks":checks.size(),"failed":failed,"runtime_texture_mib":bytes/1048576.0}))
	quit(0 if failed.is_empty() else 1)
