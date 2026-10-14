extends SceneTree

const OUT := "res://docs/tests/keycards-v1/"
const Geometry := preload("res://scripts/presentation/doorway_geometry.gd")
var game
var checks: Array=[]
var failed: Array=[]

func _initialize(): call_deferred("run")
func check(label: String, passed: bool):
	checks.append({"name":label,"ok":passed})
	if not passed: failed.append(label); push_error(label)
func frame():
	await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
func grant(kind: String, room_id: String="") -> String:
	var spec: Dictionary={"kind":kind}
	if not room_id.is_empty():spec.room_id=room_id
	var id: String=game.keycards.create(spec)
	game.inventory.bags[0].append(id)
	game.inventory.instances[id].location="bag"
	game.inventory.instances[id].actor_id=0
	return id
func at_door(id: String, outside:=true):
	var gate: Dictionary=game.keycards.gate(id)
	var rect: Rect2=Geometry.projected_rect(game.world,gate)
	var room: Rect2=game.keycards.room_area(str(gate.card_room))
	var point: Vector2=rect.get_center()
	if rect.size.y>rect.size.x:
		point.y=rect.end.y-30
		point.x=rect.end.x+40 if room.get_center().x<rect.get_center().x else rect.position.x-40
		if not outside: point.x=rect.position.x-45 if room.get_center().x<rect.get_center().x else rect.end.x+45
	else:
		point.y=rect.end.y+42 if room.get_center().y<rect.get_center().y else rect.position.y-20
		if not outside: point.y=rect.position.y-22 if room.get_center().y<rect.get_center().y else rect.end.y+42
	game.actors[0].position=point
	game.room_visibility.tick(0,true)
	game.room_visibility.doorways.tick(true)
func view(id: String):
	var rect: Rect2=Geometry.projected_rect(game.world,game.keycards.gate(id))
	game.map_camera.center_on(rect.get_center()+Vector2(100,0))
	game.map_camera.force_update_scroll()
	game.room_visibility.doorways.tick(true)
	game.presentation.tick(0)
	game.presentation.interaction.mobile_target_key="0:card_door:"+id
	game.presentation.interaction.refresh()
	game._update_ui()
func capture(name: String):
	await frame(); await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+name+".png")
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://keycard-qa-v1.cfg")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size=Vector2i(1200,720); root.content_scale_size=root.size
	game=load("res://scenes/main.tscn").instantiate()
	game.room_id="r04";root.add_child(game)
	await frame();await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false)
	game.phase="playing";game.schedule.close();game.orders.clear()
	for actor in game.room_access.dorm_occupants():
		actor.position=Vector2(2800,3000)
		actor.set_process(false);actor.set_physics_process(false)
	game.schedule.clock_elapsed=0
	game.world.update_dorm_doors(false,[],[])
	check("nineteen stable rooms",game.keycards.room_by_id.size()==19)
	var own: String=game.keycards.matching("dorm-0")
	check("starter dorm number D-03",not own.is_empty() and game.inventory.item_name(own)=="D-03 宿舍卡")
	check("starter daily rights",not game.keycards.matching("workshop").is_empty() and not game.keycards.matching("bath").is_empty())
	check("no free restricted rights",game.keycards.matching("monitor").is_empty() and game.keycards.matching("warehouse").is_empty())
	game.actors[0].position=Vector2(2850,2800)
	check("equipment outdoor notch needs no room card",not game.keycards.inside_room(Vector2(3000,2900),"equipment") and game.keycards.movement_allowed(game.actors[0],Vector2(3000,2900)))
	for entry in game.keycards.gates():
		check(str(entry.id)+" mapped room",game.keycards.room_by_id.has(str(entry.card_room)))
		check(str(entry.id)+" uses current door art",not Geometry.art_spec(entry).is_empty())
	at_door("dorm-0")
	game.keycards.gate("dorm-0").closed=true
	check("own room opens by card",game.keycards.toggle(0,"dorm-0").ok)
	check("swipe retains physical instance",game.inventory.owns(0,own) and game.keycards.matching("dorm-0")==own)
	check("cards cannot be manually consumed",not game.inventory.try_use(0,own).ok and game.inventory.owns(0,own))
	check("cards cannot bind consumable quick slot",not game.quick_items.bind_reason(0,own).is_empty())
	at_door("dorm-1")
	game.keycards.gate("dorm-1").closed=true
	check("wrong dorm card denied",not game.keycards.toggle(0,"dorm-1").ok)
	var other: String=grant("dorm_card","dorm-1")
	check("same template unique card instances",other!=own and game.inventory.instances[other].definition_id==game.inventory.instances[own].definition_id)
	check("D-04 instance only own room",game.keycards.permissions(other)==["dorm-1"] and game.inventory.item_name(other)=="D-04 宿舍卡")
	check("D-04 swipe opens",game.keycards.toggle(0,"dorm-1").ok)
	var before: String=game.inventory.item_name(other)
	game.actors[1].name="随机囚徒甲"
	check("randomized actor name does not affect card",game.inventory.item_name(other)==before and game.keycards.matching("dorm-1")==other)
	game.world.dorms_locked=true
	game.keycards.gate("dorm-1").closed=true
	check("dorm card cannot override curfew from outside",not game.keycards.toggle(0,"dorm-1").ok)
	at_door("dorm-1",false)
	check("existing nighttime dorm lock remains inside",not game.keycards.toggle(0,"dorm-1").ok)
	game.world.dorms_locked=false
	at_door("dorm-0",false)
	game.inventory.try_drop(0,own)
	game.keycards.gate("dorm-0").closed=true
	check("drop immediately removes rights",game.keycards.matching("dorm-0").is_empty())
	check("inside cannot open locked door without card",not game.keycards.toggle(0,"dorm-0").ok)
	check("recover card to leave locked room",game.inventory.try_pickup(0,own).ok and game.keycards.toggle(0,"dorm-0").ok)
	game.inventory.try_drop(0,own)
	var rect: Rect2=Geometry.projected_rect(game.world,game.keycards.gate("dorm-0"))
	var crossing: Vector2=Vector2(rect.end.x+55,rect.end.y-30)
	check("body can exit without card",game.world.motion_clear(game.actors[0].position,crossing,game.actors[0],false,true))
	game.actors[0].position=crossing
	check("open door does not grant entry",not game.world.motion_clear(crossing,Vector2(rect.position.x-35,crossing.y),game.actors[0],false,true))
	check("no card click path denied",not game.orders.issue(0,Vector2(rect.position.x-45,crossing.y)))
	game.actors[0].position=Vector2(game.inventory.instances[own].position[0],game.inventory.instances[own].position[1])
	check("pickup restores same permission",game.inventory.try_pickup(0,own).ok and game.keycards.matching("dorm-0")==own)
	at_door("monitor-entry")
	game.world.set_access_closed("monitor-entry",true,true)
	check("monitor denies no card",not game.keycards.toggle(0,"monitor-entry").ok)
	view("monitor-entry")
	var hint=game.presentation.interaction.hint
	check("missing hint status",hint.status_text=="需要监控室房卡" and hint.disabled and not game.presentation.interaction.mobile_available())
	await capture("door-missing-card")
	var logistics: String=grant("logistics_card")
	check("logistics exactly three rooms",game.keycards.permissions(logistics)==["laundry","equipment","warehouse"])
	check("role card no administrative access",game.keycards.matching("monitor").is_empty())
	at_door("energy-entry")
	game.world.set_access_closed("energy-entry",true,true)
	check("multi room card opens equipment",game.keycards.toggle(0,"energy-entry").ok)
	at_door("cafeteria-rear")
	game.world.set_access_closed("cafeteria-rear",true,true)
	check("matching card opens outside opening hours",game.keycards.toggle(0,"cafeteria-rear").ok)
	game.world.set_access_closed("cafeteria-rear",true,true)
	game.schedule.clock_elapsed=(720.0-float(game.schedule.config.start_minutes))*game.schedule.day_seconds/1440.0
	check("laundry card during open hours",game.keycards.toggle(0,"cafeteria-rear").ok)
	game.world.set_access_closed("cafeteria-rear",true,true)
	view("cafeteria-rear")
	check("matched hint names actual carried card",hint.status_text=="已匹配：后勤通行卡" and not hint.disabled and hint.action=="刷卡开门")
	await capture("door-matched-card")
	game.inventory.try_drop(0,logistics)
	check("drop role card removes all three rights",game.keycards.permissions(logistics).all(func(id):return game.keycards.matching(str(id)).is_empty()))
	check("recover role card",game.inventory.try_pickup(0,logistics).ok)
	var duty: String=grant("duty_card")
	game.fullscreen_ui.bag_open=true
	var drawer=game.fullscreen_ui.inventory_drawer
	drawer.select_category("document")
	game.inventory_panel.selected_item=logistics;drawer.refresh()
	check("card detail hides use action",not game.inventory_panel.use_button.visible and drawer.card_note.visible)
	check("all certificate slots have numbered tooltip",game.inventory_panel.slots[game.inventory.items(0).find(other)].tooltip_text=="D-04 宿舍卡")
	check("certificate category functional",drawer.category=="document" and not drawer.matches_category(game.inventory.add_ground("scrap",Vector2.ZERO)))
	await capture("backpack-certificates")
	for size_value in [Vector2i(960,540),Vector2i(1600,900)]:
		root.size=size_value;root.content_scale_size=size_value
		await frame();game.fullscreen_ui.layout();drawer.layout();drawer.refresh()
		check("backpack in viewport "+str(size_value),Rect2(Vector2.ZERO,Vector2(size_value)).encloses(drawer.paper.get_global_rect()))
		check("card thumbnail and close do not overlap "+str(size_value),not drawer.thumbnail.get_global_rect().intersects(drawer.close_button.get_global_rect()))
		check("card note and discard do not overlap "+str(size_value),not drawer.card_note.get_global_rect().intersects(game.inventory_panel.drop_button.get_global_rect()))
		await capture("backpack-"+str(size_value.x))
	root.size=Vector2i(1200,720);root.content_scale_size=root.size
	game.fullscreen_ui.bag_open=false
	game.fullscreen_ui.layout()
	game.schedule.clock_elapsed=0
	# Guaranteed keycards use the existing timed search and transfer, not direct pickup.
	at_door("workshop-entry",false)
	game.actors[0].position=Vector2(1002,1120)
	game.room_visibility.tick(0,true)
	check("normal search can open card source",game.looting.open("locker_0"))
	game.looting.tick(45)
	var sourced: String=""
	for id in game.looting.containers["locker_0"].ids:
		if game.inventory.instances[id].definition_id=="logistics_card":sourced=id
	check("guaranteed logistics card revealed",not sourced.is_empty() and game.looting.containers["locker_0"].revealed.get(sourced,false))
	check("card source search takes actual instance",game.looting.take(sourced).ok)
	game.looting.close()
	for container_id in game.keycards.config.loot:
		game.looting._generate(str(container_id))
		check("card source registered "+str(container_id),game.looting.containers.has(container_id))
		for spec in game.keycards.config.loot[container_id]:
			check("guaranteed packed "+str(container_id)+":"+str(spec),(game.looting.containers[container_id].ids+game.inventory.items(0)).any(func(id):return game.inventory.instances[id].definition_id==spec.kind and (not spec.has("room_id") or game.keycards.permissions(str(id))==[spec.room_id])))
	game.actors[1].position=Vector2(240,1750)
	game.keycards.gate("dorm-1").closed=true
	game.keycards.prepare_npc_route(game.actors[1],Vector2(760,1780))
	check("NPC can plan exit from closed own room",not game.keycards.gate("dorm-1").closed)
	check("NPC own dorm and public credentials",game.keycards.authorized(game.actors[1],"dorm-1") and game.keycards.authorized(game.actors[1],"canteen") and not game.keycards.authorized(game.actors[1],"dorm-0"))
	game.reset_round([],123)
	check("reset grants exactly two starting cards",game.inventory.items(0).size()==2 and game.keycards.matching("dorm-0")!="" and game.keycards.matching("monitor")=="")
	check("reset clears explored card containers",not game.looting.containers["locker_0"].generated)
	var report: Dictionary={"checks":checks,"failed":failed}
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("KEYCARD_NATIVE_CHECKS ",checks.size()," FAILED=",failed)
	game.queue_free();await process_frame
	quit(0 if failed.is_empty() else 1)
