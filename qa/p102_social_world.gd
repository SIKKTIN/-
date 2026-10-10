extends "res://qa/p101_npc_responses.gd"

var social
func _initialize():
	create_timer(60).timeout.connect(func():quit(124))
	call_deferred("run")
func near(id: int):
	game.dialogue.close()
	game.actors[id].position = Vector2(1120,1300)
	game.orders.clear()
	game.room_visibility.tick(1,true)
	approach({"node":game.actors[id]})

func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_FRAME_SETTINGS_PATH","user://p102-test.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://p102-test-layout.cfg")
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	reset("backpack",740)
	social = game.social
	var names := {}
	for p in social.people.values(): names[p.name] = true
	check("every_person_has_unique_named_identity",social.people.size()>=9 and social.people.size()==names.size() and game.actors.all(func(a):return a.has_meta("display_name")))
	check("distinct_personalities_and_relationships",social.people["prisoner:1"].traits.generosity>social.people["prisoner:2"].traits.generosity and social.relation("prisoner:1").like>social.relation("prisoner:2").like)
	near(1)
	game.attributes.values[0].fullness = 35
	game.attributes.values[1].fullness = 85
	var sum_before: float = game.attributes.values[0].fullness+game.attributes.values[1].fullness
	var line: String = social.request_help("prisoner:1")
	if social.people["prisoner:1"].last_decision.is_empty(): quit(1); return
	check("generous_person_gives_actual_food",social.people["prisoner:1"].last_decision.action=="help" and line.contains("口粮") and game.attributes.values[0].fullness==47 and social.people["prisoner:1"].rations==0)
	check("food_has_a_real_donor_cost",is_equal_approx(sum_before,game.attributes.values[0].fullness+game.attributes.values[1].fullness))
	var before: float = game.attributes.values[0].fullness
	for i in range(20): social.request_help("prisoner:1")
	check("repeated_requests_do_not_duplicate_food",game.attributes.values[0].fullness==before and social.people["prisoner:1"].help_count==1)
	var decision: Dictionary = social.people["prisoner:1"].last_decision
	var total := 0.0
	for term in decision.terms.values(): total += float(term)
	check("decision_has_auditable_consequence_and_cost_terms",is_equal_approx(total,decision.score) and decision.candidates.size()==3 and decision.impact.has("body"))
	near(2)
	line = social.request_help("prisoner:2")
	check("cautious_self_interested_person_refuses",social.people["prisoner:2"].last_decision.action=="refuse" and line.contains("帮不了") and game.inventory.wallet==0)
	near(1)
	game.inventory.wallet = 2
	var trust_before: float = social.relation("prisoner:1").trust
	line = social.chat("prisoner:1",true)
	check("repayment_moves_money_and_builds_trust",game.inventory.wallet==0 and social.people["prisoner:1"].money==6 and social.people["prisoner:1"].debt==0 and social.relation("prisoner:1").trust>trust_before and line.contains("信得过"))
	social.chat("prisoner:1",true)
	trust_before = social.relation("prisoner:1").trust
	for i in range(20): social.chat("prisoner:1",true)
	check("chat_cannot_farm_relationships_per_click",social.relation("prisoner:1").trust==trust_before)
	social.now = 31
	line = social.request_help("prisoner:1")
	check("information_is_shared_and_remembered",social.people["prisoner:1"].last_decision.action=="share" and social.knowledge.has("workshop_warning") and social.people["prisoner:1"].memories.any(func(m):return m.kind=="share"))
	social.now = 65
	var wallet_before: int = game.inventory.wallet
	social.request_help("prisoner:1")
	check("repayment_does_not_reopen_daily_resource_reward",game.inventory.wallet==wallet_before and social.people["prisoner:1"].help_count==1)
	var r: Dictionary = social.relation("prisoner:1")
	r.like = -80
	r.trust = 5
	social.now = 100
	line = social.request_help("prisoner:1")
	check("bad_relationship_changes_a_generous_person_to_refusal",social.people["prisoner:1"].last_decision.action=="refuse")
	r.like = 20
	r.trust = 50
	var key := "prisoner:1"
	var item: String = game.inventory.add_ground("scrap",game.actors[0].position)
	check("real_gift_pickup",game.inventory.try_pickup(0,item).ok)
	game.actors[1].position = game.actors[0].position+Vector2(30,0)
	trust_before = r.trust
	check("real_gift_changes_relationship_and_memory",game.inventory.try_transfer(0,1,item).ok and r.trust>trust_before and social.people[key].memories.any(func(m):return m.kind=="gift") and social.chat(key,false).contains("记着"))
	for i in range(30): social.remember(key,"conversation","prisoner:0","闲聊")
	check("bounded_memory_retains_significant_gifts",social.people[key].memories.size()==12 and social.people[key].memories.any(func(m):return m.kind=="gift"))
	var count: int = social.people[key].memories.size()
	clock(1080)
	check("day_schedule_changes_do_not_erase_memory",social.people[key].memories.size()==count)
	near(1)
	game.actors[2].position = game.actors[0].position
	game.actors[0].position = Vector2(750,1300)
	game.orders.clear()
	game.actors[1].action_state = "idle"
	game.actors[2].action_state = "idle"
	social.people[key].cooldowns.erase("peer")
	social.peer_conversation()
	check("npcs_build_relationships_with_each_other",game.actors[1].action_state=="chatting" and social.relation(key,"prisoner:2").like>0 and social.people[key].memories.any(func(m):return m.other=="prisoner:2"))
	social.now += 3
	social.peer_conversation()
	check("peer_conversation_releases_people_after_two_seconds",game.actors[1].action_state=="idle" and game.actors[2].action_state=="idle")
	social.people[key].mood.anger = 80
	game.actors[0].position = Vector2(2400,2400)
	var cycles: int = social.thought_cycles
	for i in range(600): social.tick(1.0/60)
	check("decisions_are_throttled_instead_of_per_frame",social.thought_cycles-cycles>=9 and social.thought_cycles-cycles<=11)
	check("emotions_recover_gradually",social.people[key].mood.anger>0 and social.people[key].mood.anger<80)
	var instant: float = social.now
	paused = true
	social.tick(10)
	paused = false
	check("pause_stops_social_time",social.now==instant)
	game.tutorial.active = true
	social.tick(10)
	game.tutorial.active = false
	check("tutorial_keeps_its_authored_performance",social.now==instant)
	var gate: Dictionary = game.world.access_by_id("maintenance-entry")
	game.world.set_access_closed("maintenance-entry",true)
	var collider: Rect2 = game.world.door_collision_rect(gate.rect)
	var offset := Vector2(0,45) if collider.size.x>collider.size.y else Vector2(45,0)
	game.actors[0].position = collider.get_center()+offset
	game.actors[1].position = collider.get_center()-offset
	check("wall_blocks_perception_and_help",not game.world.line_clear(game.actors[0].position,game.actors[1].position) and not social.accessible(key,125))
	before = game.attributes.values[0].fullness
	social.request_help(key)
	check("inaccessible_requests_have_no_effect",game.attributes.values[0].fullness==before)
	clock(600)
	game.actors[1].position = Vector2(1350,1300)
	near(2)
	game.actors[0].immune_until = 0
	game.guard.position = (game.actors[2].position+game.actors[0].position)/2
	game.guard.state = "patrol"
	game.room_visibility.tick(1,true)
	social.people["prisoner:2"].cooldowns.erase("witness")
	check("report_fixture_is_a_real_visible_violation",game.workshop.outside_violation(0) and social.accessible("prisoner:2",180) and game.world.line_clear(game.actors[2].position,game.guard.position))
	var old_foot: Vector2 = game.actors[0].position
	social.witness("prisoner:2")
	check("witness_reports_to_a_nearby_guard",social.people["prisoner:2"].last_decision.action=="report" and game.guard.state=="searching" and game.guard.last_seen==old_foot)
	check("report_starts_investigation_without_teleport_capture",game.actors[0].position==old_foot and not game.actors[0].confined and game.guard.target_id==-1)
	game.guard.position = Vector2(3000,2400)
	check("guard_cannot_receive_remote_report",not game.guard.receive_tip(game.actors[2],old_foot))
	game.actors[1].position = game.actors[0].position
	game.actors[2].position = Vector2(2000,2400)
	game.room_visibility.tick(1,true)
	count = social.people["prisoner:2"].memories.size()
	game.capture_actor(0)
	check("only_actual_witnesses_remember_capture",social.people[key].memories.any(func(m):return m.kind=="capture") and social.people["prisoner:2"].memories.size()==count and social.people[key].mood.fear>=25)
	reset("backpack",740)
	social = game.social
	near(1)
	game.attributes.values[0].fullness = 30
	game.attributes.values[1].fullness = 85
	social.tick(1)
	check("friend_autonomously_helps_a_nearby_hungry_player",game.attributes.values[0].fullness==42 and social.people[key].last_decision.action=="help" and not game.orders.active.has(0))
	reset("backpack",740)
	social = game.social
	near(1)
	game.attributes.values[0].fullness = 80
	game.inventory.wallet = 0
	social.request_help(key)
	check("loan_transfers_real_money_from_npc",game.inventory.wallet==2 and social.people[key].money==2 and social.people[key].debt==1)
	reset("backpack",740)
	social = game.social
	near(1)
	game.attributes.values[0].fullness = 35
	social.people[key].mood.fear = 95
	social.request_help(key)
	check("fear_can_override_a_generous_persons_help",social.people[key].last_decision.action=="refuse" and game.attributes.values[0].fullness==35)
	reset("backpack",1080)
	social = game.social
	var merchant: Dictionary = game.dialogue.targets().filter(func(t):return t.role=="merchant")[0]
	merchant.node.update_schedule()
	approach(merchant)
	var stock: Array = game.trade.merchants["prison_dealer"].stock
	var offer: String = stock[0]
	var merchant_key := "merchant:prison_dealer"
	trust_before = social.relation(merchant_key).trust
	game.inventory.wallet = 100
	check("successful_purchase_leaves_merchant_memory",game.trade.try_buy(0,"prison_dealer",offer).ok and social.relation(merchant_key).trust==trust_before+3 and social.people[merchant_key].memories.any(func(m):return m.kind=="purchase"))
	trust_before = social.relation(merchant_key).trust
	check("failed_purchase_cannot_farm_merchant_trust",not game.trade.try_buy(0,"prison_dealer",offer).ok and social.relation(merchant_key).trust==trust_before)
	reset("backpack",540)
	social = game.social
	game.inventory.wallet = 0
	var pay_begin: float = game.schedule.clock_elapsed
	var pay_end: float = pay_begin+game.routines.work_duration()/1440.0*game.schedule.day_seconds
	game.routines.accrue_work(pay_begin,pay_end,[1],{1:game.routines.work_duration()})
	var npc_money: int = social.people[key].money
	check("npc_wages_fund_own_help_instead_of_player_wallet",npc_money==4+game.routines.work_wage() and game.inventory.wallet==0)
	game.routines.accrue_work(pay_begin,pay_end,[1],{1:game.routines.work_duration()})
	check("npc_income_consumes_each_work_interval_once",social.people[key].money==npc_money)
	reset("backpack",740)
	social = game.social
	check("round_reset_clears_social_state_and_rebinds_new_people",social.people[key].memories.is_empty() and social.knowledge.is_empty() and social.people[key].money==4 and is_instance_valid(social.people["merchant:prison_dealer"].node))
	near(1)
	game.attributes.values[0].fullness = 40
	game.dialogue.open(key)
	game.fullscreen_ui.refresh()
	game.dialogue.layout()
	await frame()
	check("named_dialogue_exposes_mood_and_relationships",game.dialogue.speaker.text.contains("周大勇") and game.dialogue.social_note.text.contains("好感") and game.dialogue.social_note.visible and game.dialogue.special_button.text.contains("帮我"))
	if DisplayServer.get_name()!="headless":
		await click(game.dialogue.special_button.get_global_rect().get_center(),true)
		check("touch_request_uses_real_decision_and_changes_attributes",game.dialogue.body.text.contains("口粮") and game.attributes.values[0].fullness==52)
		for dims in [Vector2i(1200,720),Vector2i(960,540)]:
			root.size = dims
			root.content_scale_size = dims
			await frame()
			game.fullscreen_ui.layout()
			game.fullscreen_ui.refresh()
			game.map_camera.center_on(Vector2(1155,1300))
			game.dialogue.layout()
			await frame()
			check("social_dialogue_fits_"+str(dims.x),fits())
			game.fullscreen_ui.fps_badge.hide()
			await frame()
			root.get_texture().get_image().save_png("res://docs/tests/p102-social-"+str(dims.x)+".png")
	var failed: Array = checks.keys().filter(func(k):return not checks[k])
	var tag := "headless" if DisplayServer.get_name()=="headless" else "native"
	FileAccess.open("res://docs/tests/p102-social-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"total":checks.size(),"world":social.snapshot()},"\t"))
	print(JSON.stringify({"failed":failed,"total":checks.size()}))
	quit(0 if failed.is_empty() else 1)
