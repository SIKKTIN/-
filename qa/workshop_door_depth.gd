extends SceneTree
const OUT = "res://docs/art/workshop-one-restoration/door-depth/"
const Depth = preload("res://scripts/presentation/world_depth.gd")
var checks := {}
func check(label: String, passed: bool): checks[label] = passed
func _initialize(): call_deferred("run")
func frame():
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func shot(name: String):
	await frame(); await frame()
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(OUT+name+".png")
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1280,800); root.content_scale_size = root.size
	var disk := FileAccess.get_sha256("res://data/rooms/r04.json")
	var editor = load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor); await frame(); await frame()
	var preview = editor.canvas.architecture_preview
	var original: Dictionary = editor.document.data.duplicate(true)
	var first = preview.doorways.by_id("workshop-entry")
	editor.canvas.zoom = 1.5
	editor.canvas.origin = editor.canvas.size/2-(first.visual_rect.get_center()+Vector2(0,-55))*editor.canvas.zoom
	editor.canvas.queue_redraw()
	for id in ["workshop-entry","workshop-entry-east"]:
		var door = preview.doorways.by_id(id)
		check(id+" art uses raised sorting", door.gate.get("raised_door",false))
		check(id+" sorted at footline", not door.z_as_relative and door.z_index==Depth.for_y(door.gate.rect.end.y,preview.world.bounds.end.y)+1)
		check(id+" independent floor below walls", door.has_node("ThresholdFloor") and not door.get_node("ThresholdFloor").z_as_relative and door.get_node("ThresholdFloor").z_index==12)
		var sides := 0
		for key in preview.nodes:
			var node = preview.nodes[key]
			if not key.begins_with("wall:") or not node.visible: continue
			if node.display_rect.intersects(door.visual_rect) and absf(node.footprint.end.y-door.gate.rect.end.y)<1:
				sides += 1
				check(id+" overlaps wall in front "+key,door.z_index>node.z_index)
		check(id+" jamb actually overlaps neighbouring walls",sides>=2)
	first.gate.closed = false; first.refresh(true)
	await shot("editor-open")
	if DisplayServer.get_name() != "headless":
		var corrected: Image = root.get_texture().get_image()
		var depth: int = first.z_index
		first.z_index = 12
		await shot("editor-before")
		var old: Image = root.get_texture().get_image()
		var pixels := 0
		for y in corrected.get_height():
			for x in corrected.get_width():
				var d := corrected.get_pixel(x,y)-old.get_pixel(x,y)
				if absf(d.r)+absf(d.g)+absf(d.b)>.15: pixels += 1
		check("raised jamb pixels become visible",pixels>100)
		first.z_index = depth
	first.gate.closed = true; first.refresh(true)
	await shot("editor-closed")
	check("preview changes do not modify map draft",editor.document.data==original)
	editor.queue_free(); await frame()
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://workshop-door-depth-qa.cfg")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game); await frame()
	game.set_process(false); game.fullscreen_ui.set_process(false)
	var player = game.actors[0]
	game.get_node("HUD").hide()
	for id in ["workshop-entry","workshop-entry-east"]:
		var door = game.room_visibility.doorways.by_id(id)
		var gate: Dictionary = game.world.access_by_id(id)
		game.world.set_access_closed(id,false)
		var centre: float = gate.rect.get_center().x
		var inside := Vector2(centre,gate.rect.position.y-140)
		var outside := Vector2(centre,gate.rect.end.y+55)
		check(id+" open full body crossing",game.world.motion_clear(outside,inside,player,false,true) and game.world.motion_clear(inside,outside,player,false,true))
		for offset in [-30,55]:
			player.position = Vector2(centre,gate.rect.end.y+offset)
			game.room_visibility.tick(0,true);game.presentation.tick(0)
			check(id+" actor shares foot depth "+str(offset),player.z_index==Depth.for_y(player.position.y,game.world.bounds.end.y))
			check(id+" floor cannot cover actor "+str(offset),door.get_node("ThresholdFloor").z_index<player.z_index)
			check(id+" correct front back order "+str(offset),player.z_index<door.z_index if offset<0 else player.z_index>door.z_index)
		player.position = Vector2(centre,gate.rect.end.y+180)
		game.world.set_access_closed(id,true)
		check(id+" closed full body blocked",not game.world.motion_clear(outside,inside,player,false,true))
		game.world.set_access_closed(id,false)
	var door = game.room_visibility.doorways.by_id("workshop-entry")
	player.position = Vector2(door.visual_rect.get_center().x,door.gate.rect.end.y+35)
	game.map_camera.center_on(door.visual_rect.get_center()+Vector2(0,-130));game.map_camera.force_update_scroll()
	game.room_visibility.tick(0,true);game.presentation.tick(0)
	await shot("runtime-crossing")
	check("saved map untouched",disk==FileAccess.get_sha256("res://data/rooms/r04.json"))
	var failed: Array = checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)
