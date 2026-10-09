extends SceneTree

var game
var checks := {}
var layouts: Array = []
func _initialize(): call_deferred("run")
func check(key: String, value: bool):
	checks[key] = value
	print(key+": "+str(value))
func image(label: String):
	if DisplayServer.get_name()=="headless": return
	game.presentation.tick(0)
	game.fullscreen_ui.fps_badge.hide()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/tests/p94-"+label+".png")
func add_item(kind: String) -> String:
	var id: String = game.inventory.add_ground(kind,game.actors[0].position)
	var result: Dictionary = game.inventory.try_pickup(0,id)
	check("pickup_"+kind,result.ok)
	return id
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_FRAME_SETTINGS_PATH","user://p94-ui.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://p94-ui-layout.cfg")
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.reset_round(["backpack","chat","strong"],94)
	game.room_visibility.tick(0.5)
	var ui = game.fullscreen_ui
	var inv = game.inventory_panel
	var drawer = ui.inventory_drawer
	check("one_player_status",game.cards[0].visible and not game.cards[1].visible and not game.cards[2].visible)
	check("status_has_no_selection_number",game.cards[0].mouse_filter==Control.MOUSE_FILTER_IGNORE)
	check("daily_planner_removed",not ui.routine_button.visible and not game.routine_panel.panel.visible)
	check("map_starts_collapsed",ui.minimap_collapsed)
	check("collapsed_map_does_not_consume_touch",not game.mini_map.is_processing_input())
	ui.minimap_collapsed = false
	ui.refresh()
	check("expanded_map_accepts_touch",game.mini_map.is_processing_input())
	check("legacy_transfer_buttons_hidden",inv.transfer_buttons.all(func(button):return not button.visible))
	var key := add_item("door_key")
	var tool := add_item("lock_tool")
	var scrap := add_item("scrap")
	ui.bag_open = true
	inv._select(1)
	ui.refresh()
	check("bag_collapses_map_and_disables_map_input",ui.minimap_collapsed and not game.mini_map.is_processing_input())
	check("tool_selection_details",inv.selected_item==tool and drawer.thumbnail.texture==drawer.icon_for("lock_tool") and not drawer.item_name.text.is_empty())
	check("use_disabled_away_from_door",inv.use_button.disabled)
	check("atlas_has_transparent_bounds",drawer.icons.size()==4 and drawer.icon_for("door_key").region.size.x>200 and drawer.icon_for("backpack").region.size.y>200)
	for size in [Vector2i(1200,720),Vector2i(960,540),Vector2i(1440,900)]:
		root.size = size
		root.content_scale_size = size
		await process_frame
		ui.layout()
		inv._select(1)
		ui.refresh()
		await process_frame
		var safe: Rect2 = ui.safe_area()
		var bounds: Rect2 = drawer.paper.get_rect()
		var all_fit := safe.encloses(bounds)
		var slots_fit: bool = inv.slots.filter(func(slot):return slot.visible).all(func(slot):return Rect2(Vector2.ZERO,drawer.paper.size).encloses(slot.get_rect()))
		var text_fit: bool = drawer.description.get_minimum_size().y<=drawer.description.size.y+1
		for item_index in range(3):
			inv._select(item_index)
			ui.refresh()
			await process_frame
			text_fit = text_fit and drawer.description.get_minimum_size().y<=drawer.description.size.y+1
		inv._select(1)
		ui.refresh()
		var footer_fit: bool = inv.drop_button.get_rect().end.y<=(drawer.hint.position.y+1 if drawer.hint.visible else drawer.paper.size.y-8)
		var row_clear: bool = not game.cards[0].get_rect().intersects(ui.clock.get_rect()) and not ui.clock.get_rect().intersects(ui.wallet.get_rect())
		var drawer_clear: bool = not drawer.paper.get_rect().intersects(ui.clock.get_rect()) and not drawer.paper.get_rect().intersects(game.cards[0].get_rect())
		check("drawer_layout_"+str(size.x),all_fit and slots_fit and text_fit and footer_fit and row_clear and drawer_clear)
		layouts.append({"size":str(size),"paper":str(bounds),"description_min_height":drawer.description.get_minimum_size().y,"description_height":drawer.description.size.y,"footer_bottom":inv.drop_button.get_rect().end.y,"hint_top":drawer.hint.position.y})
		await image("bag-three-"+str(size.x))
		ui.bag_open = false
		ui.refresh()
		check("drawer_closes_"+str(size.x),not drawer.paper.visible)
		check("closed_bag_hides_transfer_buttons_"+str(size.x),inv.transfer_buttons.all(func(button):return not button.visible))
		await image("hud-"+str(size.x))
		ui.bag_open = true
	ui.refresh()
	inv._select(2)
	inv.drop_button.pressed.emit()
	check("drop_returns_item_to_ground",game.inventory.instances[scrap].location=="ground" and not game.inventory.items(0).has(scrap))
	var gate: Dictionary = game.world.access_by_id("maintenance-entry")
	game.actors[0].position = game.world.door_interaction_point(gate)
	game.world.set_access_closed(str(gate.id),true)
	inv._select(0)
	ui.refresh()
	check("use_enabled_near_locked_door",not inv.use_button.disabled)
	inv.use_button.pressed.emit()
	check("key_opens_door_and_consumes",not game.world.access_by_id(str(gate.id)).closed and game.inventory.instances[key].location=="consumed")
	game.world.set_access_closed(str(gate.id),true)
	inv._select(0)
	ui.refresh()
	inv.use_button.pressed.emit()
	check("tool_starts_real_six_second_lockpick",game.skills.actions.has(0) and game.skills.actions[0].kind=="lock_tool" and game.inventory.instances[tool].location=="consumed")
	game.skills.tick(6.01)
	check("lockpick_opens_real_door",not game.world.access_by_id(str(gate.id)).closed)
	game.reset_round(["chat","backpack","strong"],94)
	game.room_visibility.tick(0.5)
	root.size = Vector2i(960,540)
	root.content_scale_size = root.size
	await process_frame
	ui.layout()
	ui.bag_open = true
	ui.refresh()
	check("one_capacity_shows_one_slot",inv.slots.filter(func(slot):return slot.visible).size()==1 and drawer.capacity.text=="0 / 1")
	check("empty_bag_buttons_disabled",inv.use_button.disabled and inv.drop_button.disabled)
	await image("bag-empty-one-960")
	ui.bag_open = false
	game.shop_panel.panel.show()
	game.shop_panel.blocker.show()
	ui.refresh()
	check("shop_and_inventory_do_not_overlap",drawer.paper.visible and not drawer.paper.get_rect().intersects(game.shop_panel.panel.get_rect()))
	await image("shop-960")
	drawer.close_button.pressed.emit()
	check("close_dismisses_bag_and_shop",not drawer.paper.visible and not game.shop_panel.panel.visible)
	game.reset_round(["backpack","chat","strong"],94)
	ui.bag_open = true
	ui.refresh()
	ui.toggle_menu()
	check("pause_hides_inventory",not drawer.paper.visible and paused)
	ui.close_menu()
	check("resume_restores_inventory",drawer.paper.visible and not paused)
	ui.bag_open = false
	game.tutorial.begin()
	var task_layout_ok := true
	for size in [Vector2i(960,540),Vector2i(1200,720)]:
		root.size = size
		root.content_scale_size = size
		await process_frame
		ui.layout()
		for step_id in game.tutorial.steps:
			game.tutorial.step_id = step_id
			game.tutorial._refresh()
			ui.refresh()
			await process_frame
			task_layout_ok = task_layout_ok and game.tutorial.body.get_minimum_size().y<=game.tutorial.body.size.y+1
		check("tutorial_hides_legacy_transfer_buttons_"+str(size.x),inv.transfer_buttons.all(func(button):return not button.visible))
	check("all_tutorial_task_text_fits",task_layout_ok)
	var failed: Array = checks.keys().filter(func(k):return not checks[k])
	FileAccess.open("res://docs/tests/p94-single-player-ui.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"layouts":layouts},"\t"))
	print(JSON.stringify({"failed":failed,"checks":checks}))
	quit(0 if failed.is_empty() else 1)
