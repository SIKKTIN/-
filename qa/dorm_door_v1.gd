extends SceneTree
const OUT := "res://docs/art/dorm-door-v1/"
const Geometry = preload("res://scripts/presentation/doorway_geometry.gd")
const Depth = preload("res://scripts/presentation/world_depth.gd")
var checks := {}
func check(label: String, passed: bool) -> void: checks[label] = passed
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func shot(name: String) -> void:
	await frame(); await frame()
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	root.size = Vector2i(1200,800); root.content_scale_size = root.size
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://dorm-door-v1-qa.cfg")
	var disk := FileAccess.get_sha256("res://data/rooms/r04.json")
	var reg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT+"registration.json"))
	check("original generated atlas unchanged",FileAccess.get_sha256("res://art/architecture/dorm_door_v1/components.png")==reg.sha256)
	var catalog = preload("res://scripts/editor/editor_catalog.gd").new()
	for id in ["doorway_dorm_side_open_v1","doorway_dorm_side_closed_v1"]:
		check(id+" registered in editor",catalog.entries.any(func(a): return a.id==id))
	var editor = load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor); await frame(); await frame()
	var draft: Dictionary = editor.document.data.duplicate(true)
	var preview = editor.canvas.architecture_preview
	var ids := ["dorm-0","dorm-1","dorm-2","fixture:campus-dorm-extra-1","fixture:campus-dorm-extra-2"]
	for id in ids:
		var door = preview.doorways.by_id(id)
		check(id+" uses approved artwork",door.gate.get("door_art","")=="doorway_dorm_side_open_v1")
		check(id+" clear old aperture",preview.world.portal_cuts.any(func(c):return c.encloses(door.visual_rect)))
		check(id+" visible broad inward leaves",door.open_patches.size()==3 and door.open_patches[0].destination[3]>=70)
		check(id+" identical fixed frame",door.open_patches[-1].texture==door.closed_patches[-1].texture and door.open_patches[-1].destination==door.closed_patches[-1].destination)
		check(id+" each leaf has independent depth",door.patch_parts.size()==5 and door.patch_parts[0].z_index<door.patch_parts[1].z_index)
		check(id+" no opaque threshold over people",door.get_node("ThresholdFloor").z_index==12)
		var image: Image = door.open_patches[-1].texture.get_image()
		check(id+" frame centre has genuine transparency",image.get_pixel(2,image.get_height()/2).a<0.05)
	var door = preview.doorways.by_id("dorm-1")
	editor.canvas.zoom = 1.7
	editor.canvas.origin = editor.canvas.size/2-(door.visual_rect.get_center()+Vector2(-190,-30))*editor.canvas.zoom
	editor.canvas.queue_redraw()
	await shot("editor-open")
	var ref := {"group":"dorm_doors","index":1}
	check("editor can select new visual doorway",editor.canvas.at(editor.canvas.screen(door.visual_rect.get_center()))==ref)
	var leaf_point: Vector2 = door.position+Vector2(0,door.open_patches[0].destination[3]/2+6).rotated(door.rotation)
	check("editor can select inward leaf handle",editor.canvas.at(editor.canvas.screen(leaf_point))==ref)
	check("preview does not rewrite saved draft",editor.document.data==draft)
	var transform = preload("res://scripts/editor/map_transform.gd")
	var captured: Dictionary = transform.capture(editor.document,[ref],false)
	editor.document.begin(); transform.apply(editor.document,captured,1); editor.document.commit()
	check("side door rotation retains correct canonical direction",int(editor.document.value(ref).rotation_quarters)==2)
	editor.document.undo()
	check("door rotation undo restores draft",editor.document.data==draft)
	editor.queue_free(); await frame()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game); await frame(); await frame()
	game.set_process(false); game.fullscreen_ui.set_process(false)
	game.world.admission_filter = Callable()
	game.get_node("HUD").hide()
	var player = game.actors[0]
	for index in game.world.dorm_doors.size():
		var gate: Dictionary = game.world.dorm_doors[index]
		var node = game.room_visibility.doorways.by_id("dorm-%d" % index)
		check("runtime resolves dorm "+str(index),node.gate.door_art=="doorway_dorm_side_open_v1")
		gate.closed = false; game.world._changed(true); game.room_visibility.doorways.tick(true)
		var y: float = node.visual_rect.end.y-54
		var inside := Vector2(gate.rect.position.x-110,y)
		var outside := Vector2(gate.rect.end.x+110,y)
		player.position = outside
		check("open clear inward and outward "+str(index),game.world.motion_clear(inside,outside,player,false,true) and game.world.motion_clear(outside,inside,player,false,true))
		check("open doorway path reachable "+str(index),not game.world.find_path(inside,outside,player,false,true).is_empty())
		check("open corridor beside door clear "+str(index),game.world.motion_clear(Vector2(gate.rect.end.x+65,y-25),Vector2(gate.rect.end.x+65,y+25),player,false,true))
		if gate.get("kind","") != "open":
			gate.closed = true; game.world._changed(true); game.room_visibility.doorways.tick(true)
			check("closed actually blocks "+str(index),not game.world.motion_clear(inside,outside,player,false,true))
			check("closed state drawn "+str(index),node.closed and node.patch_parts.filter(func(p): return p.visible).size()==2)
			var crossing := Vector2(node.visual_rect.get_center().x,y)
			check("inspection can still use key "+str(index),game.world.door_passage.solids(false).any(func(r):return r.has_point(crossing)) and not game.world.door_passage.solids(true).any(func(r):return r.has_point(crossing)))
		gate.closed = false; game.world._changed(true)
	# Night schedule remains the owner of logical locks; tutorial open gate is preserved.
	player.position = Vector2(2600,3000)
	game.world.update_dorm_doors(true,[])
	check("night locks assigned dorm doors",game.world.dorm_doors.slice(1).all(func(g):return g.closed))
	check("interactive first dorm now obeys night lock",game.world.dorm_doors[0].closed)
	game.world.update_dorm_doors(false,[])
	check("day opens dorm doors",game.world.dorm_doors.all(func(g):return not g.closed))
	var occupied = game.room_visibility.doorways.by_id("dorm-1")
	player.position = Vector2(occupied.visual_rect.get_center().x,occupied.visual_rect.end.y-54)
	game.world.update_dorm_doors(true,[])
	check("night closure waits for body in doorway",not game.world.dorm_doors[1].closed)
	game.world.update_dorm_doors(false,[])
	var gate: Dictionary = game.world.dorm_doors[1]
	door = game.room_visibility.doorways.by_id("dorm-1")
	player.position = Vector2(gate.rect.position.x-85,door.visual_rect.end.y-54)
	game.map_camera.center_on(door.visual_rect.get_center()+Vector2(-190,-30)); game.map_camera.force_update_scroll()
	game.room_visibility.tick(0,true); game.presentation.tick(0)
	game.room_visibility.doorways.tick(true)
	check("upper leaf behind foreground actor",door.patch_parts[0].z_index<Depth.for_y(player.position.y,game.world.bounds.end.y))
	check("lower leaf above actor behind it",door.patch_parts[1].z_index>Depth.for_y(player.position.y,game.world.bounds.end.y))
	await shot("runtime-open")
	gate.closed = true; game.world._changed(true); game.room_visibility.doorways.tick(true)
	await shot("runtime-closed")
	check("saved map remains untouched",disk==FileAccess.get_sha256("res://data/rooms/r04.json"))
	var failed: Array = checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)
