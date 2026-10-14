extends SceneTree

const Model = preload("res://scripts/minigames/nine_point_round.gd")
const OUT := "res://docs/art/nine-point-v1/"
var checks := {}
var game
var metrics := {}

func check(label: String, passed: bool): checks[label] = passed
func _initialize():
	create_timer(90,true).timeout.connect(func(): push_error("Nine point QA timed out"); quit(2))
	call_deferred("run")
func frame():
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func wait_animation(panel):
	for i in 150:
		await create_timer(0.015,true).timeout
		if not panel.busy: return
	check("animation completes",false)
func shot(name: String):
	await frame(); await frame()
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(OUT+name+".png")

func click(control: Control):
	for pressed_value in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed_value
		event.position = control.get_global_rect().get_center()
		event.global_position = event.position
		root.push_input(event)
		await frame()

func press_key(code: Key):
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)
	await frame()

func rules_checks():
	check("seven plus eight wraps to five",Model.points([6,7]) == 5)
	check("A is one",Model.card_value(0) == 1)
	check("all ten and face ranks zero",[9,10,11,12].all(func(c):return Model.card_value(c) == 0))
	check("nine is highest normal point",Model.points([8]) == 9)
	var conservation := true
	var no_duplicates := true
	var bounded := true
	var tie_seen := false
	var no_repeat := true
	for count in [2,3,4]:
		for seed_value in 150:
			var round = Model.new()
			round.rng.seed = seed_value
			var names := ["林川","周大勇","许文斌","老陆"].slice(0,count)
			var banks := []
			for i in count: banks.append(100)
			var error: String = round.start(names,10,banks)
			bounded = bounded and error.is_empty() and round.hands.all(func(h):return h.size() == 1)
			round.decide(seed_value % 2 == 0)
			conservation = conservation and round.bank_after.reduce(func(total,value):return total+value,0) == count*100
			var used := {}
			for hand in round.hands:
				bounded = bounded and hand.size() <= 2
				for card in hand:
					if used.has(card): no_duplicates = false
					used[card] = true
			no_repeat = no_repeat and not round.decide(true)
			if round.winners.size() > 1:
				tie_seen = true
				var low := 9999
				var high := -1
				for winner in round.winners:
					low = mini(low,round.payouts[winner]); high = maxi(high,round.payouts[winner])
				conservation = conservation and high-low <= 1
	check("450 rounds conserve all money",conservation)
	check("no duplicated cards in a round",no_duplicates)
	check("one optional second card only",bounded)
	check("ties exercised",tie_seen)
	check("450 rounds reject a repeated decision",no_repeat)
	var round = Model.new()
	check("insufficient money rejected before any cards",not round.start(["a","b"],10,[0,100]).is_empty() and round.hands.is_empty())
	check("invalid count rejected",not round.start(["a"],10,[100]).is_empty())
	check("invalid stake rejected",not round.start(["a","b"],-1,[100,100]).is_empty())
	round = Model.new()
	round.start(["a","b","c","d"],10,[100,100,100,100])
	round.forfeit()
	check("forfeiting player never wins",0 not in round.winners and round.bank_after[0] == 90)
	check("forfeit also conserves pot",round.bank_after.reduce(func(total,value):return total+value,0) == 400)
	check("forfeit cannot settle twice",not round.forfeit())
	round = Model.new()
	round.start(["a","b"],0,[0,0]); round.decide(false)
	check("practice never changes balances",round.bank_after == [0,0])

func run():
	rules_checks()
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://nine-point-qa-dev.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://nine-point-qa-buttons.cfg")
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	var disk_hash := FileAccess.get_sha256("res://data/rooms/r04.json")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame(); await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.phase = "playing"
	game.fullscreen_ui.menu.hide()
	game.schedule.panel.hide()
	game.developer_settings.panel.hide()
	game.dialogue.close()
	game.tutorial.cancel()
	game.actors[0].position = Vector2(1090,454)
	game.orders.clear()
	game.room_visibility.tick(0)
	game.presentation.tick(0)
	game.inventory.wallet = 100
	var controller = game.nine_point
	var panel = controller.panel
	check("R04 card table discovered",controller.tables().size() == 1)
	check("nearby table can be entered",controller.reason("chess-card-table").is_empty())
	game.presentation.interaction.refresh()
	check("nearby E/mobile target registered",game.presentation.interaction.targets.any(func(t):return t.kind == "nine_point"))
	var texture_memory_before := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
	game.presentation.interaction.mobile_target_key = "0:nine_point:chess-card-table"
	await press_key(KEY_E)
	check("world interaction opens the real UI",controller.is_open())
	check("world paused while at table",paused and game.world_input_blocked())
	var deal_before: int = game.deal_number
	await press_key(KEY_R)
	check("game restart shortcut cannot reset a seated game",game.deal_number == deal_before and controller.is_open() and game.inventory.wallet == 100)
	check("12 bounded seated resources loaded",panel.poses.size() == 4 and panel.poses.values().all(func(p):return p.size() == 3))
	check("all seated sprites bounded at 256",panel.poses.values().all(func(p):return p.values().all(func(t):return maxi(t.get_width(),t.get_height()) <= 256)))
	check("seated textures keep transparent alpha",panel.poses.values().all(func(p):return p.values().all(func(t):return t.get_image().detect_alpha() != Image.ALPHA_NONE)))
	check("full minigame pixel budget under 12MiB",panel.asset_bytes < 12*1024*1024)
	metrics = {"art_pixel_bytes":panel.asset_bytes,"cold_art_load_ms":panel.art_load_ms,"texture_memory_delta":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)-texture_memory_before}
	await frame(); await frame()
	var redraws_before: int = panel.paint_count
	for i in 20: await frame()
	check("static table does not redraw every frame",panel.paint_count == redraws_before)
	controller.amount = 10
	panel.refresh()
	await shot("betting-4p-1200x720")
	await click(panel.primary)
	check("mouse click accepts bet",controller.round_model.state == "decision")
	check("bet deducted exactly once",game.inventory.wallet == 90 and controller.npc_banks == [190,190,190])
	check("repeat confirm cannot debit again",not controller.confirm_bet() and game.inventory.wallet == 90)
	await wait_animation(panel)
	await shot("decision-4p-1200x720")
	await press_key(KEY_E)
	check("keyboard E draws second card",controller.round_model.hands[0].size() == 2)
	await wait_animation(panel)
	var wallet_after: int = game.inventory.wallet
	check("drawing resolves and shows all points",controller.round_model.state == "result" and panel.revealed and controller.round_model.hands[0].size() == 2)
	controller.commit_result(); panel.refresh(); controller.commit_result()
	check("redraw and repeat commit cannot duplicate payout",game.inventory.wallet == wallet_after)
	check("wallet plus NPC ledgers conserve money",game.inventory.wallet+controller.npc_banks.reduce(func(total,value):return total+value,0) == 700)
	await shot("result-4p-1200x720")
	for count in [2,3]:
		panel.primary.pressed.emit()
		controller.player_count = count
		panel.refresh()
		await shot("betting-%dp-1200x720" % count)
		panel.primary.pressed.emit()
		await wait_animation(panel)
		await press_key(KEY_SPACE)
		await wait_animation(panel)
		check("%d player stand uses one card" % count,controller.round_model.hands[0].size() == 1)
	panel.primary.pressed.emit()
	controller.player_count = 4
	panel.refresh()
	root.size = Vector2i(960,540); root.content_scale_size = root.size
	await frame(); panel.layout()
	await shot("betting-4p-960x540")
	check("960 viewport fits both actions",root.get_visible_rect().encloses(panel.primary.get_global_rect()) and root.get_visible_rect().encloses(panel.secondary.get_global_rect()))
	await click(panel.board.get_children().filter(func(c):return c is Button and c.text == "规则")[0])
	await shot("rules-960x540")
	check("rules contains costs and face card convention",panel.modal_text.text.contains("10/J/Q/K") and panel.modal_text.text.contains("弃局"))
	panel._modal_yes()
	controller.close()
	var banks_before_reopen: Array = controller.npc_banks.duplicate()
	check("exit restores world pause",not paused and not game.world_input_blocked())
	check("exit releases minigame textures",panel.poses.is_empty() and panel.background == null)
	game.actors[0].position = Vector2(2800,2000)
	check("stale far interaction rejected",not controller.open_table("chess-card-table"))
	game.actors[0].position = Vector2(1090,454)
	game.inventory.wallet = 0
	controller.open_table("chess-card-table")
	check("reopening table does not refill NPC bankrolls",controller.npc_banks == banks_before_reopen)
	controller.amount = 10; panel.refresh()
	check("zero money disables paid betting",panel.primary.disabled and not controller.confirm_bet() and game.inventory.wallet == 0)
	controller.amount = 0; panel.refresh()
	check("practice remains available with zero wallet",not panel.primary.disabled and controller.confirm_bet())
	await wait_animation(panel)
	controller.decide(false); await wait_animation(panel)
	check("practice preserves actual wallet",game.inventory.wallet == 0)
	controller.close()
	game.inventory.wallet = 100
	controller.open_table("chess-card-table")
	controller.amount = 10
	controller.confirm_bet(); await wait_animation(panel)
	controller.request_close()
	check("paid unfinished exit asks about forfeit",panel.modal.visible and panel.modal_no.visible and controller.is_open())
	panel.modal_no.pressed.emit()
	check("cancel exit keeps same cards and charge",controller.round_model.state == "decision" and game.inventory.wallet == 90 and not panel.modal.visible)
	controller.request_close(); panel._modal_yes()
	check("confirmed forfeit cannot refund or win",game.inventory.wallet == 90 and not controller.is_open() and not paused)
	metrics["map_sha256_at_start"] = disk_hash
	metrics["map_sha256_at_end"] = FileAccess.get_sha256("res://data/rooms/r04.json")
	metrics["concurrent_map_change"] = metrics.map_sha256_at_start != metrics.map_sha256_at_end
	var failed := []
	for key in checks:
		if not checks[key]: failed.append(key)
	var report := {"checks":checks,"failed":failed,"count":checks.size(),"display":DisplayServer.get_name(),"metrics":metrics}
	FileAccess.open(OUT+("headless" if DisplayServer.get_name() == "headless" else "native")+"-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("Nine point checks: ",checks.size()," failed ",failed)
	game.queue_free()
	await frame()
	quit(0 if failed.is_empty() else 1)
