extends SceneTree
var game
var checks := {}
var sizes: Array = []
func _initialize(): call_deferred("run")
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","on")
	OS.set_environment("ESCAPE_FRAME_SETTINGS_PATH","user://p91-layout.cfg")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.tutorial.set_process(false)
	for size in [Vector2i(1200,720),Vector2i(960,540)]:
		root.size = size
		root.content_scale_size = size
		await process_frame
		for spec in game.tutorial.steps.values():
			if spec.kind != "brief": continue
			game.tutorial._enter(spec.id)
			game.tutorial.body.visible_characters = -1
			game.fullscreen_ui.layout()
			game.tutorial.layout()
			await process_frame
			var tutorial = game.tutorial
			var bounds: Rect2 = tutorial.panel.get_rect()
			var fits: bool = bounds.position.x>=0 and bounds.position.y>=0 and bounds.end.x<=size.x and bounds.end.y<=size.y and tutorial.body.get_rect().end.y<=tutorial.note.position.y and tutorial.primary.get_rect().end.y<=bounds.size.y
			var name: String = "%s_%d" % [spec.id,size.x]
			checks[name] = fits
			sizes.append({"step":name,"fits":fits,"body_bottom":tutorial.body.get_rect().end.y,"note_top":tutorial.note.position.y,"button_bottom":tutorial.primary.get_rect().end.y,"panel_height":bounds.size.y})
			if spec.id in ["welcome","tools_brief","warning_brief"]:
				game.room_visibility.tick(0.25)
				game.presentation.tick(0)
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://docs/tests/p91-layout-"+name+".png")
	var failed = checks.keys().filter(func(k):return not checks[k])
	FileAccess.open("res://docs/tests/p91-layout.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"sizes":sizes},"\t"))
	print(JSON.stringify({"failed":failed,"sizes":sizes}))
	quit(0 if failed.is_empty() else 1)
