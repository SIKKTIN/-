extends "res://qa/p123_looting.gd"

func pointer_click(point: Vector2, touch := false):
	if touch:
		var down := InputEventScreenTouch.new()
		down.index = 4
		down.position = point
		down.pressed = true
		root.push_input(down)
		await frame()
		down.pressed = false
		root.push_input(down)
	else:
		if DisplayServer.get_name() != "headless": root.warp_mouse(point)
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		root.push_input(motion)
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.position = point
		down.global_position = point
		down.pressed = true
		root.push_input(down)
		await frame()
		down.pressed = false
		root.push_input(down)
	await frame()

func select_container(id: String):
	check("stand_"+id,stand_beside(id))
	game.presentation.tick(0)
	var prompt = game.presentation.interaction
	prompt.mobile_target_key = "0:loot:"+id
	game.map_camera.center_on(game.actors[0].position+Vector2(90,0))
	game.map_camera.force_update_scroll()
	prompt.refresh()
	game._update_ui()
	await frame()

func capture(label: String):
	if DisplayServer.get_name() == "headless": return
	game.presentation.tick(0)
	game._update_ui()
	await frame()
	await frame()
	check(label+"_saved",root.get_texture().get_image().save_png("res://docs/dev/p138/"+label+".png")==OK)

func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p138-interaction.cfg")
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.fullscreen_ui.fps_badge.hide()
	game.reset_round(["chat","backpack","strong"],138)
	game.world.admission_filter = Callable()
	game.schedule.set_time_speed(0)
	var prompt = game.presentation.interaction
	var ui = game.fullscreen_ui
	var cabinet := "detail44-dorm-personal-0"
	await select_container(cabinet)
	check("hint_visible_on_mobile_hud",prompt.hint.visible and game.mobile_controls != null)
	var authored_title: String=str(game.looting.containers[cabinet].fixture.loot_name).replace("私人物品柜","私人柜")
	check("private_cabinet_title_and_action",prompt.hint.title==authored_title and prompt.hint.action=="翻找")
	check("hint_and_main_button_share_target",prompt.hint.target_key==prompt.mobile_target_key and ui.action_button.text==prompt.hint.action)
	check("only_one_world_hint",not prompt.button.visible and prompt.extras.values().all(func(b):return not b.visible))
	check("cabinet_uses_painted_outline",prompt.outline.visible and prompt.outline.texture!=null and prompt.outline.material.shader!=null)
	var source: Dictionary = prompt._target_visual(prompt._mobile_target())
	var expected: Rect2 = game.get_global_transform_with_canvas()*source.rect
	check("outline_matches_actual_prop_bounds",prompt.outline.position.is_equal_approx(expected.position) and (prompt.outline.scale*prompt.outline.texture.get_size()).is_equal_approx(expected.size))
	for size in [Vector2i(1200,720),Vector2i(960,540),Vector2i(1440,900)]:
		root.size = size
		root.content_scale_size = size
		await frame()
		ui.layout()
		game.map_camera.center_on(game.actors[0].position+Vector2(90,0))
		game.map_camera.force_update_scroll()
		prompt.refresh()
		game._update_ui()
		await frame()
		var bounds: Rect2 = prompt.hint.get_global_rect()
		check("hint_fits_"+str(size.x),Rect2(Vector2.ZERO,Vector2(size)).encloses(bounds))
		check("hint_avoids_clock_"+str(size.x),not bounds.intersects(ui.clock.get_global_rect()))
		var art = game.actors[0].get_node("ArtVisual")
		var body: Rect2 = game.get_global_transform_with_canvas()*Rect2(game.actors[0].position+art.body_bounds().position,art.body_bounds().size)
		check("hint_avoids_player_"+str(size.x),not bounds.intersects(body))
		await capture("cabinet-"+str(size.x))
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	ui.layout()
	await select_container(cabinet)
	var art = game.actors[0].get_node("ArtVisual")
	var target_rect: Rect2 = prompt._target_visual(prompt._mobile_target()).rect
	game.map_camera.center_on(target_rect.get_center()+Vector2(200,215))
	game.map_camera.force_update_scroll()
	prompt.refresh()
	check("near_top_edge_hint_avoids_hud",not prompt.hint.get_global_rect().intersects(ui.clock.get_global_rect()))
	await capture("cabinet-edge")
	await select_container(cabinet)
	var npc = game.actors[1]
	var original_npc_position: Vector2 = npc.position
	npc.position = game.actors[0].position+Vector2(45,20)
	prompt.refresh()
	var talk: Dictionary = {}
	for target in prompt._mobile_targets:
		if target.kind == "talk" and str(target.id)=="prisoner:1": talk = target;break
	if not talk.is_empty():
		prompt.mobile_target_key = prompt._target_key(talk)
		prompt.refresh()
		game._update_ui()
	check("npc_hint_shows_name_and_chat",not talk.is_empty() and prompt.hint.title==str(talk.get("name","")) and prompt.hint.action=="聊天")
	npc.position = original_npc_position
	await select_container(cabinet)
	await pointer_click(prompt.hint.get_global_rect().get_center())
	check("mouse_click_opens_selected_container",game.looting.current_id==cabinet)
	check("search_modal_hides_hint_and_outline",not prompt.hint.visible and not prompt.outline.visible)
	game.looting.close()
	await select_container(cabinet)
	await pointer_click(prompt.hint.get_global_rect().get_center(),true)
	check("native_touch_opens_selected_container",game.looting.current_id==cabinet)
	game.looting.close()
	await select_container(cabinet)
	var press := InputEventKey.new()
	press.keycode = KEY_E
	press.pressed = true
	root.push_input(press)
	await frame()
	press.pressed = false
	root.push_input(press)
	check("e_key_opens_same_container",game.looting.current_id==cabinet)
	game.looting.close()
	await select_container(cabinet)
	var item: String = game.inventory.add_ground("bread",game.actors[0].position+Vector2(5,0))
	prompt.refresh()
	check("multiple_targets_available",prompt.mobile_target_count()>1)
	var previous: String = prompt.mobile_target_key
	prompt.cycle_mobile_target()
	check("switch_updates_hint_and_main_button",prompt.mobile_target_key!=previous and prompt.hint.target_key==prompt.mobile_target_key and ui.action_button.text==prompt.mobile_label())
	prompt.mobile_target_key = "0:pickup:"+item
	prompt.refresh()
	game._update_ui()
	check("ground_item_has_name_and_action",prompt.hint.title=="馒头" and prompt.hint.action=="拾取")
	await pointer_click(prompt.hint.get_global_rect().get_center(),true)
	check("touch_hint_picks_up_ground_item",game.inventory.owns(0,item))
	await select_container(cabinet)
	var old_position: Vector2 = game.actors[0].position
	var key: String = prompt.hint.target_key
	var hint_point: Vector2 = prompt.hint.get_global_rect().get_center()
	var touch := InputEventScreenTouch.new()
	touch.index = 7
	touch.position = hint_point
	touch.pressed = true
	root.push_input(touch)
	game.actors[0].position += Vector2(400,0)
	prompt.refresh()
	touch.pressed = false
	root.push_input(touch)
	await frame()
	check("held_touch_does_not_activate_changed_target",not game.looting.is_open())
	check("old_target_leaves_range",prompt.mobile_target_key!=key)
	game.actors[0].position = old_position
	await select_container(cabinet)
	ui.toggle_bag()
	prompt.refresh()
	check("bag_hides_hint_and_outline",not prompt.hint.visible and not prompt.outline.visible)
	ui.toggle_bag()
	await select_container(cabinet)
	ui.toggle_menu()
	prompt.refresh()
	check("pause_hides_hint_and_outline",not prompt.hint.visible and not prompt.outline.visible)
	ui.close_menu()
	await select_container(cabinet)
	game.map_camera.center_on(game.actors[0].position+Vector2(1000,0))
	game.map_camera.force_update_scroll()
	prompt.refresh()
	check("offscreen_target_does_not_pin_prompt_to_edge",not prompt.hint.visible and not prompt.outline.visible)
	game.reset_round(["chat","backpack","strong"],139)
	await select_container(cabinet)
	check("round_reset_rebuilds_outline_source",prompt.hint.visible and prompt.outline.visible and is_instance_valid(prompt.fixture_volumes.get(cabinet)))
	var failed: Array = checks.keys().filter(func(k):return not checks[k])
	var path := "res://docs/dev/p138/interaction-"+("headless" if DisplayServer.get_name()=="headless" else "native")+".json"
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		push_error("Cannot write interaction report: %s" % FileAccess.get_open_error())
		quit(1)
		return
	file.store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	file.close()
	print(JSON.stringify({"failed":failed,"checks":checks.size()}))
	quit(0 if failed.is_empty() else 1)
