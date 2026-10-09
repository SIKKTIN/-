extends SceneTree

var game
var tutorial
var coach
var ui
var checks := {}
func _initialize(): call_deferred("run")
func check(key: String, ok: bool):
	checks[key] = ok
	print(key+": "+str(ok))
func frame():
	await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
func refresh():
	game.room_visibility.tick(1,true)
	game.presentation.tick(0)
	ui.refresh()
	tutorial._refresh()
	coach.refresh(tutorial.button_prompt())
	tutorial.marker.update_route(0.1)
func choose(kind: String, id := ""):
	var interaction = game.presentation.interaction
	interaction.refresh()
	for target in interaction._mobile_targets:
		if target.kind==kind and (id.is_empty() or target.id==id):
			interaction.mobile_target_key = interaction._target_key(target)
			break
	refresh()
func click(button: Button, touch := false):
	if DisplayServer.get_name()=="headless":
		button.pressed.emit()
		refresh()
		return
	var point := button.get_global_rect().get_center()
	if touch:
		var down := InputEventScreenTouch.new()
		down.position = point
		down.index = 0
		down.pressed = true
		Input.parse_input_event(down)
		await process_frame
		down.pressed = false
		Input.parse_input_event(down)
	else:
		var down := InputEventMouseButton.new()
		down.position = point
		down.global_position = point
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		root.push_input(down)
		await process_frame
		down.pressed = false
		root.push_input(down)
	await frame()
	refresh()
func shot(name: String):
	if DisplayServer.get_name()=="headless": return
	ui.toast.hide()
	ui.fps_badge.hide()
	await frame()
	root.get_texture().get_image().save_png("res://docs/tests/p101-"+name+".png")
func work_fixture():
	tutorial._clock(480)
	tutorial._enter("work_practice")
	game.routines.take_control(0)
	game.orders.stop(0)
	game.actors[0].position = tutorial._target("station")
	game.map_camera.locate_selected()
	refresh()
	choose("work")
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","on")
	OS.set_environment("ESCAPE_FRAME_SETTINGS_PATH","user://p101-qa.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://p101-layout.cfg")
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.reset_round(["chat","lockpick","backpack"],72)
	game.set_process(false)
	ui = game.fullscreen_ui
	ui.set_process(false)
	tutorial = game.tutorial
	tutorial.set_process(false)
	tutorial.marker.set_process(false)
	coach = tutorial.button_guide
	coach.set_process(false)
	work_fixture()
	check("arrival_highlights_real_work_button",coach.visible and coach.target_button==ui.action_button and coach.words.text.contains("点击「工作」"))
	check("ground_route_hands_off_to_ui",not tutorial.marker.enabled and not tutorial.marker.visible)
	check("hint_never_intercepts_input",[coach,coach.card,coach.words,coach.heading,coach.detail].all(func(c):return c.mouse_filter==Control.MOUSE_FILTER_IGNORE))
	check("hint_does_not_pause_world",not paused and not game.world_input_blocked())
	for dims in [Vector2i(1200,720),Vector2i(960,540)]:
		root.size = dims
		root.content_scale_size = dims
		await frame()
		ui.layout()
		game.map_camera.locate_selected()
		refresh()
		check("hint_fits_"+str(dims.x),ui.safe_area().encloses(coach.card.get_global_rect()) and [ui.action_button,ui.bag_button,ui.ability_button,tutorial.panel].all(func(b):return not coach.card.get_global_rect().intersects(b.get_global_rect())) and [coach.words,coach.detail].all(func(label):return label.get_minimum_size().y<=label.size.y+1))
		await shot("work-hint-"+str(dims.x))
	ui.action_button.disabled = true
	coach.refresh(tutorial.button_prompt())
	check("disabled_button_is_never_guided",not coach.visible)
	refresh()
	ui.toggle_menu()
	coach.refresh(tutorial.button_prompt())
	check("pause_hides_button_hint",paused and not coach.visible)
	ui.close_menu()
	refresh()
	check("resume_restores_button_hint",coach.visible)
	ui.toggle_bag()
	coach.refresh(tutorial.button_prompt())
	check("inventory_hides_button_hint",ui.inventory_paper.visible and not coach.visible)
	ui.toggle_bag()
	refresh()
	var count: int = game.routines.work_rounds[0]
	await click(ui.action_button)
	check("mouse_click_passes_through_hint_and_starts_work",tutorial.work_requested() and game.routines.is_working(0) and not coach.visible)
	check("click_is_not_instant_task_completion",tutorial.step_id=="work_practice" and game.routines.work_rounds[0]==count and tutorial.body.text.contains("保持劳动"))
	work_fixture()
	game.guard.position = game.actors[0].position+Vector2(35,0)
	game.guard.escaped = false
	game.guard.show()
	refresh()
	choose("work")
	check("new_switch_button_does_not_overlap_existing_hint",ui.target_button.visible and not coach.card.get_global_rect().intersects(ui.target_button.get_global_rect()))
	var stem := Rect2(coach.tip.min(coach.tip-coach.direction*45),Vector2(0,45)).grow(13)
	check("work_arrow_avoids_switch_button",not stem.intersects(ui.target_button.get_global_rect()))
	await shot("work-hint-with-switch")
	choose("talk","guard:patrol")
	var selected: String = game.presentation.interaction.mobile_target_key
	check("wrong_target_guides_switch_button",coach.visible and coach.target_button==ui.target_button and coach.words.text.contains("切换"))
	await shot("switch-hint")
	coach.refresh(tutorial.button_prompt())
	check("guide_does_not_change_target_automatically",game.presentation.interaction.mobile_target_key==selected)
	for i in range(8):
		if coach.target_button==ui.action_button: break
		await click(ui.target_button)
	check("switch_hands_off_to_work_button",coach.visible and coach.target_button==ui.action_button and ui.action_button.text=="工作")
	await click(ui.action_button,true)
	check("touch_starts_work_without_double_action",tutorial.work_requested() and game.routines.is_working(0) and not coach.visible)
	work_fixture()
	game.actors[0].position += Vector2(250,140)
	refresh()
	check("leaving_range_returns_to_navigation",not coach.visible and tutorial.marker.enabled and tutorial.marker.visible)
	tutorial._clock(720)
	tutorial._enter("meal_practice")
	game.actors[0].position = tutorial._target("meal")
	game.routines.records.erase(0)
	game.routines.take_control(0)
	game.orders.stop(0)
	game.map_camera.locate_selected()
	refresh()
	choose("meal")
	check("meal_button_has_hint",coach.visible and coach.target_button==ui.action_button and coach.words.text.contains("取餐"))
	await click(ui.action_button,true)
	check("meal_click_clears_hint_and_keeps_real_meal_flow",game.routines.records.get(0,{}).get("kind","")=="meal" and not coach.visible and tutorial.step_id=="meal_practice")
	game.orders.stop(0)
	game.routines.take_control(0)
	tutorial._enter("chat_practice")
	game.actors[1].position = game.routines._target(1,"work")
	for offset in [Vector2(70,0),Vector2(-70,0),Vector2(0,70),Vector2(0,-70)]:
		var candidate: Vector2 = game.actors[1].position+offset
		if game.world.can_place_circle(candidate,8,game.actors[0],false) and game.world.line_clear(candidate,game.actors[1].position):
			game.actors[0].position = candidate
			break
	game.map_camera.locate_selected()
	refresh()
	choose("talk","prisoner:1")
	check("chat_button_has_hint",coach.visible and coach.target_button==ui.action_button and coach.words.text.contains("聊天"))
	await click(ui.action_button)
	tutorial.tick(0)
	refresh()
	check("chat_click_guides_real_close_button",game.dialogue.panel.visible and coach.visible and coach.target_button==game.dialogue.end_button)
	check("close_hint_does_not_cover_dialogue",not coach.card.get_global_rect().intersects(game.dialogue.panel.get_global_rect()))
	check("close_hint_does_not_cover_player_responses",not coach.card.get_global_rect().intersects(game.dialogue.responses.get_global_rect()))
	var transform: Transform2D = game.get_global_transform_with_canvas()
	check("close_hint_does_not_cover_people",[game.actors[0],game.actors[1]].all(func(a):return not coach.card.get_global_rect().intersects(Rect2(transform*a.position-Vector2(22,64),Vector2(44,64)))))
	await shot("chat-close-hint")
	await click(game.dialogue.end_button,true)
	check("touch_close_finishes_chat_objective",not game.dialogue.panel.visible)
	tutorial.tick(0)
	refresh()
	check("next_step_has_no_stale_close_hint",tutorial.step_id=="merchant_practice" and not coach.visible)
	tutorial.cancel()
	coach.refresh(tutorial.button_prompt())
	check("cancel_clears_all_button_guides",not coach.visible)
	var failed: Array = checks.keys().filter(func(k):return not checks[k])
	var tag := "headless" if DisplayServer.get_name()=="headless" else "native"
	FileAccess.open("res://docs/tests/p101-button-guide-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"total":checks.size()},"\t"))
	print(JSON.stringify({"failed":failed,"total":checks.size()}))
	quit(0 if failed.is_empty() else 1)
