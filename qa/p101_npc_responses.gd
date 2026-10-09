extends SceneTree

var game
var checks := {}

func _initialize(): call_deferred("run")
func check(key: String, ok: bool):
	checks[key] = ok
	print(key+": "+str(ok))
func frame():
	await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
func click(point: Vector2, touch := false):
	if DisplayServer.get_name()=="headless": return
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
func clock(minute: float):
	game.schedule.clock_elapsed = (minute-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.workshop.update_gate()
	game.routines.tick()
func reset(skill := "strong", minute := 600):
	game.reset_round([skill,"chat","backpack"],72)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	clock(minute)
	game.orders.clear()
	for actor in game.actors: actor.position = game.routines._target(actor.actor_id,"work")
	game.workshop.tick(0)
	game.room_visibility.tick(1)
func approach(target: Dictionary) -> bool:
	for offset in [Vector2(70,0),Vector2(-70,0),Vector2(0,70),Vector2(0,-70),Vector2(50,50),Vector2(-50,-50)]:
		var point: Vector2 = target.node.position+offset
		if game.world.can_place_circle(point,8,game.actors[0],true) and game.world.line_clear(point,target.node.position):
			game.actors[0].position = point
			game.map_camera.center_on((point+target.node.position)/2)
			game.room_visibility.tick(1)
			game.presentation.tick(0)
			return true
	return false
func fits() -> bool:
	var talk = game.dialogue
	var rect: Rect2 = talk.panel.get_global_rect()
	var transform: Transform2D = game.get_global_transform_with_canvas()
	var bodies := [game.actors[0],talk.current_target.node]
	var choices: Rect2 = talk.responses.get_global_rect()
	var player_rect := Rect2(transform*game.actors[0].position-Vector2(22,64),Vector2(44,64))
	var tail_clear := true
	if talk.panel.tail.size()==3:
		var edge: Vector2 = talk.panel.position+(talk.panel.tail[0]+talk.panel.tail[1])/2
		var mouth: Vector2 = talk.panel.position+talk.panel.tail[2]
		var corners := [player_rect.position,Vector2(player_rect.end.x,player_rect.position.y),player_rect.end,Vector2(player_rect.position.x,player_rect.end.y)]
		tail_clear = not range(4).any(func(i):return Geometry2D.segment_intersects_segment(edge,mouth,corners[i],corners[(i+1)%4])!=null)
	return tail_clear and game.fullscreen_ui.safe_area().encloses(rect) and game.fullscreen_ui.safe_area().encloses(choices) and not rect.intersects(choices) and not rect.intersects(game.cards[0].get_global_rect()) and bodies.all(func(a): return not rect.intersects(Rect2(transform*a.position-Vector2(22,64),Vector2(44,64))) and not choices.intersects(Rect2(transform*a.position-Vector2(22,64),Vector2(44,64)))) and talk.body.get_minimum_size().y<=talk.body.size.y+1 and talk.body.get_rect().end.y<=talk.panel.size.y-14 and Rect2(Vector2.ZERO,talk.panel.size).encloses(talk.end_button.get_rect()) and [talk.casual_button,talk.rules_button,talk.special_button].all(func(b):return b.get_parent()==talk.responses and Rect2(Vector2.ZERO,talk.responses.size).encloses(b.get_rect()) and b.get_minimum_size().y<=b.size.y+1 and (not b.requirement.visible or Rect2(Vector2.ZERO,b.size).encloses(b.requirement.get_rect())))
func shot(label: String):
	if DisplayServer.get_name()=="headless": return
	game.fullscreen_ui.fps_badge.hide()
	await frame()
	root.get_texture().get_image().save_png("res://docs/tests/p101-"+label+".png")
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_FRAME_SETTINGS_PATH","user://p101-input.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://p101-input-layout.cfg")
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	reset()
	var talk = game.dialogue
	var roles := {}
	for target in talk.targets():
		var opened: bool = approach(target) and talk.open(str(target.id))
		check("opens_"+str(target.id),opened and talk.speaker.text==target.name)
		if not opened: continue
		roles[target.role] = true
		await frame()
		for dims in [Vector2i(1200,720),Vector2i(960,540)]:
			root.size = dims
			root.content_scale_size = dims
			await frame()
			game.fullscreen_ui.layout()
			game.map_camera.center_on((game.actors[0].position+target.node.position)/2)
			game.presentation.tick(0)
			for text in talk.config.roles[target.role].greeting+[talk.config.roles[target.role].rules]:
				talk.body.text = text
				talk.layout()
				await frame()
				check("fits_"+str(target.id)+"_"+str(dims.x)+"_"+str(text.hash()),fits())
			if target.role in ["prisoner","patrol","merchant"]:
				talk.body.text = str(talk.config.roles[target.role].greeting[0])
				talk.layout()
				await shot(str(target.role)+"-"+str(dims.x))
		talk.close()
		check("close_hides_both_"+str(target.id),not talk.panel.visible and not talk.responses.visible)
	check("all_five_regular_roles",roles.size()==5)
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	await frame()
	game.fullscreen_ui.layout()
	reset()
	var target: Dictionary = talk.find_target("prisoner:1")
	approach(target)
	talk.open(str(target.id))
	await frame()
	var index: int = talk.line_index
	var foot: Vector2 = game.actors[0].position
	if DisplayServer.get_name()!="headless":
		await click(talk.casual_button.get_global_rect().get_center())
		check("mouse_selects_one_line",talk.line_index==index+1)
		await click(talk.rules_button.get_global_rect().get_center(),true)
		check("touch_selects_rules_once",talk.body.text==talk.config.roles.prisoner.rules and talk.line_index==index+1)
		await click(talk.special_button.get_global_rect().get_center())
		check("nearby_prisoner_option",not talk.body.text.is_empty() and talk.panel.visible)
		await click(talk.body.get_global_rect().get_center())
		check("bubble_backdrop_consumes_input",game.actors[0].position==foot and not game.orders.active.has(0) and talk.line_index==index+1)
	var before: float = game.schedule.clock_elapsed
	game.schedule.set_time_speed(1)
	game._process(0.1)
	check("ordinary_chat_clock_continues",game.schedule.clock_elapsed>before and not paused)
	var npc_before: Vector2 = target.node.position
	game.orders.tick(0.2)
	check("prisoner_stays_to_talk",target.node.position==npc_before)
	game.map_camera.manual_pan_by(Vector2(38,12))
	talk.position_speech()
	var mouth: Vector2 = game.get_global_transform_with_canvas()*target.node.position+Vector2(0,-48)
	check("tail_tracks_camera",talk.panel.tail.size()==3 and (talk.panel.tail[2]+talk.panel.position).distance_to(mouth)<0.01)
	var same_key: Array = talk.text_layout_key.duplicate()
	for i in range(30): talk.position_speech()
	check("static_speech_reuses_text_layout",talk.text_layout_key==same_key)
	if DisplayServer.get_name()!="headless":
		await click(talk.end_button.get_global_rect().get_center())
		check("mouse_close_restores_control",not talk.panel.visible and game.actors[0].action_state=="idle")
	else: talk.close()
	talk.open(str(target.id))
	game.actors[0].position = Vector2(1600,1040)
	talk.tick()
	check("distance_closes_speech",not talk.panel.visible)
	reset("strong",1080)
	target = talk.find_target("prisoner:1")
	approach(target)
	talk.open(str(target.id))
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	game.fullscreen_ui._unhandled_input(escape)
	check("escape_closes_speech",not talk.panel.visible)
	target = talk.targets().filter(func(t):return t.role=="merchant")[0]
	target.node.update_schedule()
	approach(target)
	check("merchant_opens",talk.open(str(target.id)))
	talk.special()
	check("purchase_still_opens_shop",game.shop_panel.panel.visible and not talk.panel.visible)
	game.shop_panel.close()
	reset("chat",1080)
	var gate = game.gate_watch.guards[0]
	target = talk.find_target("guard:"+gate.guard_id)
	approach(target)
	talk.open(str(target.id))
	talk.special()
	check("distraction_still_uses_skill",game.skills.chat_guard(game.actors[0])==gate and gate.state=="talking" and not talk.panel.visible)
	game.skills.cancel(0)
	reset()
	game.guard.position = game.world.guard_start
	game.room_visibility.tick(1,true)
	target = {"node":game.guard}
	approach(target)
	game.guard.facing = game.guard.position.direction_to(game.actors[0].position)
	game.actors[0].immune_until = 0
	game.map_camera.center_on(game.actors[0].position)
	game.room_visibility.tick(1)
	game.presentation.tick(0)
	check("guard_ordinary_chat_opens",talk.open("guard:patrol"))
	check("non_chat_skill_cannot_distract",talk.special_button.disabled and game.guard.state!="talking")
	check("locked_response_explains_skill_requirement",talk.special_button.requirement.visible and talk.special_button.requirement.text.contains("会聊天"))
	if DisplayServer.get_name()!="headless":
		var message: String = talk.body.text
		await click(talk.special_button.get_global_rect().get_center(),true)
		check("disabled_response_cannot_trigger_skill",talk.body.text==message and not game.skills.actions.has(0) and talk.panel.visible and talk.responses.visible)
	game.guard.tick(0)
	check("guard_keeps_enforcing",game.guard.state=="chasing" and game.guard.target_id==0)
	game.guard.position = game.guard.position.lerp(game.actors[0].position,0.5)
	game.guard.tick(0)
	check("capture_closes_speech",game.actors[0].confined and not talk.panel.visible)
	var failed: Array = checks.keys().filter(func(k):return not checks[k])
	var tag := "headless" if DisplayServer.get_name()=="headless" else "native"
	FileAccess.open("res://docs/tests/p101-npc-speech-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"total":checks.size()},"\t"))
	print(JSON.stringify({"failed":failed,"total":checks.size()}))
	quit(0 if failed.is_empty() else 1)
