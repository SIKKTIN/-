extends SceneTree
const OUT="res://docs/art/reading-chess-roofs-v1/"
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
func cover(id: String):return game.room_visibility.covers.filter(func(c):return c.room.id==id)[0]
func set_player(point: Vector2):
	game.actors[0].position=point;game.room_visibility.tick(0,true);game.presentation.tick(0)
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://reading-chess-roof-qa.cfg")
	root.size=Vector2i(1280,850);root.content_scale_size=root.size
	var before=raw(OUT+"before.json");var after=raw(OUT+"after.json");var record=raw(OUT+"registration.json")
	for key in before:
		if key not in ["fixtures","visibility_rooms"]:check("preserved map field "+key,before[key]==after[key])
	check("all existing fixtures unchanged",by_id(before.fixtures)==by_id(after.fixtures.filter(func(f):return f.id!="reading-exterior-sign")))
	for room in before.visibility_rooms:
		var a: Dictionary=room.duplicate(true);var b: Dictionary=by_id(after.visibility_rooms)[room.id].duplicate(true)
		if room.id in ["reading-room","chess-room"]:a.erase("roof_style");b.erase("roof_style")
		check("room geometry preserved "+room.id,a==b)
	var assets=preload("res://scripts/presentation/prop_catalog.gd").assets()
	var catalog=preload("res://scripts/editor/editor_catalog.gd").new()
	for entry in record.assets:
		check("original PNG retained "+entry.id,FileAccess.get_sha256(entry.project)==entry.sha256)
		var texture=preload("res://scripts/presentation/world_texture.gd").load_asset(assets[entry.id])
		check("bounded runtime texture "+entry.id,texture!=null and maxf(texture.get_width(),texture.get_height())<=512)
		check("mipmaps retained "+entry.id,texture.get_image().has_mipmaps())
	check("sign has genuine alpha",Image.load_from_file(record.assets[2].project).get_pixel(0,0).a==0)
	check("sign available in editor",catalog.entries.any(func(e):return e.id=="reading_enamel_sign_v1"))
	game=load("res://scenes/main.tscn").instantiate();game.room_id="r04";root.add_child(game);await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.get_node("HUD").hide();game.world.admission_filter=Callable()
	game.guard.position=Vector2(3000,1500);game.dog.position=Vector2(3100,1500)
	var player=game.actors[0]
	var reading=cover("reading-room");var chess=cover("chess-room")
	check("reading uses approved red roof",reading.style=="reading" and reading.roof_texture==preload("res://scripts/presentation/world_texture.gd").load_asset(assets.roof_reading))
	check("chess uses approved gray roof",chess.style=="chess" and chess.roof_texture==preload("res://scripts/presentation/world_texture.gd").load_asset(assets.roof_chess))
	check("details are not duplicated",reading.get_child_count()==0 and chess.get_child_count()==0)
	for c in [reading,chess]:
		var spec: Dictionary=by_id(before.visibility_rooms)[c.room.id].duplicate(true)
		spec.area=Rect2(spec.rect[0],spec.rect[1],spec.rect[2],spec.rect[3])
		var layout=preload("res://scripts/presentation/roof_geometry.gd").plan(game.world,spec)
		check("unchanged roof envelope "+c.room.id,layout.roof==c.roof and layout.panels==c.panels and layout.cutouts==c.cutouts)
	set_player(Vector2(780,700))
	game.map_camera.zoom=Vector2(0.83,0.83);game.map_camera.position=Vector2(800,485)-Vector2(root.size)/0.83/2;game.map_camera.force_update_scroll()
	var f: Dictionary=by_id(game.world.fixtures)["reading-exterior-sign"]
	var fi=game.world.fixtures.find(f)
	var volume=game.presentation.volumes.filter(func(v):return v.kind=="fixture" and v.wall_index==fi)[0]
	check("both roofs opaque outside",reading.visible and reading.modulate.a==1 and chess.visible and chess.modulate.a==1)
	check("reading sign visible outside above coping",volume.visible and volume.z_index==4096)
	check("bounded texture preserves readable sign width",is_equal_approx(volume.display_rect.size.x,115))
	check("sign remains nonblocking",not f.get("blocks_movement",false) and not f.get("blocks_sight",false))
	var reading_door=game.room_visibility.doorways.by_id("fixture:reading-room-entry")
	# Only the mounting tab touches the wall; the plate stays outside the aperture.
	var plate: Rect2=volume.display_rect
	plate.position.x+=plate.size.x*.15;plate.size.x*=.85
	check("sign plate clear of reading opening",not plate.intersects(reading_door.visual_rect))
	check("reading bidirectional whole-body passage",game.world.motion_clear(Vector2(740,470),Vector2(590,470),player,false,true) and game.world.motion_clear(Vector2(590,470),Vector2(740,470),player,false,true))
	await shot("runtime-exterior")
	set_player(Vector2(550,446));await frame()
	check("reading roof hidden inside",game.room_visibility.active_id=="reading-room" and not reading.visible and chess.visible)
	check("sign still visible inside",volume.visible)
	await shot("runtime-reading-interior")
	set_player(Vector2(780,700));check("reading roof restored after exit",reading.visible and reading.modulate.a==1)
	game.world.set_access_closed("chess-entry",false);game.room_visibility.doorways.tick(true)
	var gate=game.world.access_by_id("chess-entry");var center: Vector2=gate.rect.get_center()
	# The unrelated workshop starts at y940; use the clear approach outside this door.
	var outside=center+Vector2(0,90);var inside=center-Vector2(0,90)
	check("chess entrance whole-body passage",game.world.motion_clear(outside,inside,player,false,true) and game.world.motion_clear(inside,outside,player,false,true))
	set_player(inside);await frame()
	check("chess roof hidden inside",game.room_visibility.active_id=="chess-room" and not chess.visible and reading.visible)
	await shot("runtime-chess-interior")
	set_player(Vector2(780,700));await frame()
	check("chess roof restored after exit",chess.visible and chess.modulate.a==1)
	var builds=[reading.draw_builds,chess.draw_builds]
	for i in 12:game.map_camera.position.x+=1;game.map_camera.force_update_scroll();game.presentation.tick(0);await frame()
	check("camera and AI ticks do not rebuild roofs",builds==[reading.draw_builds,chess.draw_builds])
	game.queue_free();await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor);await frame();await frame();editor.open_now("res://data/rooms/r04.json");await frame()
	check("saved map validates",editor.document.validate().errors.is_empty())
	check("both styles editable and round trip",preload("res://scripts/presentation/room_cover.gd").style_for(by_id(editor.document.data.visibility_rooms)["reading-room"])=="reading" and preload("res://scripts/presentation/room_cover.gd").style_for(by_id(editor.document.data.visibility_rooms)["chess-room"])=="chess")
	editor.canvas.zoom=.68;editor.canvas.origin=editor.canvas.size/2-Vector2(785,460)*.68;editor.canvas.queue_redraw();editor.subcategory_picker.select(0);editor.resource_search.text="阅览室";editor.rebuild_palette()
	await shot("editor")
	check("QA does not write map state",by_id(raw("res://data/rooms/r04.json").fixtures)["reading-room-entry"]==by_id(after.fixtures)["reading-room-entry"])
	var failed=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"count":checks.size(),"checks":checks,"failed":failed},"\t"))
	print("Reading/chess roofs QA: ",checks.size()," checks; failures=",failed)
	quit(0 if failed.is_empty() else 1)
