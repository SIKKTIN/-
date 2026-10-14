extends SceneTree
const Rules = preload("res://scripts/minigames/nine_point_round.gd")
const OUT := "res://docs/art/nine-point-v3/"
var game
var checks := {}
func _initialize():
	create_timer(100,true).timeout.connect(func(): push_error("Nine point v3 timed out"); quit(2))
	call_deferred("run")
func frame():
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func shot(name: String):
	await frame(); await frame()
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(OUT+name+".png")
func key(code: Key):
	var event := InputEventKey.new()
	event.keycode = code; event.pressed = true
	root.push_input(event)
	await frame()
func mouse(point: Vector2, pressed_value: bool):
	var event := InputEventMouseButton.new()
	event.position = point; event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed_value
	root.push_input(event)
	await frame()
func stroke(card, touch := false):
	var start: Vector2 = card.get_global_transform_with_canvas()*Vector2(30,65)
	if touch:
		var press := InputEventScreenTouch.new()
		press.index = 2; press.position = start; press.pressed = true
		root.push_input(press)
	else: await mouse(start,true)
	for i in 15:
		var point: Vector2 = card.get_global_transform_with_canvas()*Vector2(30+i*6,65+i*4.5)
		if touch:
			var event := InputEventScreenDrag.new()
			event.index = 2; event.position = point
			root.push_input(event)
		else:
			var event := InputEventMouseMotion.new()
			event.position = point; event.global_position = point; event.button_mask = MOUSE_BUTTON_MASK_LEFT
			root.push_input(event)
		await frame()
	if touch:
		var release := InputEventScreenTouch.new()
		release.index = 2; release.position = start; release.pressed = false
		root.push_input(release)
	else: await mouse(start,false)

func wipe(card):
	for y in range(20,220,22):
		if card.exposed: break
		var point: Vector2 = card.get_global_transform_with_canvas()*Vector2(8,y)
		await mouse(point,true)
		for x in range(8,165,8):
			if card.exposed: break
			var motion := InputEventMouseMotion.new()
			motion.position = card.get_global_transform_with_canvas()*Vector2(x,y)
			motion.global_position = motion.position
			motion.button_mask = MOUSE_BUTTON_MASK_LEFT
			root.push_input(motion)
		await mouse(point,false)

func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var conserved := true
	var deferred := true
	for count in [2,3,4]:
		for seed_value in 60:
			var model = Rules.new(); model.rng.seed = seed_value
			var names: Array = ["a","b","c","d"].slice(0,count)
			model.start(names,10,[100,100,100,100].slice(0,count))
			model.draw_for_reveal()
			deferred = deferred and model.state == "revealing" and model.winners.is_empty() and model.payouts.all(func(v):return v == 0) and not model.draw_for_reveal()
			if seed_value % 2 == 0: model.finish_reveal()
			else: model.forfeit()
			conserved = conserved and model.bank_after.reduce(func(sum,v):return sum+v,0) == count*100 and not model.finish_reveal() and not model.forfeit() and (seed_value % 2 == 0 or 0 not in model.winners)
	checks["180 pending reveals never settle early or draw third card"] = deferred
	checks["180 reveal or interrupted rounds conserve money once"] = conserved
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://nine-v3-qa.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://nine-v3-buttons.cfg")
	root.size = Vector2i(1200,720); root.content_scale_size = root.size
	var hash_before := FileAccess.get_sha256("res://data/rooms/r04.json")
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await frame(); await frame()
	game.set_process(false)
	game.phase = "playing"
	game.fullscreen_ui.close_menu()
	game.schedule.panel.hide(); game.developer_settings.panel.hide()
	game.tutorial.cancel(); game.dialogue.close()
	game.schedule.clock_elapsed = (1030.0-game.schedule.config.start_minutes)/1440.0*game.schedule.day_seconds
	game.schedule.set_time_speed(1)
	game.schedule.tick(false); game.routines.tick()
	game.orders.clear()
	game.actors[0].position = Vector2(1090,454)
	game.room_visibility.tick(0); game.presentation.tick(0)
	game.inventory.wallet = 100
	var controller = game.nine_point
	var panel = controller.panel
	var zoom_before: Vector2 = game.map_camera.zoom
	checks["nearby world table opens"] = controller.open_table("chess-card-table")
	checks["world is not paused"] = not paused and game.world_input_blocked()
	checks["local panel leaves at least 70 percent visible"] = panel.board.get_global_rect().get_area()/root.get_visible_rect().get_area() < 0.3 and panel.screen.mouse_filter == Control.MOUSE_FILTER_IGNORE
	var clock_before: float = game.schedule.clock_elapsed
	var elapsed_before: float = game.elapsed
	game._process(1)
	checks["world clock and simulation advance while seated"] = game.schedule.clock_elapsed > clock_before and game.elapsed > elapsed_before and controller.is_open()
	game.show_status("广播：自由活动结束前，请留意集合。",5)
	await frame()
	checks["external event toast stays visible"] = panel.event_toast.visible and panel.event_text.text.contains("广播")
	checks["seated actor cannot receive manual movement"] = not game.orders.issue(0,Vector2(1120,500))
	controller.amount = 10; panel.refresh()
	await shot("betting-4p")
	await key(KEY_E)
	checks["initial draw enters scratch and debits once"] = panel.scratch_index == 0 and panel.known_cards == 0 and game.inventory.wallet == 90 and not controller.confirm_bet()
	await stroke(panel.scratch)
	checks["real mouse drag partially reveals card"] = panel.scratch.coverage() > 0.03 and panel.scratch.coverage() < 0.62 and panel.known_cards == 0
	await shot("scratch-first-partial")
	var coverage: float = panel.scratch.coverage()
	var hover := InputEventMouseMotion.new(); hover.position = panel.scratch.get_global_rect().get_center()
	root.push_input(hover); await frame()
	checks["released pointer cannot keep scratching"] = is_equal_approx(coverage,panel.scratch.coverage())
	await key(KEY_E)
	checks["explicit flip reveals first card only"] = panel.known_cards == 1 and panel.scratch_index == -1 and controller.round_model.state == "decision"
	await shot("decision-4p")
	await key(KEY_E)
	checks["second draw does not disclose winner or pay"] = controller.round_model.state == "revealing" and not controller.committed and controller.round_model.winners.is_empty() and game.inventory.wallet == 90 and panel.known_cards == 1
	controller.finish_reveal()
	checks["settlement cannot bypass hidden card"] = not controller.committed and controller.round_model.state == "revealing"
	await stroke(panel.scratch,true)
	checks["touch drag also partially scratches"] = panel.scratch.coverage() > 0.03 and panel.scratch_index == 1
	await shot("scratch-second-partial")
	panel.show_rules(); await frame()
	checks["rules remain inside local panel"] = panel.modal.get_global_rect().get_area() < root.get_visible_rect().get_area()*0.3 and not paused
	panel._modal_yes()
	await wipe(panel.scratch)
	await create_timer(0.6,true).timeout
	checks["scratching enough automatically uncovers"] = panel.scratch.exposed and panel.scratch.coverage() >= 0.62
	checks["reveal settles once and shows result"] = panel.revealed and panel.known_cards == 2 and controller.committed
	var wallet: int = game.inventory.wallet
	controller.finish_reveal(); controller.commit_result()
	checks["repeat reveal cannot duplicate reward"] = game.inventory.wallet == wallet
	checks["real wallet and NPC ledgers conserve pot"] = game.inventory.wallet+controller.npc_banks.reduce(func(sum,v):return sum+v,0) == 700
	await shot("result-4p")
	for count in [2,3]:
		controller.prepare(); panel.known_cards = 0; panel.revealed = false
		controller.player_count = count; panel.refresh()
		await shot("betting-%dp" % count)
	controller.player_count = 4; panel.refresh()
	root.size = Vector2i(960,540); root.content_scale_size = root.size
	await frame(); panel.layout(); await shot("betting-960x540")
	checks["small viewport keeps actions in bounds"] = root.get_visible_rect().encloses(panel.board.get_global_rect())
	game.fullscreen_ui.toggle_menu(); await frame()
	checks["global pause menu retains priority"] = paused and not panel.screen.visible
	game.fullscreen_ui.close_menu(); await frame()
	checks["return from pause restores same card UI"] = panel.screen.visible and not paused
	controller.close()
	checks["exit restores camera and releases assets"] = game.map_camera.zoom == zoom_before and panel.background == null and panel.poses.is_empty() and not controller.world_view.visible
	controller.open_table("chess-card-table"); controller.amount = 0
	controller.confirm_bet(); panel.scratch.reveal_all(); controller.decide(false)
	await create_timer(0.5,true).timeout
	checks["practice with scratch does not change wallet"] = game.inventory.wallet == wallet
	controller.close()
	controller.open_table("chess-card-table"); controller.amount = 5
	controller.confirm_bet(); panel.scratch.reveal_all(); controller.decide(true)
	var charged: int = game.inventory.wallet
	controller.request_close(); panel.modal_no.pressed.emit()
	checks["cancel exit preserves hidden second card"] = controller.round_model.state == "revealing" and game.inventory.wallet == charged and panel.scratch_index == 1
	var moved: bool = game.orders.issue(0,Vector2(1120,500),"routine")
	checks["forced movement interrupts pending reveal"] = moved and not controller.is_open() and controller.round_model.forfeited and game.inventory.wallet == charged
	game.orders.stop(0)
	game.actors[0].position = Vector2(1090,454)
	controller.open_table("chess-card-table"); controller.amount = 5
	controller.confirm_bet(); panel.scratch.reveal_all(); controller.decide(true)
	charged = game.inventory.wallet
	game.capture_actor(0)
	checks["capture closes and forfeits pending reveal"] = not controller.is_open() and controller.round_model.forfeited and game.inventory.wallet == charged and 0 not in controller.round_model.winners
	checks["capture does not leave world paused"] = not paused
	checks["R04 unchanged"] = hash_before == FileAccess.get_sha256("res://data/rooms/r04.json")
	var failed := checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"count":checks.size()},"\t"))
	print("NINE_V3 ",checks.size()," failed ",failed)
	game.queue_free(); await frame()
	quit(0 if failed.is_empty() else 1)
