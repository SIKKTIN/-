extends Node

# All card credit belongs to an item instance, not a global bath wallet.
var game
var config: Dictionary={}
var panel
var sessions: Dictionary={}
var stations: Dictionary={}
var fixture_revision: int=-1

func configure(owner_game):
	game=owner_game
	config=game.room_config.get("bath_service",{}).duplicate(true)
	panel=preload("res://scripts/ui/bath_service_panel.gd").new()
	game.add_child(panel)
	panel.configure(self)
	reset()
	set_process(false)

func reset():
	sessions.clear()
	config=game.room_config.get("bath_service",{}).duplicate(true)
	stations.clear();fixture_revision=-1
	if panel:panel.close();panel.refresh_progress()

func enabled() -> bool:return config.get("enabled",false)
func cost() -> int:return maxi(1,int(config.get("shower_cost",2)))
func duration() -> float:return maxf(1,float(config.get("duration_seconds",6)))
func balance(card: String) -> int:return maxi(0,int(game.inventory.instances.get(card,{}).get("water_balance",0)))

func refresh_stations():
	if fixture_revision==game.world.fixtures_revision:return
	fixture_revision=game.world.fixtures_revision
	stations.clear()
	if not enabled():return
	for fixture in game.world.fixtures:
		if fixture.get("asset_id","")=="bath_shower_single":stations[str(fixture.id)]=fixture

func card_ids(actor_id: int) -> Array:
	return game.inventory.items(actor_id).filter(func(id):return game.inventory.instances.get(id,{}).get("definition_id","")=="water_card")

func preferred_card(actor_id: int,minimum:=0) -> String:
	var selected: String=""
	for id in card_ids(actor_id):
		if balance(id)>=minimum and (selected.is_empty() or balance(id)>balance(selected)):selected=str(id)
	return selected

func actor_reason(actor_id: int) -> String:
	if not game.actor_is_controllable(actor_id) or not game.inventory.available(actor_id):return "当前无法使用浴室服务。"
	if game.actors[actor_id].confined:return "禁闭期间无法使用浴室服务。"
	if game.schedule and game.schedule.is_sleeping(actor_id):return "请先起床再使用浴室服务。"
	return ""

func station_point(id: String) -> Vector2:
	refresh_stations()
	return stations[id].rect.get_center()+Vector2(0,50) if stations.has(id) else Vector2.ZERO

func counter_fixture() -> Dictionary:
	for fixture in game.world.fixtures:
		if str(fixture.id)==str(config.get("counter_id","")):return fixture
	return {}

func counter_point() -> Vector2:
	var fixture: Dictionary=counter_fixture()
	if fixture.is_empty():return Vector2.ZERO
	if not fixture.has("recharge_offset"):return fixture.rect.position+Vector2(-24,fixture.rect.size.y/2)
	# Map-authored offsets belong to the original furniture orientation.
	# Follow the same local mirrors and quarter turns as its painted counter.
	var turns: int=posmod(int(fixture.get("rotation_quarters",0)),4)
	var size: Vector2=fixture.rect.size
	if turns%2:size=Vector2(size.y,size.x)
	var offset: Array=fixture.recharge_offset
	var local:=Vector2(offset[0],offset[1])-size/2
	if fixture.get("mirror_x",false):local.x=-local.x
	if fixture.get("mirror_y",false):local.y=-local.y
	return fixture.rect.get_center()+preload("res://scripts/core/spatial_transform.gd").point(local,Vector2.ZERO,turns)

func cashier():
	return game.resident_staff.actors.get(str(config.get("cashier_id",""))) if game.resident_staff else null

func recharge_reason(actor_id: int,allow_panel:=false) -> String:
	if not enabled():return "这里没有水卡充值服务。"
	var reason: String=actor_reason(actor_id)
	if not reason.is_empty():return reason
	if sessions.has(actor_id):return "请先结束洗澡再充值。"
	var staff=cashier()
	var fixture: Dictionary=counter_fixture()
	if not is_instance_valid(staff) or fixture.is_empty():return "收费点暂时无法使用。"
	var minute: float=game.schedule.clock_minutes()
	if minute<float(staff.spec.get("work_start",480)) or minute>=float(staff.spec.get("work_end",1200)):return "收费员已下班，充值时间为08:00–20:00。"
	var point: Vector2=counter_point()
	var actor=game.actors[actor_id]
	if game.world.is_under_roof(staff.position):return "进入浴室后才能充值水卡。"
	if actor.position.distance_to(point)>72 or not game.world.line_clear(actor.position,point):return "请靠近入口柜台的收费点。"
	if game.skills.actions.has(actor_id):return "先停止当前操作再充值。"
	if game.world_input_blocked() and not (allow_panel and panel.is_open() and panel.actor_id==actor_id):return "关闭当前界面后再充值。"
	return ""

func open_recharge(actor_id: int) -> Dictionary:
	var reason: String=recharge_reason(actor_id)
	if not reason.is_empty():return {"ok":false,"reason":reason}
	game.orders.stop(actor_id);game.mobile_controls.cancel_input();game.routines.take_control(actor_id)
	panel.open(actor_id)
	return {"ok":true,"reason":""}

func try_recharge(actor_id: int,amount: int,card_id: String="") -> Dictionary:
	var reason: String=recharge_reason(actor_id,true)
	if not reason.is_empty():return {"ok":false,"reason":reason}
	if panel.is_open() and game.selected_actor_id!=actor_id:return {"ok":false,"reason":"操作对象已经变化，请重新打开充值窗口。"}
	if amount<=0 or not config.get("recharge_amounts",[5,10,20]).any(func(value):return int(value)==amount):return {"ok":false,"reason":"请选择有效的充值金额。"}
	if not card_id.is_empty() and (not game.inventory.owns(actor_id,card_id) or card_id not in card_ids(actor_id)):return {"ok":false,"reason":"这张水卡已不在背包，未扣款。"}
	if card_id.is_empty() and not card_ids(actor_id).is_empty():card_id=preferred_card(actor_id)
	var point: Vector2i=Vector2i(-1,-1)
	if card_id.is_empty():
		point=game.inventory.find_space(actor_id,"water_card")
		if point.x<0:return {"ok":false,"reason":"背包需要1个空格领取水卡，未扣款。"}
	if game.inventory.wallet<amount:return {"ok":false,"reason":"现金不足，充值未扣款。可以劳动领取工资。"}
	# Check first; debit, issue and credit together in this synchronous commit.
	var issued: bool=card_id.is_empty()
	if issued:
		card_id=game.inventory.add_ground("water_card",Vector2.ZERO)
		game.inventory.instances[card_id].location="bag";game.inventory.instances[card_id].actor_id=actor_id
		game.inventory.bags[actor_id].append(card_id);game.inventory.place_item(actor_id,card_id,point)
	game.inventory.wallet-=amount
	game.inventory.instances[card_id].water_balance=balance(card_id)+amount
	game.inventory.metadata_revision+=1
	var staff=cashier()
	if is_instance_valid(staff):staff.play_service_pose("handover" if issued else "counting",1.6)
	return {"ok":true,"reason":"%s充值%d点，水卡余额%d点。" % ["已领卡并" if issued else "已",amount,balance(card_id)],"card_id":card_id}

func nearby_stations(point: Vector2) -> Array:
	refresh_stations()
	var result: Array=[]
	for id in stations:
		var target: Vector2=station_point(id)
		if not game.world.is_under_roof(target) and point.distance_to(target)<=72 and game.world.line_clear(point,target):result.append(id)
	return result

func shower_reason(actor_id: int,id: String) -> String:
	refresh_stations()
	var reason: String=actor_reason(actor_id)
	if not reason.is_empty():return reason
	if not stations.has(id):return "这个花洒已不可用。"
	if sessions.has(actor_id):return "正在洗澡，按E可以中断。"
	if game.world_input_blocked():return "关闭当前界面后再使用花洒。"
	if game.skills.actions.has(actor_id) or game.routines.is_working(actor_id) or game.routines.is_eating(actor_id):return "先停止当前操作再洗澡。"
	var point: Vector2=station_point(id)
	if game.world.is_under_roof(point):return "进入浴室后才能使用花洒。"
	var actor=game.actors[actor_id]
	if actor.position.distance_to(point)>44 or not game.world.line_clear(actor.position,point):return "再靠近一些，站进淋浴位后使用。"
	if not game.world.can_place_circle(actor.position,game.ACTOR_RADIUS,actor,false):return "请站到淋浴位的空地上。"
	if sessions.values().any(func(s):return str(s.station_id)==id):return "这个淋浴位正在使用，请换一个。"
	if card_ids(actor_id).is_empty():return "没有水卡，请先到入口柜台找收费员充值领卡。"
	if preferred_card(actor_id,cost()).is_empty():return "水卡余额不足，每次洗澡需要%d点。请找收费员充值。" % cost()
	return ""

func start_shower(actor_id: int,id: String) -> Dictionary:
	var reason: String=shower_reason(actor_id,id)
	if not reason.is_empty():return {"ok":false,"reason":reason}
	var card: String=preferred_card(actor_id,cost())
	var actor=game.actors[actor_id]
	game.orders.stop(actor_id);game.mobile_controls.cancel_input();game.routines.take_control(actor_id)
	game.inventory.instances[card].water_balance=balance(card)-cost();game.inventory.metadata_revision+=1
	sessions[actor_id]={"station_id":id,"card_id":card,"anchor":actor.position,"elapsed":0.0,"paid":cost(),"duration":duration()}
	actor.action_state="bathing";panel.refresh_progress()
	return {"ok":true,"reason":"洗澡开始，扣除%d点水卡余额；移动或按E中断会退款。" % cost()}

func cancel(actor_id: int,reason: String="洗澡已中断。"):
	if not sessions.has(actor_id):return
	var session: Dictionary=sessions[actor_id]
	sessions.erase(actor_id)
	if game.inventory.instances.has(session.card_id):
		game.inventory.instances[session.card_id].water_balance=balance(session.card_id)+int(session.paid)
		game.inventory.metadata_revision+=1
	if game.actors[actor_id].action_state=="bathing":game.actors[actor_id].action_state="idle"
	game.show_status(reason+" 本次%d点已退回原水卡。" % int(session.paid),5)
	panel.refresh_progress()

func tick(delta: float):
	if not enabled() or game.get_tree().paused:return
	if panel.is_open():
		var reason: String=recharge_reason(panel.actor_id,true)
		if game.selected_actor_id!=panel.actor_id:reason="操作对象已变化。"
		if not reason.is_empty():panel.close();game.show_status(reason)
		else:panel.refresh()
	for actor_id in sessions.keys():
		var session: Dictionary=sessions[actor_id]
		var actor=game.actors[actor_id]
		if game.phase!="playing" or actor.escaped or actor.confined or actor.action_state!="bathing":
			cancel(actor_id,"当前状态无法继续洗澡。");continue
		if actor.position.distance_to(session.anchor)>12 or game.orders.active.has(actor_id) or actor.moved_this_frame:
			cancel(actor_id,"离开淋浴位，洗澡中断。");continue
		refresh_stations()
		if not stations.has(session.station_id) or actor.position.distance_to(station_point(session.station_id))>44:
			cancel(actor_id,"淋浴位已不可用。");continue
		if not game.inventory.owns(actor_id,session.card_id):
			cancel(actor_id,"水卡已不在背包，洗澡中断。");continue
		session.elapsed=minf(float(session.duration),float(session.elapsed)+maxf(0,delta))
		if session.elapsed>=session.duration:
			sessions.erase(actor_id);actor.action_state="idle"
			var amount: float=minf(float(config.get("restore_stamina",20)),100-float(game.attributes.values[actor_id].stamina))
			game.attributes.values[actor_id].stamina=minf(100,float(game.attributes.values[actor_id].stamina)+amount)
			game.show_status("洗澡完成，恢复%d点体力；水卡余额%d点。" % [roundi(amount),balance(session.card_id)],5)
	panel.refresh_progress()

func snapshot() -> Dictionary:return {"enabled":enabled(),"sessions":sessions.duplicate(true)}
