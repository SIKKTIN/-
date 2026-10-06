extends SceneTree

var game
var checks := {}
var native := false
var width := 1200

func _initialize() -> void:
	call_deferred("run")

func frame() -> void:
	await process_frame
	if native:
		await RenderingServer.frame_post_draw

func touch(id: int, point: Vector2, down: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = root.get_final_transform()*point
	event.pressed = down
	event.canceled = canceled
	Input.parse_input_event(event)
	await frame()

func drag(id: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = id
	event.position = root.get_final_transform()*point
	Input.parse_input_event(event)
	await frame()

func tap(button: Control, id := 1) -> void:
	var point := button.get_global_rect().get_center()
	await touch(id,point,true)
	await touch(id,point,false)

func walk(frames: int) -> void:
	for index in range(frames):
		game._process(1.0/60)
	await frame()

func key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	await frame()

func fresh(skills: Array = ["chat","lockpick","backpack"]) -> void:
	game.load_room("r04",skills,46)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	game.presentation.tick(0)
	game._update_ui()

func shot(label: String) -> void:
	if native:
		game.presentation.tick(0)
		game._update_ui()
		await frame()
		await frame()
		root.get_texture().get_image().save_png("res://docs/tests/p50-mobile-regression-%d-%s.png" % [width,label])

func run() -> void:
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://p50-mobile-regression-layout.cfg")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://p50-mobile-regression-layout.cfg"))
	native = DisplayServer.get_name() != "headless"
	var args := OS.get_cmdline_user_args()
	width = int(args[0]) if not args.is_empty() else 1200
	root.content_scale_size = Vector2i(width,540 if width == 960 else 720)
	root.size = root.content_scale_size
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	checks.first_day_planner_pauses = paused and game.routine_panel.panel.visible
	fresh()
	if native:
		root.grab_focus()
		await frame()
	var ui = game.fullscreen_ui
	var controls = game.mobile_controls
	var pad = controls.pad
	checks.vertical_cards = game.cards[0].position.x == game.cards[1].position.x and game.cards[1].position.x == game.cards[2].position.x and game.cards[0].position.y < game.cards[1].position.y and game.cards[1].position.y < game.cards[2].position.y
	checks.cards_above_pad = game.cards[2].get_global_rect().end.y+8 <= pad.get_global_rect().position.y
	checks.pad_touch_size = pad.size.x >= 120 and pad.size.y >= 120
	checks.main_action_size = ui.action_button.size.x >= 88 and ui.action_button.size.y >= 88
	var controls_rects: Array = game.cards.map(func(b): return b.get_global_rect())+[pad.get_global_rect(),ui.action_button.get_global_rect(),ui.ability_button.get_global_rect(),ui.bag_button.get_global_rect()]
	checks.controls_inside_safe = controls_rects.all(func(r): return ui.safe_area().encloses(r))
	var disjoint := true
	for a in range(controls_rects.size()):
		for b in range(a+1,controls_rects.size()):
			disjoint = disjoint and not controls_rects[a].intersects(controls_rects[b])
	checks.no_touch_overlap = disjoint
	checks.bag_initially_closed = not ui.bag_open and not ui.inventory_paper.visible
	checks.no_target_disabled = ui.action_button.disabled
	await shot("layout")
	var center: Vector2 = pad.get_global_rect().get_center()
	var old: Vector2 = game.actors[0].position
	await touch(0,center,true)
	await walk(12)
	checks.deadzone_no_movement = game.actors[0].position == old and not controls.is_moving()
	await drag(0,center+Vector2(150,0))
	await walk(12)
	checks.real_touch_moves_selected = game.actors[0].position.x > old.x+30 and game.actors[1].position == game.actors[1].home
	checks.faces_motion_direction = game.actors[0].facing.x > 0.9
	checks.joystick_not_camera_drag = game.map_camera.pointer_id == -2
	checks.follow_during_move = game.map_camera.following
	game.orders.issue(0,game.actors[0].home,"curfew")
	await walk(1)
	checks.held_stick_overrides_new_order = not game.orders.active.has(0) and game.routines.manual.has(0)
	await touch(0,center+Vector2(150,0),false)
	old = game.actors[0].position
	await walk(20)
	checks.release_stops_immediately = game.actors[0].position == old and controls.direction == Vector2.ZERO
	await touch(0,center+Vector2(-40,0),true)
	await walk(6)
	checks.faces_left = game.actors[0].facing.x < -0.9
	await tap(game.cards[1],1)
	checks.second_finger_switches = game.selected_actor_id == 1
	checks.switch_clears_stick = controls.direction == Vector2.ZERO and controls.pad_pointer == -2
	old = game.actors[1].position
	await drag(0,center+Vector2(150,0))
	await walk(12)
	checks.old_finger_cannot_move_new_actor = game.actors[1].position == old
	await touch(0,center,false)
	await touch(0,center+Vector2(40,0),true)
	await walk(12)
	checks.new_touch_controls_new_actor = game.actors[1].position.x > old.x+20
	await touch(0,center,false)
	# Body-to-wall movement uses physical collision, no destination/path request.
	game.actors[1].position = Vector2(450,570)
	await touch(0,center+Vector2(40,0),true)
	await walk(120)
	checks.wall_stops_direct_motion = game.actors[1].position.x < 470 and game.world.can_place_circle(game.actors[1].position,17,game.actors[1],false)
	await touch(0,center,false)
	game.actors[1].position = game.world.door.get_center()+Vector2(-40,0)
	await touch(0,center+Vector2(40,0),true)
	await walk(30)
	checks.locked_gate_stops_motion = game.actors[1].position.x <= game.world.door.position.x-17+0.01 and not game.world.door_open
	await touch(0,center,false)
	fresh()
	# Keep genuine chat and a working routine running while another actor moves.
	game.guard.position = Vector2(850,760)
	game.actors[0].position = Vector2(800,760)
	game.actors[2].position = game.routines._target(2,"work")
	var plans: Array = game.routines.plans.duplicate(true)
	plans[2][0] = "work"
	game.routines.apply_today(plans)
	game.routines.tick()
	game.select_actor(0)
	game.use_selected_skill()
	checks.chat_started = game.skills.actions.has(0) and game.guard.state == "talking"
	game.select_actor(1)
	checks.switch_preserves_chat_work = game.skills.actions.has(0) and game.routines.is_working(2)
	await touch(0,center+Vector2(40,0),true)
	await walk(6)
	checks.move_preserves_chat_work = game.skills.actions.has(0) and game.routines.is_working(2)
	await touch(0,center,false)
	game.select_actor(0)
	await touch(0,center+Vector2(40,0),true)
	checks.move_cancels_only_current_skill = not game.skills.actions.has(0) and game.routines.is_working(2)
	await touch(0,center,false)
	fresh()
	# Near a locked door: independent right-finger press starts real lockpicking.
	game.gate_watch.guards[0].escaped = true
	game.gate_watch.guards[1].escaped = true
	game.gate_watch.guards[0].state = "talking"
	game.gate_watch.guards[1].state = "talking"
	game.world.set_gate_guarded(false)
	game.actors[1].position = game.world.door.get_center()+Vector2(-40,0)
	game.select_actor(1)
	game.presentation.tick(0)
	game._update_ui()
	checks.context_lockpick = ui.action_button.text == "撬锁" and not ui.action_button.disabled
	await touch(0,center,true)
	await tap(ui.action_button,1)
	checks.right_finger_lockpick = game.skills.actions.has(1) and game.actors[1].action_state == "lockpicking"
	checks.action_releases_stick = controls.direction == Vector2.ZERO
	await touch(0,center,false)
	game.select_actor(2)
	checks.switch_preserves_lockpick = game.skills.actions.has(1)
	game.select_actor(1)
	await tap(ui.ability_button)
	checks.ability_stops_skill = not game.skills.actions.has(1)
	# Item fixture supplies two real nearby targets to verify selection + pickup.
	fresh()
	game.select_actor(0)
	var ground: Array = game.inventory.instances.values().filter(func(i): return i.location == "ground")
	var item = ground[0]
	var other = ground[1]
	item.position = [365,280]
	other.position = [350,310]
	game.presentation.tick(0)
	game._update_ui()
	checks.pickup_context = ui.action_button.text == "拾取" and not ui.action_button.disabled
	checks.multiple_target_button = ui.target_button.visible and game.presentation.interaction.mobile_target_count() >= 2
	var target_before: String = game.presentation.interaction.mobile_target_key
	await tap(ui.target_button)
	checks.target_switch_works = target_before != game.presentation.interaction.mobile_target_key
	await tap(ui.action_button)
	checks.context_pickup_real_inventory = game.inventory.items(0).size() == 1
	await tap(ui.bag_button)
	checks.bag_opens_actual_slots = ui.bag_open and ui.inventory_paper.visible and game.inventory_panel.slots[0].visible
	await touch(0,center+Vector2(40,0),true)
	old = game.actors[0].position
	await walk(6)
	checks.bag_blocks_movement = game.actors[0].position == old
	await touch(0,center,false)
	await shot("bag")
	await tap(ui.bag_button)
	checks.bag_closes = not ui.bag_open and not ui.inventory_paper.visible
	# Reuse the real merchant shop with a declared arrival/time/wallet fixture.
	fresh()
	game.schedule.clock_elapsed = (720-480)/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	var merchant_id: String = game.trade.actors.keys()[0]
	var merchant = game.trade.actors[merchant_id]
	merchant.update_schedule()
	merchant.position = merchant.goal
	game.trade.tick(0)
	game.actors[0].position = merchant.position+Vector2(0,40)
	game.inventory.wallet = 30
	game.presentation.tick(0)
	game._update_ui()
	for index in range(game.presentation.interaction.mobile_target_count()):
		if ui.action_button.text == "购买":
			break
		await tap(ui.target_button)
	checks.merchant_context = ui.action_button.text == "购买"
	if not checks.merchant_context:
		print("P46_SHOP_DEBUG reason=",game.trade.reason(0,merchant_id)," merchant=",merchant.position," actor=",game.actors[0].position," goal=",merchant.goal," clock=",game.schedule.clock_minutes()," targets=",game.presentation.interaction._mobile_targets," label=",ui.action_button.text)
	await tap(ui.action_button)
	checks.shop_opens_real_bag = game.shop_panel.panel.visible and ui.inventory_paper.visible and not pad.visible
	checks.shop_bag_outside_panel = not ui.inventory_paper.get_global_rect().intersects(game.shop_panel.panel.get_global_rect())
	await tap(game.shop_panel.buy)
	checks.native_purchase = game.inventory.items(0).size() == 1 and game.inventory.wallet < 30
	await shot("shop")
	game.shop_panel.close()
	game.select_actor(2)
	await tap(ui.bag_button)
	checks.expanded_backpack_three_slots = ui.inventory_paper.visible and game.inventory_panel.slots.all(func(s): return s.visible) and game.inventory.capacity(2) == 3
	await shot("three-slots")
	await tap(ui.bag_button)
	fresh()
	await touch(0,center+Vector2(40,0),true)
	await tap(ui.menu_button,1)
	checks.second_finger_pause = paused and ui.menu.visible and controls.direction == Vector2.ZERO
	old = game.actors[0].position
	await walk(6)
	checks.paused_motion_stopped = game.actors[0].position == old
	ui.close_menu()
	await drag(0,center+Vector2(100,0))
	await walk(6)
	checks.resume_needs_new_touch = game.actors[0].position == old
	await touch(0,center,false)
	await touch(0,center+Vector2(40,0),true)
	game.routine_panel.open()
	checks.planner_clears_touch = paused and controls.direction == Vector2.ZERO and not pad.visible
	game.routine_panel.close()
	await touch(0,center,false)
	# Desktop test controls are equivalent directions; no camera arrow scrolling.
	fresh()
	old = game.actors[0].position
	await key(KEY_D,true)
	await walk(8)
	checks.keyboard_moves = game.actors[0].position.x > old.x+20
	await key(KEY_D,false)
	old = game.actors[0].position
	await walk(6)
	checks.keyboard_release = game.actors[0].position == old
	await key(KEY_LEFT,true)
	await walk(5)
	checks.arrows_drive_person = game.actors[0].position.x < old.x
	game.get_window().focus_exited.emit()
	checks.focus_loss_clears = controls.direction == Vector2.ZERO and controls.keys.is_empty()
	await key(KEY_LEFT,false)
	await touch(0,center+Vector2(40,0),true)
	game.capture_actor(0)
	checks.capture_clears = controls.direction == Vector2.ZERO and game.actors[0].position == game.actors[0].home
	await touch(0,center,false)
	await touch(0,center+Vector2(40,0),true)
	game.reset_round(["chat","lockpick","backpack"],46)
	game.routine_panel.close()
	checks.reset_clears = controls.direction == Vector2.ZERO and not ui.bag_open
	await touch(0,center,false)
	await touch(1,ui.bag_button.get_global_rect().get_center(),true)
	game.reset_round(["chat","lockpick","backpack"],46)
	game.routine_panel.close()
	await touch(1,ui.bag_button.get_global_rect().get_center(),false)
	checks.reset_cancels_pending_button = not ui.bag_open
	# Main-map short tap must not leave a destination order.
	var point := Vector2(width*0.6,300)
	await touch(0,point,true)
	await touch(0,point,false)
	checks.world_tap_no_destination = game.orders.active.is_empty()
	if native:
		root.grab_focus()
		await frame()
		var before_pan: Vector2 = game.map_camera.position
		await touch(0,Vector2(550,300),true)
		await drag(0,Vector2(460,250))
		await touch(0,Vector2(460,250),false)
		checks.main_drag_pans = game.map_camera.position.distance_to(before_pan) > 30 and not game.map_camera.following
		var map_point: Vector2 = game.mini_map.global_position+game.mini_map.to_map(Vector2(1900,1400))
		await touch(0,map_point,true)
		await touch(0,map_point,false)
		checks.minimap_navigation = not game.map_camera.following and game.map_camera.position.x > before_pan.x+100
		if not checks.minimap_navigation:
			print("MINIMAP_DIAGNOSTIC focus=",root.has_focus()," point=",map_point," before=",before_pan," after=",game.map_camera.position," blocked=",game.mini_map.blocked())
		await tap(game.mini_map.locate_button)
		checks.locate_restores_follow = game.map_camera.following
	fresh(["strong","lockpick","backpack"])
	var crate: Rect2 = game.world.crate
	game.actors[0].position = Vector2(crate.position.x-18,crate.get_center().y)
	var crate_before: Vector2 = crate.position
	await touch(0,center+Vector2(40,0),true)
	await walk(30)
	checks.direct_strong_pushes = game.world.crate.position.x > crate_before.x+8
	await touch(0,center,false)
	fresh()
	game.actors[0].position = game.world.exit_area.get_center()-Vector2(60,0)
	game.map_camera.locate_selected()
	await touch(0,center+Vector2(40,0),true)
	await walk(30)
	checks.direct_exit = game.actors[0].escaped and game.selected_actor_id != 0 and controls.direction == Vector2.ZERO
	fresh()
	game.phase = "failed"
	game._update_ui()
	checks.end_hides_controls = not pad.visible and not ui.action_button.visible
	fresh()
	await shot("final")
	var passed: bool = checks.values().all(func(x): return x)
	var report := {"passed":passed,"checks":checks,"native":native,"width":width,"scope":"Input.parse_input_event real touch/key routing, two simultaneous fingers, real collision/push/exit, existing skill/routine coexistence and modal lifecycle. Nearby door/item/push/exit fixtures use explicit positions; no phone hardware or human playtest claim."}
	FileAccess.open("res://docs/tests/p50-mobile-regression-"+("native" if native else "headless")+"-%d.json" % width,FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("P50_MOBILE_REGRESSION passed=",passed," count=",checks.size()," failed=",checks.keys().filter(func(k): return not checks[k]))
	game.presentation.stop_all()
	game.queue_free()
	await frame()
	quit(0 if passed else 1)
