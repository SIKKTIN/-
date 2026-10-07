extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await RenderingServer.frame_post_draw
	game.set_process(false)
	game.load_room("r04",["lockpick","chat","backpack"],73)
	game.routine_panel.close()
	game.schedule.set_time_speed(1)
	var shots := {}
	for step in range(2000):
		if paused: game.routine_panel.close()
		game._process(0.05)
		var minute: float=game.schedule.clock_minutes()
		var name := ""
		if game.routines.is_eating(0): name="meal"
		elif minute>780 and minute<810 and game.routines.records.get(0,{}).get("kind","")=="free": name="lunch-free"
		elif minute>=810 and minute<840: name="return-work"
		elif minute>=840: name="afternoon"
		if name.is_empty() or shots.has(name): continue
		shots[name]=minute
		game.map_camera.center_on(game.actors[0].position)
		game.map_camera.following=false
		game.presentation.tick(0)
		game._update_ui()
		await process_frame
		await RenderingServer.frame_post_draw
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/tests/p73-"+name+".png")
		if shots.size()==4: break
	FileAccess.open("res://docs/tests/p73-lunch-visual.json",FileAccess.WRITE).store_string(JSON.stringify({"shots":shots,"captures":game.captures,"wallet":game.inventory.wallet,"routines":game.routines.snapshot()},"\t"))
	print(JSON.stringify(shots))
	quit(0 if shots.size()==4 and game.captures==0 else 1)
