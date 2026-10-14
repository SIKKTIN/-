extends SceneTree
const OUT = "res://docs/art/workshop-one-restoration/door-v2/"
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
	var catalog = preload("res://scripts/editor/editor_catalog.gd").new()
	for id in ["doorway_workshop_open_v2","doorway_workshop_closed_v2"]:
		check("new door in palette "+id,catalog.entries.any(func(v):return v.id==id))
	check("old door and components hidden in palette",not catalog.entries.any(func(v):return str(v.id).begins_with("workshop_door_v2_") or v.id in ["doorway_workshop_open_v1","doorway_workshop_closed_v1"]))
	var registration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT+"asset-registration.json"))
	check("original PNG hash preserved",FileAccess.get_sha256("res://art/architecture/workshop_door_v2/components.png")==registration.sha256)
	editor.canvas.zoom = 1.5
	editor.canvas.origin = editor.canvas.size/2-(first.visual_rect.get_center()+Vector2(0,-55))*editor.canvas.zoom
	editor.canvas.queue_redraw()
	for id in ["workshop-entry","workshop-entry-east"]:
		var door = preview.doorways.by_id(id)
		check(id+" art uses raised sorting", door.gate.get("raised_door",false))
		check(id+" foreground contact sorts above door",not door.z_as_relative and door.z_index<Depth.for_y(door.gate.rect.end.y+3.01,preview.world.bounds.end.y))
		check(id+" independent floor below walls", door.has_node("ThresholdFloor") and not door.get_node("ThresholdFloor").z_as_relative and door.get_node("ThresholdFloor").z_index==12)
		check(id+" exactly two states",door.gate.states==["closed","fully-open"])
		check(id+" legacy map resolves new artwork",door.gate.door_art=="doorway_workshop_open_v2" and door.gate.door_art_closed=="doorway_workshop_closed_v2")
		check(id+" open and closed reuse exact frame",door.open_patches[-1].texture==door.closed_patches[-1].texture and door.open_patches[-1].source==door.closed_patches[-1].source and door.open_patches[-1].destination==door.closed_patches[-1].destination)
		check(id+" separate leaf assembly",door.open_patches.size()==3 and door.closed_patches.size()==2)
		check(id+" old wall facade fully cut",preview.world.portal_cuts.has(door.visual_rect))
		var frame_image: Image = door.open_patches[-1].texture.get_image()
		check(id+" actual transparent aperture",frame_image.get_pixel(frame_image.get_width()/2,frame_image.get_height()/2).a==0)
		var sides := 0
		for key in preview.nodes:
			var node = preview.nodes[key]
			if not key.begins_with("wall:") or not node.visible: continue
			if node.display_rect.intersects(door.visual_rect) and absf(node.footprint.end.y-door.gate.rect.end.y)<1:
				sides += 1
				var pieces: Array = preload("res://scripts/presentation/roof_geometry.gd").subtract_all(node.display_rect,preview.world.portal_cuts)
				check(id+" neighbouring wall cannot cover jamb "+key,pieces.all(func(p):return not p.intersects(door.visual_rect)))
		check(id+" jamb actually overlaps neighbouring walls",sides>=2)
	first.gate.closed = false; first.refresh(true)
	await shot("editor-open")
	var opened: Image = root.get_texture().get_image() if DisplayServer.get_name() != "headless" else null
	first.gate.closed = true; first.refresh(true)
	await shot("editor-closed")
	if DisplayServer.get_name() != "headless":
		var closed: Image = root.get_texture().get_image()
		var differences := 0
		var samples := 0
		var transform: Transform2D = first.get_global_transform_with_canvas()
		for area in [Rect2(0,0,180,18),Rect2(0,18,20,102),Rect2(160,18,20,102)]:
			for y in range(int(area.position.y),int(area.end.y)):
				for x in range(int(area.position.x),int(area.end.x)):
					var p: Vector2i = transform*Vector2(x,y)
					if p.x<0 or p.y<0 or p.x>=closed.get_width() or p.y>=closed.get_height():continue
					var d: Color = opened.get_pixelv(p)-closed.get_pixelv(p)
					if absf(d.r)+absf(d.g)+absf(d.b)>.03: differences += 1
					samples += 1
		check("fixed frame rendered identically across states",samples>1000 and differences==0)
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
		check(id+" linked gates close together",game.world.access_by_id("workshop-entry").closed and game.world.access_by_id("workshop-entry-east").closed)
		check(id+" closed full body blocked",not game.world.motion_clear(outside,inside,player,false,true))
		game.world.set_access_closed(id,false)
	var door = game.room_visibility.doorways.by_id("workshop-entry")
	player.position = Vector2(door.visual_rect.get_center().x,door.gate.rect.end.y+35)
	game.map_camera.center_on(door.visual_rect.get_center()+Vector2(0,-130));game.map_camera.force_update_scroll()
	game.room_visibility.tick(0,true);game.presentation.tick(0)
	await shot("runtime-crossing")
	player.position = Vector2(door.visual_rect.get_center().x,door.gate.rect.end.y+180)
	game.world.set_access_closed("workshop-entry",true)
	game.room_visibility.tick(0,true);game.presentation.tick(0)
	await shot("runtime-closed")
	game.world.set_access_closed("workshop-entry",false)
	player.position = Vector2(door.visual_rect.get_center().x,door.gate.rect.position.y-90)
	game.room_visibility.tick(0,true);game.presentation.tick(0)
	await shot("runtime-inside")
	check("saved map untouched",disk==FileAccess.get_sha256("res://data/rooms/r04.json"))
	var failed: Array = checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)
