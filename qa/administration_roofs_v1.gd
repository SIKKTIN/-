extends SceneTree

const OUT := "res://docs/art/administration-roofs-v1/"
const Cover = preload("res://scripts/presentation/room_cover.gd")
const Geometry = preload("res://scripts/presentation/roof_geometry.gd")
var checks := {}
var game
var saved_map_hash := ""

func _initialize():
	create_timer(120).timeout.connect(func():quit(124))
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://administration-roof-qa.cfg")
	OS.set_environment("ESCAPE_MENU_SETTINGS_PATH","user://administration-roof-menu-qa.cfg")
	call_deferred("run")

func check(label: String, ok: bool):
	checks[label] = ok
	if not ok: print("FAIL: ", label)

func read(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func frame():
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func shot(id: String):
	await frame(); await frame()
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(OUT+id+".png")

func cover(id: String):
	return game.room_visibility.covers.filter(func(c):return c.room.id == id)[0]

func position_player(point: Vector2):
	game.actors[0].position = point
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)

func run():
	root.size = Vector2i(1280,850)
	root.content_scale_size = root.size
	saved_map_hash = FileAccess.get_sha256("res://data/rooms/r04.json")
	var before := read(OUT+"input-map.json")
	var after := read("res://data/rooms/r04.json")
	for field in before:
		if field != "visibility_rooms": check("unchanged map field "+field,before[field] == after[field])
	var original_rooms := {}
	for room in before.visibility_rooms: original_rooms[room.id] = room
	for room in after.visibility_rooms:
		var previous: Dictionary = original_rooms[room.id].duplicate(true)
		var current: Dictionary = room.duplicate(true)
		if room.id in ["office","duty"]:
			for key in ["roof_style","roof_asset_id"]: previous.erase(key); current.erase(key)
		check("room geometry and metadata preserved "+str(room.id),previous == current)
	var entries := preload("res://scripts/presentation/prop_catalog.gd").assets()
	var expected: Dictionary = read("res://art/architecture/administration_roofs_v1/manifest.json")
	for asset in expected.assets:
		check("source PNG unchanged "+asset.id,FileAccess.get_sha256(asset.texture) == asset.sha256)
		var texture = preload("res://scripts/presentation/world_texture.gd").load_asset(entries[asset.id])
		check("bounded roof pixels "+asset.id,texture != null and maxi(texture.get_width(),texture.get_height()) <= 512)
		check("mipmaps available "+asset.id,texture.get_image().has_mipmaps())
		check("source roof remains opaque "+asset.id,texture.get_image().detect_alpha() == Image.ALPHA_NONE)
		check("prebuilt runtime roof "+asset.id,preload("res://scripts/presentation/runtime_texture_store.gd").texture(asset) != null)
	game = load("res://scenes/main.tscn").instantiate()
	game.room_id = "r04"
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.get_node("HUD").hide()
	game.world.admission_filter = Callable()
	var duty = cover("duty")
	var office = cover("office")
	for pair in [[duty,"duty"],[office,"office"]]:
		var c = pair[0]
		var id: String = pair[1]
		check("approved style "+id,c.style == id and c.roof_texture == preload("res://scripts/presentation/world_texture.gd").load_asset(entries["roof_"+id]))
		check("no duplicated roof attachments "+id,c.get_child_count() == 0)
		check("one fitted membrane "+id,c.roof_tile == c.roof.size)
		var spec: Dictionary = original_rooms[id].duplicate(true)
		spec.area = Rect2(spec.rect[0],spec.rect[1],spec.rect[2],spec.rect[3])
		var old_plan := Geometry.plan(game.world,spec)
		check("unchanged roof envelope "+id,old_plan.roof == c.roof and old_plan.panels == c.panels and old_plan.cutouts == c.cutouts)
	position_player(Vector2(4220,770))
	check("both roofs solid outside",duty.visible and duty.modulate.a == 1 and office.visible and office.modulate.a == 1)
	game.map_camera.zoom = Vector2.ONE
	game.map_camera.position = Vector2(3620,50)
	game.map_camera.force_update_scroll()
	game.presentation.tick(0)
	await shot("runtime-exterior")
	game.map_camera.zoom = Vector2.ONE*.8
	game.map_camera.position = Vector2(3480,60)
	game.map_camera.force_update_scroll()
	game.presentation.tick(0)
	await shot("runtime-exterior-08")
	game.world.set_access_closed("office-entry",false)
	game.room_visibility.tick(0,true)
	for pair in [["duty",3990.0],["office",4450.0]]:
		var outside := Vector2(pair[1],790)
		var inside := Vector2(pair[1],605)
		check("open full body door passage "+pair[0],game.world.motion_clear(outside,inside,game.actors[0],false,true) and game.world.motion_clear(inside,outside,game.actors[0],false,true))
	position_player(Vector2(3990,500))
	check("duty roof hides inside only",game.room_visibility.active_id == "duty" and not duty.visible and office.visible)
	await shot("runtime-duty-interior")
	position_player(Vector2(4450,500))
	check("office roof hides inside only",game.room_visibility.active_id == "office" and not office.visible and duty.visible)
	await shot("runtime-office-interior")
	position_player(Vector2(4220,770))
	check("both roofs restored after leaving",duty.visible and office.visible and duty.modulate.a == 1 and office.modulate.a == 1)
	# Reappearing CanvasItems draw once; measure only the settled steady state.
	await frame(); await frame()
	var builds := [duty.draw_builds,office.draw_builds]
	for i in 8:
		game.map_camera.position.x += 1
		game.map_camera.force_update_scroll()
		game.presentation.tick(0)
		await frame()
	check("camera motion reuses roof draw commands",builds == [duty.draw_builds,office.draw_builds])
	game.world.set_access_closed("office-entry",true)
	check("closed office remains blocking",not game.world.motion_clear(Vector2(4450,790),Vector2(4450,605),game.actors[0],false,true))
	game.queue_free()
	await frame()
	var editor = load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await frame()
	editor.open_now("res://data/rooms/r04.json")
	await frame()
	check("saved map validates in editor",editor.document.validate().errors.is_empty())
	for id in ["duty","office"]:
		var index: int = -1
		for i in editor.document.data.visibility_rooms.size():
			if editor.document.data.visibility_rooms[i].id == id: index = i
		editor.selection = {"group":"visibility_rooms","index":index}
		editor.refresh_inspector()
		var picker = editor.inspector.find_child("RoofStyle",true,false)
		check("editor shows selected roof "+id,picker != null and picker.get_item_text(picker.selected).contains("值班室" if id == "duty" else "办公室"))
	check("QA leaves production map unchanged",FileAccess.get_sha256("res://data/rooms/r04.json") == saved_map_hash)
	var failed: Array = checks.keys().filter(func(key):return not checks[key])
	FileAccess.open(OUT+("headless" if DisplayServer.get_name() == "headless" else "native")+"-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"count":checks.size(),"failed":failed,"checks":checks},"\t"))
	print("Administration roofs: ", checks.size(), " checks; failures=", failed)
	quit(0 if failed.is_empty() else 1)
