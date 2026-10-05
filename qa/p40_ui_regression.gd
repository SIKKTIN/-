extends SceneTree

var game
var checks := {}
var prefix := "p40-regression"
var frames := 0
var focused := 0

func _initialize() -> void:
	call_deferred("run")

func frame() -> void:
	root.grab_focus()
	await process_frame
	await RenderingServer.frame_post_draw
	frames += 1
	focused += int(root.has_focus())

func tap(point: Vector2) -> void:
	await frame() # Settle focus/layout before sending a native press.
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = root.get_final_transform()*point
	touch.pressed = true
	Input.parse_input_event(touch)
	await frame()
	touch = touch.duplicate()
	touch.pressed = false
	Input.parse_input_event(touch)
	await frame()

func shot(suffix: String) -> void:
	await frame()
	root.get_texture().get_image().save_png("res://docs/tests/"+prefix+"-"+suffix+".png")

func press(button: Button) -> void:
	await tap(button.get_global_rect().get_center())

func run() -> void:
	prefix += "-"+OS.get_cmdline_user_args()[0]
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.reset_round(["chat","lockpick","backpack"],33)
	game.routine_panel.close() # Dismiss new daily allocation before the existing fixture.
	game.schedule.set_time_speed(1)
	game.developer_settings.preference_path = "user://p33-ui-test.cfg"
	await frame()
	var ui = game.fullscreen_ui
	checks.full_viewport = game.map_camera.view_rect() == Rect2(Vector2.ZERO,game.get_viewport_rect().size)
	checks.no_paper_frame = game.get_node_or_null("HUD/PaperBackdrop") == null
	checks.art_theme = ui.theme.resource_path == "res://art/ui/fullscreen/theme.tres"
	var safe: Rect2 = ui.safe_area()
	checks.widgets_safe = (game.cards+[ui.clock,ui.goal,ui.wallet,ui.menu_button,game.mini_map,ui.inventory_paper]).all(func(c): return safe.grow(1).encloses(c.get_global_rect()))
	checks.one_slot = game.inventory_panel.slots.filter(func(c): return c.visible).size() == 1
	var body: Rect2 = game.actors[0].get_node("ArtVisual").body_bounds()
	body.position += game.actors[0].position-game.map_camera.position
	checks.initial_actor_clear = not body.intersects(ui.clock.get_global_rect())
	await press(game.cards[2])
	checks.touch_select = game.selected_actor_id == 2
	checks.three_slots = game.inventory_panel.slots.filter(func(c): return c.visible).size() == 3
	checks.three_slot_safe = safe.grow(1).encloses(ui.inventory_paper.get_global_rect()) and not ui.inventory_paper.get_global_rect().intersects(game.cards[2].get_global_rect())
	await shot("three-slots")
	await press(game.cards[0])
	checks.identity_stable = ui.portraits[0].resource_path.ends_with("portrait_1.tres") and game.actors[0].skill_id == "chat"
	# Native touch to open ground at screen center, away from HUD.
	game.actors[0].position = Vector2(540,490)
	game.map_camera.locate_selected()
	game.presentation.tick(0)
	var point: Vector2 = game.get_global_transform_with_canvas()*Vector2(555,620)
	await tap(point)
	checks.touch_move = game.orders.active.has(0)
	for index in range(80):
		game._process(1.0/120)
		await frame()
	checks.camera_follow = game.map_camera.following and game.actors[0].position.y > 610
	await press(game.mini_map.stop_button)
	checks.touch_stop = not game.orders.active.has(0)
	await press(ui.map_collapse)
	checks.collapse_map = not game.mini_map.visible and ui.map_toggle.visible
	await press(ui.map_toggle)
	checks.restore_map = game.mini_map.visible and not ui.map_toggle.visible
	await tap(game.mini_map.map_rect().get_center()+game.mini_map.position)
	checks.map_pan = not game.map_camera.following
	await press(game.mini_map.locate_button)
	checks.map_locate = game.map_camera.following
	await shot("day")
	# Menu must really pause normal frame processing, without accumulating dt.
	game.set_process(true)
	await press(ui.menu_button)
	var elapsed: float = game.elapsed
	var clock: float = game.schedule.clock_elapsed
	checks.menu_pauses = paused and ui.menu.visible and game.world_input_blocked()
	for index in range(20):
		await frame()
	checks.paused_clock_and_simulation = game.elapsed == elapsed and game.schedule.clock_elapsed == clock
	await shot("menu")
	await press(ui.menu.get_children().filter(func(c): return c is Button and c.text == "继续行动")[0])
	checks.menu_resumes = not paused and not ui.menu.visible
	game.set_process(false)
	game._process(0.1)
	checks.no_resume_jump = game.elapsed-elapsed < 0.2 and game.schedule.clock_elapsed-clock < 0.2
	# Daily schedule is deliberately a live modal, not a pause menu.
	await press(ui.clock)
	checks.schedule_open = game.schedule.panel.visible and not paused and not game.mini_map.visible
	clock = game.schedule.clock_elapsed
	game._process(0.2)
	checks.schedule_time_runs = game.schedule.clock_elapsed > clock
	await shot("schedule")
	game.schedule.close()
	await frame()
	# Reach trader with a free inventory, test selection above the full blocker.
	game.schedule.clock_elapsed = (720.0-480)/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.routines.tick()
	for index in range(240):
		game.trade.tick(1.0/60)
	game.actors[0].position = Vector2(540,620)
	game.map_camera.locate_selected()
	game.inventory.wallet = 30
	game.presentation.tick(0)
	game.shop_panel.open("prison_dealer")
	await frame()
	checks.shop_open = game.shop_panel.panel.visible and not game.mini_map.visible
	checks.shop_icons_hidden = game.presentation.interaction.targets.is_empty()
	await press(game.shop_panel.buy)
	checks.buy_item = game.inventory.items(0).size() == 1 and game.inventory.wallet < 30
	await press(game.inventory_panel.slots[0])
	checks.shop_inventory_select = game.inventory_panel.selected_item != "" and not game.orders.active.has(0)
	await shot("shop")
	await press(game.shop_panel.sell)
	checks.sell_item = game.inventory.items(0).is_empty()
	await press(game.shop_panel.buy)
	if game.inventory.items(0).is_empty():
		print("P33_SECOND_BUY_FAIL checks=",checks," disabled=",game.shop_panel.buy.disabled," selected=",game.shop_panel.offers.get_selected_items()," shop=",game.shop_panel.panel.visible," status=",game.status_text," wallet=",game.inventory.wallet," stock=",game.trade.merchants["prison_dealer"].stock)
		quit(2)
		return
	var item_id: String = game.inventory.items(0)[0]
	game.shop_panel.close()
	await frame()
	game.actors[1].position = Vector2(550,640)
	await press(game.inventory_panel.slots[0])
	checks.item_actions_expand = game.inventory_panel.use_button.visible and ui.inventory_paper.size.x >= 320 and safe.grow(1).encloses(ui.inventory_paper.get_global_rect())
	await shot("item-actions")
	await press(game.inventory_panel.transfer_buttons[1])
	checks.transfer_item = game.inventory.items(0).is_empty() and game.inventory.owns(1,item_id)
	await press(game.cards[1])
	await press(game.inventory_panel.slots[0])
	await press(game.inventory_panel.drop_button)
	checks.drop_item = game.inventory.items(1).is_empty() and game.inventory.instances[item_id].location == "ground"
	game.presentation.tick(0)
	await frame()
	if not game.presentation.interaction.extras.has("pickup:"+item_id):
		print("P33_PICKUP_MISSING checks=",checks," item=",game.inventory.instances[item_id]," status=",game.status_text)
		game.presentation.stop_all()
		game.queue_free()
		await process_frame
		quit(2)
		return
	await press(game.presentation.interaction.extras["pickup:"+item_id])
	checks.pickup_item = game.inventory.owns(1,item_id)
	game.actors[1].position = Vector2(1820,770)
	game.map_camera.locate_selected()
	game.presentation.tick(0)
	await press(game.inventory_panel.slots[0])
	await press(game.inventory_panel.use_button)
	checks.use_item = game.inventory.items(1).is_empty() and game.skills.actions.has(1)
	game.skills.cancel(1)
	await press(ui.menu_button)
	await press(game.developer_settings.button)
	checks.developer_from_menu = game.developer_settings.panel.visible and not paused and not ui.menu.visible
	await press(game.developer_settings.panel.get_node("SpeedPreset3"))
	clock = game.schedule.clock_elapsed
	elapsed = game.elapsed
	game._process(0.2)
	checks.developer_clock_only = is_equal_approx(game.schedule.clock_elapsed-clock,0.8) and is_equal_approx(game.elapsed-elapsed,0.2)
	game.schedule.set_time_speed(1)
	game.developer_settings.close()
	# Stage transition uses actual schedule, not concept's decorative timeline.
	game.schedule.clock_elapsed = (1200-480)/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.presentation.tick(0)
	await shot("night")
	checks.night_light = game.presentation.lighting.period == "night" and game.schedule.is_curfew()
	game.schedule.clock_elapsed = game.schedule.limit_seconds
	game._process(0.1)
	await frame()
	checks.deadline_result = game.phase == "failed" and game.schedule.result_panel.visible
	await press(ui.menu_button)
	checks.menu_over_result = ui.menu.visible and ui.menu.z_index > game.schedule.result_panel.z_index
	game.room_selector.item_selected.emit(0)
	await frame()
	checks.menu_change_room = game.room_id == "r01" and paused and game.routine_panel.panel.visible and not ui.menu.visible and not game.schedule.result_panel.visible
	game.routine_panel.close()
	# Isolated end-state fixture verifies the successful result and its restart.
	for actor in game.actors:
		actor.position = game.world.exit_area.get_center()
		if game.world.check_exit(actor):
			game.on_actor_escaped(actor.actor_id)
	await frame()
	checks.success_result = game.phase == "complete" and game.schedule.result_panel.visible
	await press(game.schedule.result_panel.get_children().filter(func(c): return c is Button)[0])
	checks.result_restart = paused and game.routine_panel.panel.visible and game.phase == "playing" and not game.schedule.result_panel.visible and game.schedule.clock_minutes() == 480
	for identifier in ["r01","r02","r03","r04"]:
		game.load_room(identifier,["chat","lockpick","strong"],33)
		game.routine_panel.close() # Dismiss new daily allocation before the existing fixture.
		await frame()
		checks["load_"+identifier] = game.phase == "playing" and game.map_camera.view_rect().size == game.get_viewport_rect().size
		if identifier == "r01":
			await shot("small-room")
	checks.focused = focused > frames*0.95
	var passed: bool = checks.values().all(func(x): return x)
	var report := {"passed":passed,"checks":checks,"window":[root.size.x,root.size.y],"canvas":[game.get_viewport_rect().size.x,game.get_viewport_rect().size.y],"frames":frames,"focused_frames":focused,"scope":"Native Windows D3D12, real screen-touch events across frames. Actual fullscreen world, pause/resume, modal input, merchant and four maps. No Android/iOS device claim."}
	FileAccess.open("res://docs/tests/"+prefix+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("P40_UI passed=",passed," failed=",checks.keys().filter(func(k): return not checks[k])," canvas=",report.canvas)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://p33-ui-test.cfg"))
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
