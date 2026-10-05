extends SceneTree

var game
var checks := {}
var prefix := "p28-native"
var focused_frames := 0
var rendered_frames := 0

func _initialize() -> void:
	call_deferred("run")

func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	rendered_frames += 1
	focused_frames += int(root.has_focus())

func tap(point: Vector2) -> void:
	root.grab_focus()
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = root.get_final_transform()*point
	event.pressed = true
	Input.parse_input_event(event)
	await frame()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frame()

func screenshot(suffix: String) -> void:
	await frame()
	root.get_texture().get_image().save_png("res://docs/tests/"+prefix+"-"+suffix+".png")

func run() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		prefix += "-"+OS.get_cmdline_user_args()[0]
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.load_room("r04",["backpack","lockpick","strong"],28)
	game.set_process(false)
	root.grab_focus()
	await frame()
	var label: Label = game.schedule.clock_label
	checks.clock_header_fits = label.get_global_rect().end.x < game.room_selector.position.x and label.get_global_rect().end.y < 70
	await tap(game.schedule.stage_button.get_global_rect().get_center())
	checks.touch_opens_schedule = game.schedule.panel.visible
	game._process(1)
	checks.schedule_live_clock = game.elapsed == 1
	await screenshot("schedule")
	await tap(game.schedule.panel.position+Vector2(230,264))
	checks.touch_closes_schedule = not game.schedule.panel.visible
	var merchant: String = game.trade.merchants.keys()[0]
	var p: Array = game.trade.merchants[merchant].position
	game.actors[0].position = Vector2(p[0]+35,p[1])
	game.map_camera.locate_selected()
	game.presentation.tick(0)
	var trade_button: Button = game.presentation.interaction.extras["trade:"+merchant]
	await tap(trade_button.get_global_rect().get_center())
	checks.touch_opens_shop = game.shop_panel.panel.visible
	checks.shop_hides_world_icons = not trade_button.visible and not game.presentation.interaction.button.visible
	var before: Vector2 = game.actors[0].position
	await tap(Vector2(150,350))
	checks.modal_blocks_world_tap = game.actors[0].position == before and not game.orders.active.has(0)
	var item: String = game.inventory.add_ground("scrap",game.actors[0].position)
	checks.pickup_setup = game.inventory.try_pickup(0,item).ok
	game._update_ui()
	await tap(game.inventory_panel.slots[0].get_global_rect().get_center())
	game.shop_panel.refresh()
	checks.touch_selects_inventory_behind_shop = game.inventory_panel.selected_item == item and not game.shop_panel.sell.disabled
	await tap(game.shop_panel.sell.get_global_rect().get_center())
	checks.touch_sell = game.inventory.wallet == 3 and game.inventory.items(0).is_empty()
	game.inventory.wallet = 20
	game._update_ui()
	await tap(game.shop_panel.buy.get_global_rect().get_center())
	checks.touch_buy = game.inventory.wallet == 11 and game.inventory.items(0).size() == 1
	await screenshot("shop")
	await tap(game.shop_panel.panel.position+Vector2(408,318))
	checks.touch_closes_shop = not game.shop_panel.panel.visible and not game.shop_panel.blocker.visible
	game.load_room("r01",["chat","lockpick","strong"],28)
	game.set_process(false)
	game.elapsed = 120
	game.schedule.tick(false)
	game.dog.position = Vector2(865,520)
	game.dog.state = "patrol"
	game.dog.facing = Vector2.LEFT
	var visual = game.presentation.dog_visual
	checks.dog_art_loaded = visual.idle != null and visual.frames.size() == 4
	var seen := {}
	game.dog.moved_this_frame = true
	for i in range(4):
		visual.tick_visual(0.001 if i == 0 else 0.1)
		seen[visual.frame_index] = true
	checks.dog_four_frames_and_flip = seen.size() == 4 and visual.flip_h
	var anchor: Array = visual.definition.walk_animation.frames[visual.frame_index].anchor
	var ratio: float = visual.definition.world_height/visual.definition.walk_animation.scale_height
	checks.dog_registered_scale = is_equal_approx(visual.destination.position.y,-anchor[1]*ratio)
	game.dog.moved_this_frame = false
	visual.tick_visual(0)
	checks.dog_returns_to_idle = visual.frame_index == -1 and visual.texture == visual.idle
	game.presentation.tick(0)
	checks.long_stage_header_fits = label.get_global_rect().end.x < game.room_selector.position.x and label.get_global_rect().end.y < 70
	await screenshot("night-dog")
	game.elapsed = 179.95
	game._process(0.1)
	await screenshot("timeout")
	checks.timeout_overlay = game.phase == "failed" and game.schedule.result_panel.visible
	await tap(game.room_selector.get_global_rect().get_center())
	checks.terminal_room_selector_receives_touch = game.room_selector.get_popup().visible
	game.room_selector.get_popup().hide()
	await frame()
	await tap(game.schedule.result_panel.position+Vector2(250,205))
	checks.touch_restarts_terminal = game.phase == "playing" and game.elapsed == 0 and not game.schedule.result_panel.visible and game.presentation.lighting.period == "day"
	var passed: bool = checks.values().all(func(c): return c)
	var report := {"passed":passed,"checks":checks,"focused_frames":focused_frames,"rendered_frames":rendered_frames,"window":[root.size.x,root.size.y],"scope":"Native Godot D3D12 renderer; simulated screen-touch press/release. No physical mobile or human usability test."}
	FileAccess.open("res://docs/tests/"+prefix+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("P28_NATIVE passed=",passed," failed=",checks.keys().filter(func(k): return not checks[k])," focused=",focused_frames,"/",rendered_frames)
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
