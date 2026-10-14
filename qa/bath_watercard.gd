extends SceneTree
const OUT="res://docs/art/bath-watercard-v1/"
var game
var checks: Dictionary={}
func _initialize():
	create_timer(120).timeout.connect(func():quit(124))
	call_deferred("run")
func check(label: String,passed: bool):checks[label]=passed
func frame():
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func shot(name: String):
	await frame();await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+name+".png")
func stand(point: Vector2):
	game.actors[0].position=point
	game.actors[0].moved_this_frame=false
	game.orders.clear();game.skills.clear_all()
	game.room_visibility.tick(0,true)
	game.resident_staff.tick(0)
func put(kind: String) -> String:
	var id: String=game.inventory.add_ground(kind,game.actors[0].position)
	var result: Dictionary=game.inventory.try_pickup(0,id)
	check("pickup "+id,result.ok)
	return id

func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://bath-water-card-qa.cfg")
	root.size=Vector2i(1280,900);root.content_scale_size=root.size
	var disk:=FileAccess.get_file_as_string("res://data/rooms/r04.json")
	var registration: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"asset-registration.json"))
	for key in registration.assets:
		var asset: Dictionary=registration.assets[key]
		check(key+" original PNG retained",FileAccess.get_sha256(asset.texture)==asset.sha256)
		var pixels: Image=load(asset.texture).get_image()
		check(key+" real transparency",pixels.get_pixel(0,0).a==0 and pixels.get_used_rect().has_area())
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"registration-input.json"))
	var after: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"registration-output.json"))
	for key in before:
		if key not in ["fixtures","resident_staff","bath_service"]:check("registration preserves "+key,before[key]==after[key])
	check("other room props preserved",before.fixtures.filter(func(f):return not str(f.id).begins_with("campus-bath"))==after.fixtures.filter(func(f):return not str(f.id).begins_with("campus-bath")))
	var doc=preload("res://scripts/editor/map_document.gd").new()
	doc.open_file("res://data/rooms/r04.json")
	check("editor validates map",doc.validate().errors.is_empty())
	var catalog=preload("res://scripts/items/item_catalog.gd").new()
	check("water card registered in preview catalog",catalog.definitions.has("water_card") and catalog.icon("water_card")!=null)
	check("cashier registered in character selector",preload("res://scripts/presentation/character_library.gd").all().has("bath_cashier"))
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.fullscreen_ui.fps_badge.hide();game.world.admission_filter=Callable()
	var bath=game.bath_service
	bath.refresh_stations()
	check("all six showers use payment",bath.stations.size()==6)
	var station: String=bath.stations.keys()[0]
	stand(bath.station_point(station))
	var result: Dictionary=bath.start_shower(0,station)
	check("no card rejects washing",not result.ok and result.reason.contains("没有水卡") and bath.sessions.is_empty())
	var empty_card:=put("water_card")
	check("new card has zero credit",bath.balance(empty_card)==0)
	result=bath.start_shower(0,station)
	check("empty card rejects washing",not result.ok and result.reason.contains("余额不足"))
	game.inventory.bags[0].erase(empty_card);game.inventory.instances[empty_card].location="consumed"
	stand(bath.counter_point())
	game.inventory.wallet=0
	result=bath.try_recharge(0,5)
	check("no cash no issued card",not result.ok and bath.card_ids(0).is_empty() and game.inventory.wallet==0)
	game.inventory.wallet=30
	var fillers: Array=[]
	for i in range(game.inventory.capacity(0)):fillers.append(put("scrap"))
	result=bath.try_recharge(0,5)
	check("full bag does not debit or issue",not result.ok and game.inventory.wallet==30 and bath.card_ids(0).is_empty())
	for id in fillers:game.inventory.bags[0].erase(id);game.inventory.instances[id].location="consumed"
	game.inventory.grid_layout(0)
	check("cashier interaction available",bath.recharge_reason(0).is_empty())
	game.map_camera.center_on(Vector2(1200,440));game.map_camera.force_update_scroll();await frame()
	game.presentation.tick(0);game._update_ui()
	check("nearest E target offers recharge",game.presentation.interaction.targets.any(func(t):return t.kind=="recharge"))
	var e_key:=InputEventKey.new();e_key.keycode=KEY_E;e_key.pressed=true
	game._unhandled_input(e_key)
	check("E opens recharge panel",bath.panel.is_open() and game.world_input_blocked())
	bath.panel.buttons[0].pressed.emit()
	var card: String=bath.panel.selected_card
	result={"ok":game.inventory.owns(0,card)}
	check("first payment issues one card",result.ok and bath.card_ids(0).size()==1 and game.inventory.owns(0,card))
	check("cash converted one to one",game.inventory.wallet==25 and bath.balance(card)==5)
	check("cashier plays handover",bath.cashier().service_pose=="handover")
	await shot("recharge-panel")
	result=bath.try_recharge(0,10,card)
	check("recharge updates same instance",result.ok and bath.card_ids(0)==[card] and bath.balance(card)==15 and game.inventory.wallet==15)
	check("cashier plays ledger animation",bath.cashier().service_pose=="counting")
	result=bath.try_recharge(0,-5,card)
	check("invalid recharge cannot create cash",not result.ok and bath.balance(card)==15 and game.inventory.wallet==15)
	bath.panel.close()
	game.inventory_panel.selected_item=card;game.fullscreen_ui.bag_open=true;game.fullscreen_ui.refresh()
	check("bag shows live card balance",game.fullscreen_ui.inventory_drawer.description.text.contains("15"))
	await shot("card-in-backpack")
	game.fullscreen_ui.bag_open=false;game.fullscreen_ui.refresh()
	result=game.inventory.try_use(0,card)
	check("card balance reading works",result.ok and is_instance_valid(game.inventory.reading_dialog) and game.inventory.reading_dialog.dialog_text.contains("15"))
	if is_instance_valid(game.inventory.reading_dialog):game.inventory.reading_dialog.hide()
	stand(bath.station_point(station))
	game.attributes.values[0].stamina=40
	game.presentation.tick(0)
	check("flower has E target without machine",game.presentation.interaction.targets.any(func(t):return t.kind=="shower" and t.id==station))
	game._unhandled_input(e_key)
	check("paid shower starts",bath.sessions.has(0) and game.actors[0].action_state=="bathing" and bath.balance(card)==13)
	check("repeat start cannot debit twice",not bath.start_shower(0,station).ok and bath.balance(card)==13)
	check("bathing does not incur skill stamina drain",game.attributes.behaviors()[0]=="idle")
	bath.tick(2)
	check("progress shown during bathing",bath.panel.progress_panel.visible and bath.panel.progress.value>0 and bath.panel.effect_nodes.size()==1)
	await shot("paid-shower")
	bath.tick(4)
	check("completed bathing restores stamina",not bath.sessions.has(0) and game.attributes.values[0].stamina==60 and bath.balance(card)==13)
	check("water card not consumed",game.inventory.owns(0,card))
	bath.tick(60)
	check("completion not credited twice",game.attributes.values[0].stamina==60 and bath.balance(card)==13)
	bath.start_shower(0,station)
	game.actors[0].position+=Vector2(15,0);bath.tick(.1)
	check("walking interrupts and refunds once",bath.sessions.is_empty() and bath.balance(card)==13 and game.attributes.values[0].stamina==60)
	bath.cancel(0)
	check("duplicate cancel cannot duplicate credit",bath.balance(card)==13)
	stand(bath.station_point(station))
	bath.start_shower(0,station)
	check("drop during shower allowed",game.inventory.try_drop(0,card).ok)
	bath.tick(.1)
	check("dropping card refunds original instance",bath.sessions.is_empty() and bath.balance(card)==13 and game.inventory.instances[card].location=="ground")
	check("pickup retains water card credit",game.inventory.try_pickup(0,card).ok and bath.balance(card)==13)
	check("manual bag rearrangement preserves credit",game.inventory.move_item(0,card,Vector2i(4,3)).ok and bath.balance(card)==13)
	var locker: Rect2=game.looting.containers["campus-bath-locker-0"].fixture.rect
	stand(Vector2(locker.end.x+24,locker.get_center().y))
	check("current locker can be opened",game.looting.open("campus-bath-locker-0"));game.looting.tick(30)
	var state: Dictionary=game.looting.containers["campus-bath-locker-0"]
	var free: Vector2i=preload("res://scripts/items/grid_packing.gd").first_space(state.get("layout",{}),Vector2i(4,4),Vector2i.ONE)
	check("card drag back preserves credit",game.looting.move_item(card,"bag","source",free).ok and bath.balance(card)==13)
	check("card drag into bag preserves credit",game.looting.move_item(card,"source","bag",Vector2i(4,3)).ok and bath.balance(card)==13)
	game.looting.close()
	stand(bath.station_point(station))
	var second:=put("water_card");game.inventory.instances[card].water_balance=1;game.inventory.instances[second].water_balance=8
	bath.start_shower(0,station)
	check("multiple cards selects affordable actual card",bath.sessions[0].card_id==second and bath.balance(card)==1 and bath.balance(second)==6)
	bath.cancel(0)
	check("refund returns to same selected card",bath.balance(card)==1 and bath.balance(second)==8)
	bath.start_shower(0,station)
	game.actors[0].confined=true;bath.tick(.1)
	check("capture cancels and refunds",bath.sessions.is_empty() and bath.balance(second)==8)
	game.actors[0].confined=false
	bath.start_shower(0,station)
	game.phase="failed";bath.tick(0)
	check("round ending cancels and refunds",bath.sessions.is_empty() and bath.balance(second)==8)
	game.phase="playing"
	for id in bath.stations:
		stand(bath.station_point(id))
		game.presentation.tick(0)
		var prompt = game.presentation.interaction
		prompt.refresh()
		check(str(id)+" highlight follows fixture mirror",prompt.outline.flip_h==bool(bath.stations[id].get("mirror_x",false)))
		if id=="campus-bath-shower-1-2":await shot("right-shower-highlight")
		check(str(id)+" physically reachable",game.world.can_place_circle(game.actors[0].position,8,game.actors[0],false))
		check(str(id)+" takes water-card payment",bath.start_shower(0,str(id)).ok)
		bath.cancel(0)
	stand(bath.station_point(station))
	game.attributes.values[0].stamina=95
	bath.start_shower(0,station)
	var held_balance: int=bath.balance(second)
	paused=true
	bath.tick(6)
	paused=false
	check("paused shower neither completes nor refunds",bath.sessions.has(0) and bath.sessions[0].elapsed==0 and bath.balance(second)==held_balance)
	bath.tick(6)
	check("recovery clamps at maximum",game.attributes.values[0].stamina==100)
	stand(bath.counter_point())
	bath.open_recharge(0)
	var old_clock: float=game.schedule.clock_elapsed
	game.schedule.clock_elapsed=(1260-480)/1440.0*game.schedule.day_seconds
	bath.tick(0)
	check("closed shift closes recharge modal",not bath.panel.is_open())
	check("closed shift does not debit",not bath.try_recharge(0,5,card).ok)
	game.schedule.clock_elapsed=old_clock
	check("no scene reader added",game.world.fixtures.filter(func(f):return str(f.id).begins_with("campus-bath") and str(f.asset_id).contains("reader")).is_empty())
	stand(bath.counter_point())
	game.resident_staff.tick(2)
	game.inventory.wallet=20
	game.get_node("HUD").hide()
	await shot("cashier-counter-clear")
	game.get_node("HUD").show()
	check("QA leaves project map untouched",disk==FileAccess.get_file_as_string("res://data/rooms/r04.json"))
	game.reset_round()
	check("round reset clears sessions and modal",bath.sessions.is_empty() and not bath.panel.is_open() and not bath.panel.progress_panel.visible)
	check("round reset clears previous card credit",bath.card_ids(0).is_empty() and game.inventory.wallet==0)
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	game.queue_free();await frame();quit(0 if failed.is_empty() else 1)
