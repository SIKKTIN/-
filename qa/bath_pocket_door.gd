extends SceneTree
const OUT="res://docs/art/bath-pocket-door-v1/"
var checks={}
var game
func _initialize():
	create_timer(120).timeout.connect(func():quit(124))
	call_deferred("run")
func raw(path: String) -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(path))
func check(label: String,ok: bool):
	checks[label]=ok
	if not ok:print("FAIL: ",label)
func frame():
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func shot(name: String):
	await frame();await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+name+".png")
func by_id(values: Array) -> Dictionary:
	var result={}
	for value in values:result[value.id]=value
	return result
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://bath-pocket-door-qa.cfg")
	root.size=Vector2i(1200,850);root.content_scale_size=root.size
	var before=raw(OUT+"input-map.json");var after=raw(OUT+"output-map.json");var record=raw(OUT+"registration.json")
	check("other furniture and player arrangement preserved",by_id(before.fixtures.filter(func(f):return f.id!="campus-bath"))==by_id(after.fixtures.filter(func(f):return f.id!="campus-bath")))
	for key in before:
		if key!="fixtures":check("map field preserved "+str(key),before[key]==after[key])
	check("original generated PNG retained",FileAccess.get_sha256(record.project_png)==record.image_sha256)
	var atlas=Image.load_from_file(record.project_png)
	check("open aperture truly transparent",atlas.get_pixel(1400,400).a==0)
	game=load("res://scenes/main.tscn").instantiate();game.room_id="r04";root.add_child(game);await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.get_node("HUD").hide()
	var fixture: Dictionary=game.world.fixtures.filter(func(f):return f.id=="campus-bath")[0]
	var player=game.actors[0];var center: Vector2=fixture.rect.get_center()
	var outside=center+Vector2(0,-160);var inside=center+Vector2(0,130)
	game.guard.position=Vector2(3000,1500);game.dog.position=Vector2(3100,1500)
	var door=game.room_visibility.doorways.by_id("fixture:campus-bath")
	check("door aligned to current moved facade",door.visual_rect.position==Vector2(record.visual_rect[0],record.visual_rect[1]) and door.visual_rect.end.y==fixture.rect.end.y)
	check("compact frame width and full wall height",door.visual_rect.size==Vector2(140,120))
	check("free bath entrance remains open",not door.closed)
	check("whole body crosses both directions",game.world.motion_clear(outside,inside,player,false,true) and game.world.motion_clear(inside,outside,player,false,true))
	for x in [-25,25]:check("crossing offset "+str(x),game.world.motion_clear(outside+Vector2(x,0),inside+Vector2(x,0),player,false,true))
	var definitions=preload("res://scripts/presentation/prop_catalog.gd").assets()
	var lockers: Dictionary=game.world.fixtures.filter(func(f):return f.id=="campus-bath-locker-0")[0]
	var locker_rect: Rect2=preload("res://scripts/presentation/prop_proportions.gd").display_rect(definitions[lockers.asset_id],lockers.rect)
	check("door art does not overlap changing lockers",not door.visual_rect.intersects(locker_rect))
	check("open and closed use identical shared jambs",door.open_patches.size()==3 and door.closed_patches.size()==4 and door.closed_patches.slice(1).all(func(p):return p.texture==door.custom_texture))
	player.position=inside;game.room_visibility.tick(0,true);game.presentation.tick(0)
	game.map_camera.zoom=Vector2(1.5,1.5);game.map_camera.position=center+Vector2(15,50)-Vector2(root.size)/1.5/2;game.map_camera.force_update_scroll()
	await shot("runtime-open")
	# Temporary runtime-only closed state checks the new panel art and body
	# obstruction; saved public entrance remains freely open as before.
	var portal: Dictionary=game.world.door_passage.by_id("fixture:campus-bath")
	portal.closed=true;game.world._changed()
	door.style="static";door.gate.closed=true;door.refresh(true)
	check("closed panels block whole-body crossing",not game.world.motion_clear(outside,inside,player,false,true) and not game.world.motion_clear(inside,outside,player,false,true))
	await shot("runtime-closed")
	portal.closed=false;game.world._changed();door.style="free";door.gate.closed=false;door.refresh(true)
	player.position=outside;game.room_visibility.tick(0,true);game.presentation.tick(0)
	var cover=game.room_visibility.covers.filter(func(c):return c.room.id=="bath")[0]
	check("bath roof stays opaque outside",cover.visible and cover.modulate.a==1)
	await shot("runtime-roof")
	game.queue_free();await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor);await frame();await frame()
	editor.open_now("res://data/rooms/r04.json");await frame()
	check("saved map validates",editor.document.validate().errors.is_empty())
	for id in record.definition_ids:
		check("new door in editor palette "+id,editor.catalog.entries.any(func(a):return a.id==id))
		var texture: Texture2D=preload("res://scripts/presentation/world_texture.gd").load_asset(definitions[id])
		check("bounded runtime texture "+id,texture!=null and maxf(texture.get_width(),texture.get_height())<=512)
	editor.canvas.zoom=1.15;editor.canvas.origin=editor.canvas.size/2-(center+Vector2(0,80))*1.15;editor.canvas.queue_redraw()
	editor.resource_search.text="浴室北入口";editor.rebuild_palette()
	await shot("editor-layout")
	var saved: Dictionary=by_id(raw("res://data/rooms/r04.json").fixtures)["campus-bath"]
	check("QA never writes the door state to live map",saved==by_id(after.fixtures)["campus-bath"])
	var failed=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"count":checks.size(),"checks":checks,"failed":failed},"\t"))
	print("Bath pocket door QA: ",checks.size()," checks; failures=",failed)
	quit(0 if failed.is_empty() else 1)
