extends SceneTree
const OUT := "res://docs/tests/clinic-door-occlusion/"
const Sliding = preload("res://scripts/presentation/sliding_door_geometry.gd")
var game
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
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://clinic-occlusion-qa.cfg")
	root.size = Vector2i(1200,720); root.content_scale_size = root.size
	var saved := FileAccess.get_sha256("res://data/rooms/r04.json")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game); await frame()
	game.set_process(false); game.fullscreen_ui.set_process(false)
	game.get_node("HUD").hide()
	var door = game.room_visibility.doorways.by_id("clinic-entry")
	var rect: Rect2 = door.visual_rect
	game.actors[0].position = Vector2(rect.get_center().x,rect.end.y+105)
	game.map_camera.center_on(rect.get_center()+Vector2(0,40)); game.map_camera.force_update_scroll()
	game.room_visibility.tick(0,true); game.presentation.tick(0)
	var edges: Array = game.room_visibility.wall_edges.edges
	var lowered: Array = edges.filter(func(e): return not e.z_as_relative)
	check("only doorway-adjacent wall edges use normal depth",not lowered.is_empty() and lowered.size()<edges.size())
	var first_builds := {}
	for edge in edges: first_builds[edge.get_instance_id()] = edge.draw_builds
	for fraction in [0.0,0.25,0.5,0.75,1.0]:
		door.gate.slide_fraction = fraction; door.refresh(true)
		for index in 2:
			var leaf: Rect2 = door.transform*Sliding.leaves(door.gate,fraction)[index]
			for edge in edges:
				if edge.clips.any(func(c):return c.intersects(leaf)):
					check("leaf %s at %s covers intersecting trim %s" % [index,fraction,edge.get_instance_id()],not edge.z_as_relative and edge.z_index<door.z_index)
		await shot("open" if fraction==0 else "closed" if fraction==1 else "moving-"+str(fraction))
	check("door animation retains static wall painters",edges.all(func(e):return e.draw_builds==first_builds[e.get_instance_id()]))
	# Reproduce the previous ordering for an actual pixel comparison.
	door.gate.slide_fraction = 0.0; door.refresh(true)
	await shot("after")
	var corrected: Image
	if DisplayServer.get_name() != "headless": corrected = root.get_texture().get_image()
	for edge in lowered: edge.z_as_relative = true; edge.z_index = 0
	await shot("before")
	if DisplayServer.get_name() != "headless":
		var previous: Image = root.get_texture().get_image()
		var changed := 0
		for leaf in Sliding.leaves(door.gate,0.0):
			var area: Rect2 = door.get_global_transform_with_canvas()*leaf
			for y in range(maxi(0,floori(area.position.y)),mini(corrected.get_height(),ceili(area.end.y))):
				for x in range(maxi(0,floori(area.position.x)),mini(corrected.get_width(),ceili(area.end.x))):
					var delta := corrected.get_pixel(x,y)-previous.get_pixel(x,y)
					if absf(delta.r)+absf(delta.g)+absf(delta.b)>.12: changed+=1
		check("native pixels restore both door tops",changed>200)
	for edge in lowered: edge.z_as_relative=false; edge.z_index=door.z_index-1
	var cover = game.room_visibility.covers.filter(func(c): return c.room.id=="clinic")[0]
	check("restored facade trim still above clinic roof",lowered.all(func(e):return e.z_index>cover.z_index))
	game.actors[0].position = Vector2(rect.get_center().x,rect.end.y-20)
	game.room_visibility.tick(0,true); game.presentation.tick(0)
	await shot("crossing")
	check("threshold stays below actor",door.get_node("ThresholdFloor").z_index<game.actors[0].z_index)
	check("saved user map unchanged",saved==FileAccess.get_sha256("res://data/rooms/r04.json"))
	var failed: Array = checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)