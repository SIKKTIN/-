extends SceneTree

var game
var checks := {}
var trace: Array = []
var max_player_move := 0.0
var max_guide_move := 0.0
var ticks := 0
var chat_started := false
var last_step := ""
var order_retry := 0.0
var saw_work_wage := false
var saw_warning := false
var saw_recovery := false
var saw_meal_twenty := false
var saw_gate_closed := false
var layout_checks := {}
var stages_seen := {}
var lecture_motion_clear := true

func _initialize(): call_deferred("run")
func check(label: String, ok: bool):
	checks[label] = ok
	print(label+": "+str(ok))

func go_near(point: Vector2, radius := 0.0):
	if order_retry>0: return
	var candidates: Array[Vector2] = [point]
	if radius>0:
		candidates = [point+Vector2(radius,0),point+Vector2(0,radius),point+Vector2(-radius,0),point+Vector2(0,-radius),point+Vector2(radius,radius)]
	for goal in candidates:
		if game.world.can_place_circle(goal,8,game.actors[0],true) and game.world.line_clear(goal,point):
			if game.orders.issue(0,goal,"manual"):
				order_retry = 0.75
				return

func screenshot(label: String):
	if DisplayServer.get_name()=="headless": return
	game.presentation.tick(0)
	game.fullscreen_ui.refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/tests/p102-"+label+".png")

func check_stage():
	var tutorial = game.tutorial
	lecture_motion_clear = lecture_motion_clear and (game.actors+game.guard.warning_officers()+game.trade.actors.values()).all(func(actor): return not actor.moved_this_frame)
	var original_line: int = tutorial.line_index
	var original_reveal: float = tutorial.text_revealed
	for size in [Vector2i(1200,720),Vector2i(960,540)]:
		root.size = size
		root.content_scale_size = size
		await process_frame
		game.fullscreen_ui.layout()
		tutorial.layout()
		for i in range(70): tutorial._conversation_focus(0.05)
		for line in range(tutorial.lines.size()):
			tutorial.line_index = line
			tutorial.text_revealed = 999
			tutorial._refresh()
			await process_frame
			var speech = tutorial.speech
			var rectangle: Rect2 = speech.bubble.get_rect()
			var transform: Transform2D = game.get_global_transform_with_canvas()
			var host: Vector2 = transform*tutorial.presenter().position
			var player: Vector2 = transform*game.actors[0].position
			var actors_clear: bool = [host,player].all(func(p):return not rectangle.intersects(Rect2(p-Vector2(22,64),Vector2(44,64))) and p.y<tutorial.panel.position.y+1 and p.x>22 and p.x<size.x-22)
			var text_fits: bool = speech.words.get_minimum_size().y<=speech.words.size.y+1
			var panel_fits: bool = tutorial.primary.get_rect().end.y<=tutorial.panel.size.y and tutorial.body.get_rect().end.y<=tutorial.note.position.y
			var fits: bool = not tutorial.panel.visible and not tutorial.primary.visible and speech.bubble.mouse_filter==Control.MOUSE_FILTER_STOP and speech.visible and rectangle.position.x>=0 and rectangle.position.y>=0 and rectangle.end.x<size.x and rectangle.end.y<tutorial.panel.position.y and actors_clear and text_fits and panel_fits
			layout_checks["%s_%d_line%d" % [tutorial.step_id,size.x,line+1]] = fits
			if not fits: print("LAYOUT FAIL ",tutorial.step_id," size=",size," rect=",rectangle," host=",host," player=",player," actor_clear=",actors_clear," text_fits=",text_fits)
			if line==0 and tutorial.step_id in ["welcome","warning_brief","chat_brief","tools_brief"]:
				game.presentation.tick(0)
				await screenshot(tutorial.step_id+"-"+str(size.x))
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	await process_frame
	game.fullscreen_ui.layout()
	tutorial.line_index = original_line
	tutorial.text_revealed = original_reveal
	tutorial._refresh()

func drive():
	var tutorial = game.tutorial
	if tutorial.step_id != last_step:
		print("STEP "+tutorial.step_id+" player="+str(game.actors[0].position)+" guide="+str(game.guard.position))
		trace.append({"step":tutorial.step_id,"player":str(game.actors[0].position),"guide":str(game.guard.position),"minute":game.schedule.absolute_minutes()})
		last_step = tutorial.step_id
		order_retry = 0
	if tutorial.transition: return
	if tutorial.speaking():
		tutorial.speech.bubble.pressed.emit()
		return
	match tutorial.step_id:
		"follow_work","enter_work","return_work","cell_tour","return_bed":
			go_near(tutorial._target(str(tutorial.step().target)))
		"work_practice","afternoon_work":
			if game.actors[0].position.distance_to(game.routines._target(0,"work"))>75:
				go_near(game.routines._target(0,"work"))
			elif not game.routines.is_working(0): game.workshop.start_work(0)
		"warning_practice":
			if game.workshop.warning_level(0)>=1.2 or tutorial.warning_seen and game.workshop.warning_level(0)<1.2 and tutorial.age>1.2:
				if not game.routines.is_working(0): game.workshop.start_work(0)
		"meal_practice":
			if game.routines.meal_reason(0).is_empty(): game.routines.start_meal(0)
			elif not game.routines.carries_meal(0) and not game.routines.records.has(0): go_near(game.routines._target(0,"meal"))
		"chat_practice":
			if game.dialogue.panel.visible:
				game.dialogue.rules()
				game.dialogue.close()
			elif not tutorial.chat_seen:
				if game.dialogue.reason("prisoner:1").is_empty(): game.dialogue.open("prisoner:1")
				else: go_near(game.actors[1].position,70)
		"merchant_practice": go_near(tutorial._target("merchant"),70)

func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","on")
	OS.set_environment("ESCAPE_FRAME_SETTINGS_PATH","user://p102-qa.cfg")
	root.size = Vector2i(1200,720)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.tutorial.set_process(false)
	check("tutorial_default_first_day",game.tutorial.active and game.tutorial.step_id=="welcome" and game.schedule.day_number()==1)
	check("formal_deadline_not_started",game.schedule.remaining()==game.schedule.limit_seconds and is_inf(game.schedule.real_remaining()))
	check("welcome_blocks_world_input",game.world_input_blocked() and not paused)
	check("no_dialogue_before_presenter_arrives",not game.tutorial.dialogue_ready and not game.tutorial.speech.visible and game.tutorial.primary.disabled)
	var time = game.schedule.clock_elapsed
	for i in range(50): game._process(0.1)
	check("lecture_holds_clock",game.schedule.clock_elapsed==time)
	for i in range(3): game.capture_actor(0)
	check("tutorial_capture_not_failure_or_teleport",game.confinement_counts[0]==0 and game.captures==0 and game.phase=="playing" and not game.actors[0].confined)
	await screenshot("welcome-1200")
	var screenshots := {}
	for i in range(7000):
		ticks = i
		if not game.tutorial.active and not game.tutorial.transition: break
		drive()
		var player_before: Vector2 = game.actors[0].position
		var guard_before: Vector2 = game.guard.position
		var resetting: bool = game.tutorial.transition
		game.tutorial._process(0.05)
		game._process(0.05)
		if game.tutorial.active and game.tutorial.speaking() and not stages_seen.has(game.tutorial.step_id):
			stages_seen[game.tutorial.step_id] = true
			await check_stage()
		if not resetting:
			max_player_move = maxf(max_player_move,player_before.distance_to(game.actors[0].position))
			max_guide_move = maxf(max_guide_move,guard_before.distance_to(game.guard.position))
		order_retry -= 0.05
		var id: String = game.tutorial.step_id
		saw_work_wage = saw_work_wage or game.routines.work_rounds[0]>0
		saw_warning = saw_warning or (id=="warning_practice" and game.workshop.warning_level(0)>1)
		saw_recovery = saw_recovery or (id=="warning_practice" and game.workshop.warning_recovering(0))
		saw_meal_twenty = saw_meal_twenty or float(game.routines.meal_minutes[0])>=20-0.00001
		if id=="work_practice": saw_gate_closed = saw_gate_closed or game.world.access_by_id("workshop-entry").closed
		if game.tutorial.age>120 and not game.tutorial.speaking():
			print("STALLED "+id+" guard_path="+str(game.guard.path)+" goal="+str(game.guard.path_goal))
			for offset in [Vector2(82,0),Vector2(-82,0),Vector2(0,82),Vector2(0,-82),Vector2(65,65),Vector2(-65,65)]:
				var candidate: Vector2 = game.actors[0].position+offset
				print("RENDEZVOUS ",candidate," place=",game.world.can_place_circle(candidate,8,game.guard,true)," route=",game.world.find_path(game.guard.position,candidate,game.guard,true)," sight=",game.world.line_clear(candidate,game.actors[0].position))
			break
		if id in ["follow_work","warning_practice","meal_practice","inspection"] and not screenshots.has(id):
			screenshots[id] = true
			await screenshot(id+"-1200")
		if i%1000==0: print("PROGRESS "+str(i)+" "+id+" "+str(game.actors[0].position)+" goal="+str(game.tutorial.guide_goal)+" guide="+str(game.guard.position))
	check("full_day_completes",game.tutorial.completed and not game.tutorial.active and not game.tutorial.transition)
	check("all_six_chapters_played",game.tutorial.events.size()==game.tutorial.steps.size())
	var full_events: Array = game.tutorial.events.duplicate(true)
	var full_conversations: Array = game.tutorial.conversations.duplicate(true)
	check("all_fifteen_lectures_have_real_presenter",full_conversations.size()==15)
	check("every_presenter_near_and_in_sight",full_conversations.all(func(c): return c.distance<145 and c.line_clear))
	check("three_real_roles_present",full_conversations.any(func(c): return c.step=="welcome") and full_conversations.any(func(c):return c.step=="warning_brief") and full_conversations.any(func(c):return c.step=="tools_brief"))
	check("every_dialogue_page_fits_both_sizes",layout_checks.values().all(func(ok):return ok) and layout_checks.size()>80)
	check("no_walking_in_place_while_listening",lecture_motion_clear)
	check("actual_work_paid_wage",saw_work_wage)
	check("real_warning_and_recovery_exercised",saw_warning and saw_recovery)
	check("actual_meal_twenty_minutes",saw_meal_twenty)
	check("eight_oclock_gate_really_closed",saw_gate_closed)
	check("guide_really_walked",max_guide_move<=5.01 and max_guide_move>0)
	check("player_never_teleported_between_lessons",max_player_move<=13.01 and max_player_move>0)
	check("formal_calendar_day_two",game.schedule.day_number()==2 and game.schedule.clock_minutes()>=440 and game.schedule.clock_minutes()<=440.25)
	check("full_three_days_remain",game.schedule.remaining()>=899.949 and game.schedule.remaining()<=900)
	check("tutorial_penalties_and_alert_cleared",game.captures==0 and game.confinement_counts[0]==0 and not game.prison_alert.active and game.workshop.warnings.is_empty())
	check("tutorial_wallet_cleared",game.inventory.wallet==0)
	check("formal_morning_starts_without_planner",not game.routine_panel.panel.visible and not paused)
	check("overlay_and_marker_hidden",not game.tutorial.panel.visible and not game.tutorial.marker.visible and not game.tutorial.transition_cover.visible)
	game.routine_panel.close()
	var formal_clock: float = game.schedule.clock_elapsed
	game._process(0.1)
	check("formal_clock_runs",game.schedule.clock_elapsed>formal_clock)
	game.tutorial.replay()
	check("replay_restarts_intake",game.tutorial.active and game.tutorial.step_id=="welcome" and game.schedule.day_number()==1)
	game.tutorial.finish()
	for i in range(25): game.tutorial._process(0.05)
	check("skip_starts_clean_formal_day",not game.tutorial.active and game.schedule.day_number()==2 and game.schedule.remaining()==900)
	game.routine_panel.close()
	for i in range(3):
		if game.actors[0].confined: game.room_access.release(0)
		game.capture_actor(0)
	check("formal_third_confinement_still_fails",game.phase=="failed" and game.confinement_counts[0]==3)
	var failed = checks.keys().filter(func(k):return not checks[k])
	var tag := "headless" if DisplayServer.get_name()=="headless" else "native"
	var report := {"checks":checks,"failed":failed,"trace":trace,"events":full_events,"ticks":ticks,"max_player_move":max_player_move,"max_guide_move":max_guide_move,"conversations":full_conversations,"tutorial":game.tutorial.snapshot()}
	report["layout_checks"] = layout_checks
	FileAccess.open("res://docs/tests/p102-tutorial-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify({"checks":checks,"failed":failed,"ticks":ticks,"max_player_move":max_player_move,"max_guide_move":max_guide_move}))
	quit(0 if failed.is_empty() else 1)
