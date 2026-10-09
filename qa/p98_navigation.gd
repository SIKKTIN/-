extends SceneTree

var game
var checks := {}
var guide
var tutorial
func _initialize(): call_deferred("run")
func check(key: String, ok: bool):
	checks[key] = ok
	print(key+": "+str(ok))
func frame():
	await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
func route_clear() -> bool:
	var point: Vector2 = game.actors[0].position
	for next in guide.route:
		if not game.world.motion_clear(point,next,game.actors[0],false): return false
		point = next
	return not guide.route.is_empty()
func show_step(id: String):
	tutorial._enter(id)
	tutorial._refresh()
	guide.update_route(1)
func approach(point: Vector2):
	for offset in [Vector2(70,0),Vector2(-70,0),Vector2(0,70),Vector2(0,-70)]:
		var candidate: Vector2 = point+offset
		if game.world.can_place_circle(candidate,8,game.actors[0],false) and game.world.line_clear(candidate,point):
			game.actors[0].position = candidate
			return
func shot(label: String):
	if DisplayServer.get_name()=="headless": return
	game.room_visibility.tick(1,true)
	game.map_camera.locate_selected()
	game.presentation.tick(0)
	tutorial._refresh()
	game.fullscreen_ui.refresh()
	guide.update_route(0.06)
	game.fullscreen_ui.fps_badge.hide()
	await frame()
	root.get_texture().get_image().save_png("res://docs/tests/p98-"+label+".png")
func click(point: Vector2):
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

func benchmark():
	if DisplayServer.get_name()=="headless": return
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	await frame()
	game.fullscreen_ui.layout()
	tutorial._clock(480)
	game.actors[0].position = tutorial._target("station")+Vector2(220,90)
	game.orders.stop(0)
	show_step("work_practice")
	game.room_visibility.tick(1,true)
	game.map_camera.locate_selected()
	game.presentation.tick(0)
	game.set_process(true)
	game.fullscreen_ui.set_process(true)
	var performance := {}
	for enabled in [false,true]:
		guide.set_process(enabled)
		if not enabled: guide.hide()
		var samples: Array = []
		var cpu: Array = []
		var last := Time.get_ticks_usec()
		var plans: int = guide.plan_count
		for i in range(150):
			await process_frame
			var now := Time.get_ticks_usec()
			if i>=30:
				samples.append(float(now-last)/1000)
				cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
			last = now
		samples.sort()
		cpu.sort()
		performance["enabled" if enabled else "disabled"] = {"fps":Performance.get_monitor(Performance.TIME_FPS),"p99_ms":samples[118],"max_ms":samples.back(),"cpu_p99_ms":cpu[118],"cpu_max_ms":cpu.back(),"visible":guide.visible,"additional_searches":guide.plan_count-plans}
	check("performance_sample_has_real_navigation",guide.visible and tutorial.step_id=="work_practice")
	await frame()
	root.get_texture().get_image().save_png("res://docs/tests/p98-live-navigation.png")
	FileAccess.open("res://docs/tests/p98-navigation-performance.json",FileAccess.WRITE).store_string(JSON.stringify(performance,"\t"))
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	guide.set_process(false)
	print("PERFORMANCE ",JSON.stringify(performance))
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","on")
	OS.set_environment("ESCAPE_FRAME_SETTINGS_PATH","user://p98-qa.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://p98-layout.cfg")
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	tutorial = game.tutorial
	tutorial.set_process(false)
	guide = tutorial.marker
	guide.set_process(false)
	tutorial._clock(720)
	game.orders.clear()
	var goal: Vector2 = tutorial._target("station")
	var origin := Vector2.ZERO
	for offset in [Vector2(360,240),Vector2(320,160),Vector2(300,0),Vector2(100,300),Vector2(600,200)]:
		var point: Vector2 = goal+offset
		if not game.world.can_place_circle(point,8,game.actors[0],false): continue
		var path: PackedVector2Array = game.world.find_path(point,goal,game.actors[0],false)
		if path.size()>1:
			origin = point
			break
	check("fixture_requires_a_turn_around_furniture",origin!=Vector2.ZERO)
	game.actors[0].position = origin
	game.room_visibility.tick(1,true)
	show_step("work_practice")
	check("navigation_replaces_destination_circle",guide.name=="TutorialNavigation" and guide.position==Vector2.ZERO and guide.visible and guide.route.size()>1)
	check("every_route_segment_is_walkable",route_clear())
	check("route_reaches_work_station",guide.route[-1].distance_to(goal)<0.01)
	check("route_below_people_and_props",guide.z_index==13)
	var plans: int = guide.plan_count
	for i in range(300): guide.update_route(1.0/60)
	check("stationary_five_seconds_does_not_repath",guide.plan_count==plans)
	for dims in [Vector2i(1200,720),Vector2i(960,540)]:
		root.size = dims
		root.content_scale_size = dims
		await frame()
		game.fullscreen_ui.layout()
		tutorial._refresh()
		check("guide_button_fits_"+str(dims.x),tutorial.primary.text=="引导" and game.fullscreen_ui.safe_area().encloses(tutorial.panel.get_rect()) and tutorial.panel.get_rect().encloses(Rect2(tutorial.panel.position+tutorial.primary.position,tutorial.primary.size)))
		await shot("station-navigation-"+str(dims.x))
	if DisplayServer.get_name()!="headless":
		var feet: Vector2 = game.actors[0].position
		game.map_camera.manual_pan_by(Vector2(180,0))
		await click(tutorial.primary.get_global_rect().get_center())
		check("guide_button_follows_player_without_moving_them",game.map_camera.following and game.actors[0].position==feet and not game.orders.active.has(0))
		guide.update_route(0)
	game.fullscreen_ui.toggle_menu()
	guide.update_route(0)
	check("pause_hides_navigation",paused and not guide.visible and not guide.enabled)
	game.fullscreen_ui.close_menu()
	guide.update_route(0)
	check("resume_restores_navigation",not paused and guide.visible)
	game.actors[0].position = guide.route[0]
	guide.update_route(1)
	check("movement_trims_or_replans_safe_route",route_clear() and guide.plan_count<=plans+3)
	game.actors[0].position = goal
	guide.update_route(1)
	check("arrival_hides_line",not guide.visible and guide.arrived)
	game.actors[0].position = origin
	guide.update_route(1)
	check("leaving_target_restores_line",guide.visible and route_clear())
	var previous: int = guide.plan_count
	var door = game.world.access_by_id("workshop-entry")
	game.world.set_access_closed("workshop-entry",not door.closed)
	guide.update_route(0)
	check("door_revision_invalidates_cache",guide.plan_count==previous+1 and guide.planned_revision==game.world.obstacle_revision)
	game.world.set_access_closed("workshop-entry",false)
	game.world.set_access_closed("workshop-entry-east",false)
	game.actors[1].position = goal
	show_step("chat_practice")
	previous = guide.plan_count
	game.actors[1].position += Vector2(32,0)
	tutorial._refresh()
	guide.update_route(1)
	check("moving_npc_updates_destination",guide.plan_count==previous+1 and guide.planned_target==game.actors[1].position and route_clear())
	approach(game.actors[1].position)
	game.room_visibility.tick(1,true)
	game.presentation.tick(0)
	check("npc_conversation_opens",game.dialogue.open("prisoner:1"))
	guide.update_route(0)
	check("conversation_hides_line",not guide.visible and not guide.enabled)
	game.dialogue.close()
	show_step("meal_practice")
	game.routines.records[0] = {"kind":"meal","meal_stage":"dine","goal":Vector2(1028.59,1786.8)}
	tutorial._refresh()
	check("meal_guides_to_table_after_pickup",guide.target==Vector2(1028.59,1786.8))
	game.routines.records.erase(0)
	game.actors[0].position = tutorial._target("work_gate")
	game.world.set_access_closed("workshop-entry",true)
	game.world.set_access_closed("workshop-entry-east",true)
	show_step("enter_work")
	check("closed_room_never_draws_through_locked_doors",guide.route.is_empty() and not guide.visible)
	previous = guide.plan_count
	for i in range(300): guide.update_route(1.0/60)
	check("blocked_stationary_route_does_not_repeat_searches",guide.plan_count==previous)
	game.world.set_access_closed("workshop-entry",false)
	guide.update_route(0)
	check("opening_door_restores_safe_route",guide.visible and route_clear())
	tutorial._enter("work_brief")
	guide.update_route(0)
	check("lecture_hides_navigation",not guide.enabled and not guide.visible)
	await benchmark()
	game.reset_round()
	check("reset_clears_old_route",guide.route.is_empty() and not guide.visible and not guide.enabled)
	var failed: Array = checks.keys().filter(func(k):return not checks[k])
	var tag := "headless" if DisplayServer.get_name()=="headless" else "native"
	var report := {"checks":checks,"failed":failed,"total":checks.size(),"path_searches":guide.plan_count,"max_search_ms":guide.max_plan_usec/1000.0}
	FileAccess.open("res://docs/tests/p98-navigation-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failed.is_empty() else 1)
