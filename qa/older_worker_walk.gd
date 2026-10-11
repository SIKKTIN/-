extends SceneTree
const Library = preload("res://scripts/presentation/character_library.gd")
const OUT := "res://docs/dev/older-worker-walk/"
var checks: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func check(label: String, value: bool) -> void:
	checks[label] = value
	if not value: push_error("FAIL: " + label)
func run() -> void:
	var asset: Dictionary = Library.all().older_worker
	check("approved idle PNG preserved", FileAccess.get_sha256(asset.texture) == asset.sha256)
	check("replacement walk source used", asset.walk_animation.texture != asset.texture and FileAccess.get_sha256(asset.walk_animation.texture) == asset.walk_animation.sha256)
	check("eight walk poses at measured cadence", asset.walk_animation.frames.size() == 8 and asset.walk_animation.fps == 8)
	var full_image := Image.load_from_file(asset.walk_animation.texture)
	var head_heights: Array[float] = []
	for frame in asset.walk_animation.frames:
		var body_height: int = frame.region[3]-6
		var start: int = 3+roundi(body_height*0.08)
		var end: int = 3+roundi(body_height*0.30)
		var head_band := full_image.get_region(Rect2i(frame.region[0],frame.region[1]+start,frame.region[2],end-start))
		for y in range(head_band.get_height()):
			for x in range(head_band.get_width()):
				if head_band.get_pixel(x,y).a < 24.0/255.0: head_band.set_pixel(x,y,Color.TRANSPARENT)
		var used := head_band.get_used_rect()
		check(frame.id + " head registered to stable axis", absf(float(used.position.x)+float(used.size.x)/2.0-float(frame.anchor[0])) <= 3)
		head_heights.append(float(frame.region[3])*float(asset.world_height)/float(asset.walk_animation.scale_height))
	check("walk height variation limited", head_heights.max()-head_heights.min() <= 5)
	var motion: Dictionary = Library.motion("older_worker")
	for frame in range(8):
		var region: Array = asset.walk_animation.frames[frame].region
		check("frame %d correct new crop" % frame, motion.walk[frame].get_size() == Vector2(region[2],region[3]))
	var viewer = load("res://scenes/editor/character_previewer.tscn").instantiate()
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,800)
	root.add_child(viewer)
	await process_frame
	viewer.set_process(false)
	viewer.select_character("older_worker")
	viewer.seek_frame(0)
	check("preview resolves revised path", viewer.source_label.text == asset.walk_animation.texture)
	check("preview preserves idle texture", viewer.motion.idle == Library.idle("older_worker"))
	if DisplayServer.get_name() != "headless":
		Input.warp_mouse(Vector2(5,5))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + "native-preview.png")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r04", ["lockpick","chat","backpack"],52)
	game.schedule.set_time_speed(0)
	paused = false
	var actor = game.actors[1]
	actor.position = game.actors[0].position + Vector2(50,0)
	game.room_visibility.tick(0,true)
	game.room_config.character_appearances = {"actor:1":"older_worker"}
	var visual = game.presentation.visuals.filter(func(v): return v.actor == actor)[0]
	visual.refresh_appearance()
	actor.moved_this_frame = true
	var visited: Dictionary = {}
	for i in range(16):
		visual.tick_visual(1.0/8.0)
		visited[visual.walk_frame_index] = true
		check("runtime %d shares new pose and stable feet" % i, visual.texture == motion.walk[visual.walk_frame_index] and absf(visual.destination.end.y) < 1)
	check("runtime loops through all eight poses", visited.size() == 8 and not visited.has(-1))
	actor.facing = Vector2.LEFT
	visual.tick_visual(0)
	check("runtime mirrors about foot anchor", visual.flip_h and absf(visual.body_bounds().end.y) < 1)
	actor.moved_this_frame = false
	visual.tick_visual(0)
	check("runtime stops on preserved idle", visual.frame_name == "idle" and visual.texture == Library.idle("older_worker"))
	var failed: int = checks.values().count(false)
	var report := {"passed":checks.size()-failed,"failed":failed,"checks":checks}
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("Older worker walk: ",report.passed," passed, ",failed," failed")
	quit(1 if failed else 0)
