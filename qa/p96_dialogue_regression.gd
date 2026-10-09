extends SceneTree

var game
var checks := {}
func _initialize(): call_deferred("run")
func check(key: String, value: bool):
	checks[key] = value
	print(key+": "+str(value))
func click(point: Vector2):
	var down := InputEventMouseButton.new()
	down.position = point
	down.global_position = point
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	root.push_input(down)
	await process_frame
	var up := down.duplicate()
	up.pressed = false
	root.push_input(up)
	await process_frame
func touch(point: Vector2):
	var down := InputEventScreenTouch.new()
	down.position = point
	down.index = 0
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := down.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame
func shot(label: String):
	game.presentation.tick(0)
	game.fullscreen_ui.fps_badge.hide()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/tests/p96-"+label+".png")
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","on")
	OS.set_environment("ESCAPE_FRAME_SETTINGS_PATH","user://p96-input.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://p96-input-layout.cfg")
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.tutorial.set_process(false)
	for i in range(1000):
		if game.tutorial.dialogue_ready: break
		game._process(0.05)
	var tutorial = game.tutorial
	var ui = game.fullscreen_ui
	ui.refresh()
	check("actual_presenter_ready",tutorial.dialogue_ready and tutorial.speech.visible and tutorial._conversation_ready())
	check("dialogue_has_no_bottom_board",not tutorial.panel.visible and not tutorial.primary.visible)
	check("clock_displays_chapter",ui.clock.calendar_text().ends_with("1/6"))
	check("skip_is_only_in_menu",tutorial.skip_button.get_parent()==ui.menu and not tutorial.skip_button.is_visible_in_tree() and not ui.replay_tutorial.visible)
	tutorial.text_revealed = 0
	tutorial._refresh()
	await click(tutorial.speech.bubble.get_global_rect().get_center())
	check("mouse_first_click_reveals_only",tutorial.line_index==0 and tutorial.text_revealed==tutorial.current_line().length())
	await click(tutorial.speech.bubble.get_global_rect().get_center())
	check("mouse_second_click_advances_once",tutorial.line_index==1 and tutorial.text_revealed==0)
	tutorial.text_revealed = 999
	tutorial._refresh()
	await touch(tutorial.speech.bubble.get_global_rect().get_center())
	check("touch_advances_exactly_one_page",tutorial.line_index==2 and tutorial.text_revealed==0)
	var foot: Vector2 = game.actors[0].position
	var line: int = tutorial.line_index
	await click(Vector2(900,500))
	check("backdrop_click_does_not_advance_or_move",tutorial.line_index==line and game.actors[0].position==foot and not game.orders.active.has(0))
	tutorial.line_index = 0
	tutorial.text_revealed = 999
	tutorial._refresh()
	for size in [Vector2i(1200,720),Vector2i(960,540)]:
		root.size = size
		root.content_scale_size = size
		await process_frame
		ui.layout()
		for i in range(70): tutorial._conversation_focus(0.05)
		tutorial._refresh()
		ui.refresh()
		await shot("dialogue-"+str(size.x))
		ui.toggle_menu()
		check("pause_hides_speech_"+str(size.x),not tutorial.speech.visible and not tutorial.panel.visible and tutorial.skip_button.is_visible_in_tree() and paused)
		ui.close_menu()
		check("resume_restores_speech_"+str(size.x),tutorial.speech.visible and not paused)
	tutorial._enter("follow_work")
	ui.refresh()
	var tasks_fit := true
	for size in [Vector2i(1200,720),Vector2i(960,540)]:
		root.size = size
		root.content_scale_size = size
		await process_frame
		ui.layout()
		for id in tutorial.steps:
			if tutorial.steps[id].kind!="objective": continue
			tutorial.step_id = id
			tutorial._refresh()
			var text_width: float = game.presentation.font.get_string_size(tutorial.body.text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
			tasks_fit = tasks_fit and text_width<=tutorial.body.size.x and tutorial.panel.size.y==48 and tutorial.primary.get_rect().end.y<=48
			tasks_fit = tasks_fit and not tutorial.panel.get_rect().intersects(game.mobile_controls.pad.get_rect()) and not tutorial.panel.get_rect().intersects(ui.bag_button.get_rect())
			tasks_fit = tasks_fit and not tutorial.speech.visible
		tutorial.step_id = "follow_work"
		tutorial._refresh()
		ui.refresh()
		await shot("task-"+str(size.x))
	check("all_action_tasks_fit_and_do_not_cover_controls",tasks_fit)
	game.show_status("Test notification",4)
	ui.refresh()
	check("notification_does_not_cover_task",not ui.toast.get_rect().intersects(tutorial.panel.get_rect()))
	var before: Vector2 = game.actors[0].position
	await click(tutorial.primary.get_global_rect().get_center())
	check("locate_keeps_actor_and_step",game.actors[0].position==before and tutorial.step_id=="follow_work")
	ui.toggle_menu()
	await shot("pause-skip")
	await click(tutorial.skip_button.get_global_rect().get_center())
	check("menu_skip_unpauses_and_starts_transition",not ui.menu.visible and not paused and tutorial.transition)
	for i in range(25): tutorial._process(0.05)
	ui.refresh()
	check("skip_enters_clean_day_two",not tutorial.active and game.schedule.day_number()==2 and game.schedule.remaining()==900 and not tutorial.speech.visible and not tutorial.panel.visible)
	check("formal_menu_restores_replay",ui.replay_tutorial.visible and not tutorial.skip_button.visible and not ui.clock.calendar_text().contains("/6"))
	var failed: Array = checks.keys().filter(func(k):return not checks[k])
	FileAccess.open("res://docs/tests/p96-dialogue-input.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks,"failed":failed}))
	quit(0 if failed.is_empty() else 1)
