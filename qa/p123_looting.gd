extends "res://qa/p105_collision.gd"

var report_path: String="res://docs/tests/p123-looting.json"

func stand_beside(id: String) -> bool:
	var rect: Rect2=game.looting.containers[id].fixture.rect
	for margin in [12,24,40,56]:
		for side in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
			var point: Vector2=rect.get_center()+side*(rect.size/2+Vector2.ONE*margin)
			if not game.world.can_place_circle(point,8,game.actors[0],false,false):continue
			game.actors[0].position=point
			game.room_visibility.tick(1,true)
			if game.looting.reason(id).is_empty():return true
	return false

func put(kind: String) -> String:
	var id: String=game.inventory.add_ground(kind,game.actors[0].position)
	var result: Dictionary=game.inventory.try_pickup(0,id)
	if not result.ok:print("PICKUP FAILED ",kind," ",result)
	return id

func image(label: String):
	if DisplayServer.get_name()=="headless":return
	game.presentation.tick(0)
	game._update_ui()
	game.looting.panel.refresh()
	await frame()
	await frame()
	root.get_texture().get_image().save_png("res://docs/dev/p123/"+label+".png")

func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p123-looting.cfg")
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.fullscreen_ui.fps_badge.hide()
	game.reset_round(["chat","backpack","strong"],123)
	game.world.admission_filter=Callable()
	var loot=game.looting
	var inv=game.inventory
	var authored: Array=game.room_config.fixtures.filter(func(f):return f.has("loot_profile") and loot.tables.profiles.has(str(f.loot_profile))).map(func(f):return str(f.id))
	check("all_authored_map_containers_registered",loot.containers.size()==authored.size() and authored.all(func(id):return loot.containers.has(id)))
	check("no_doors_or_machines_are_search_points",loot.containers.values().all(func(c):return c.fixture.asset_id not in ["doorway_free_v48","prison_gate_closed_v37","equipment_pump_v43"]))
	var unreachable: Array=[]
	for id in loot.containers:
		if not stand_beside(str(id)):unreachable.append(id)
	check("every_container_has_accessible_side",unreachable.is_empty())
	if not unreachable.is_empty():print("UNREACHABLE ",unreachable)
	var id: String="detail44-dorm-personal-0"
	check("stand_by_dorm_cabinet",stand_beside(id))
	game.map_camera.center_on(Vector2(430,1430))
	game.presentation.interaction.refresh()
	check("world_interaction_offers_search",game.presentation.interaction._mobile_targets.any(func(t):return t.kind=="loot" and t.id==id))
	check("open_real_cabinet",loot.open(id))
	var state: Dictionary=loot.containers[id]
	var original_ids: Array=state.ids.duplicate()
	check("contents_start_unknown",state.revealed.is_empty() and not original_ids.is_empty())
	var first: String=original_ids[0]
	var before_unknown: Array=inv.items(0)
	check("unknown_cannot_be_taken",not loot.take(first).ok and inv.items(0)==before_unknown)
	check("container_item_cannot_be_ground_picked",not inv.try_pickup(0,first).ok)
	check("search_blocks_movement_input",game.world_input_blocked() and not game.mobile_controls.begin_pad(-1,Vector2(80,600)))
	loot.tick(0.6)
	var progress: float=state.progress[first]
	check("search_takes_real_time",progress>0 and not state.revealed.get(first,false))
	paused=true
	loot.tick(1)
	check("pause_does_not_advance_search",state.progress[first]==progress)
	paused=false
	loot.close()
	check("reopen_preserves_contents",loot.open(id) and state.ids==original_ids and state.progress[first]==progress)
	loot.toggle_search()
	loot.tick(1)
	check("stop_preserves_search_progress",state.progress[first]==progress)
	loot.toggle_search()
	var clock: float=game.schedule.clock_elapsed
	game._process(0.3)
	check("world_clock_continues_during_looting",game.schedule.clock_elapsed>clock and state.progress[first]>progress)
	loot.tick(30)
	check("items_are_revealed_individually",original_ids.all(func(item):return state.revealed.get(item,false)))
	loot.select(first)
	loot.panel.source_grid.quick_take.emit(first)
	check("quick_take_transfers_single_instance",inv.items(0).has(first) and inv.instances[first].location=="bag" and not state.ids.has(first))
	check("repeated_take_cannot_duplicate",not loot.take(first).ok and inv.items(0).count(first)==1)
	while inv.find_space(0,"gear").x>=0:put("gear")
	check("ordinary_grid_is_twenty_cells",inv.capacity(0)==20 and inv.used_cells(0)==20)
	var before: Array=state.ids.duplicate()
	check("full_bag_keeps_container_items",not loot.take_all().ok and state.ids==before)
	var arrangement: Dictionary=inv.grid_layout(0)
	var nonoverlap:=true
	for a in arrangement:
		for b in arrangement:
			if a!=b and arrangement[a].intersects(arrangement[b]):nonoverlap=false
	check("bag_items_never_overlap",nonoverlap and arrangement.size()==inv.items(0).size())
	for item in inv.items(0):inv.try_drop(0,str(item))
	loot.take_all()
	check("take_all_empties_discovered_container",state.ids.is_empty())
	loot.close()
	check("empty_container_does_not_reroll",loot.open(id) and state.ids.is_empty() and not loot.searching)
	loot.close()
	game.actors[0].position=Vector2(2200,2700)
	game.room_visibility.tick(1,true)
	check("remote_open_is_rejected",not loot.open(id))
	stand_beside(id)
	var rect: Rect2=state.fixture.rect
	game.actors[0].position=Vector2(rect.end.x+46,rect.end.y)
	var wall:=Rect2(rect.end.x+20,rect.end.y-20,8,40)
	game.world.walls.append(wall)
	game.world._changed(true)
	check("cannot_search_through_wall",not loot.open(id))
	game.world.walls.erase(wall)
	game.world._changed(true)
	for item in inv.items(0):inv.try_drop(0,str(item))
	var bread:=put("bread")
	game.attributes.values[0].fullness=50
	check("bread_has_real_effect",inv.try_use(0,bread).ok and game.attributes.values[0].fullness==75 and inv.instances[bread].location=="consumed")
	var bandage:=put("bandage")
	game.attributes.values[0].stamina=60
	check("bandage_has_real_effect",inv.try_use(0,bandage).ok and game.attributes.values[0].stamina==80)
	bread=put("bread")
	game.attributes.values[0].fullness=100
	check("full_stat_does_not_waste_consumable",not inv.try_use(0,bread).ok and inv.owns(0,bread))
	game.actors[0].skill_id="backpack"
	check("storage_skill_expands_grid",inv.capacity(0)==30 and inv.grid_size(0)==Vector2i(5,6))
	game.reset_round(["chat","backpack","strong"],123)
	game.world.admission_filter=Callable()
	stand_beside(id)
	check("new_round_resets_container",loot.open(id) and not loot.containers[id].ids.is_empty() and loot.containers[id].revealed.is_empty())
	loot.close()
	var industrial: String=loot.containers.keys().filter(func(k):return loot.containers[k].fixture.loot_profile=="industrial")[0]
	stand_beside(industrial)
	game.map_camera.center_on(game.actors[0].position)
	loot.open(industrial)
	loot.tick(0.5)
	await image("looting-unknown")
	loot.tick(3)
	for kind in ["wrench","cloth","bandage","bread"]:put(kind)
	for dimensions in [Vector2i(1200,720),Vector2i(960,540),Vector2i(1440,900)]:
		root.size=dimensions
		root.content_scale_size=dimensions
		await frame()
		game.fullscreen_ui.layout()
		loot.panel.refresh()
		check("looting_panel_fits_"+str(dimensions.x),game.fullscreen_ui.safe_area().encloses(loot.panel.panel.get_rect()))
		check("detail_does_not_overlap_gesture_hint_"+str(dimensions.x),not loot.panel.detail.get_rect().intersects(loot.panel.gesture_hint.get_rect()))
		await image("looting-"+str(dimensions.x))
	loot.close()
	stand_beside(industrial)
	loot.open(industrial)
	game.actors[0].position+=Vector2(400,0)
	loot.tick(0.1)
	check("leaving_container_closes_panel",not loot.is_open() and not loot.panel.panel.visible)
	stand_beside(industrial)
	loot.open(industrial)
	game.capture_actor(0)
	check("capture_closes_search_immediately",not loot.is_open() and not loot.panel.blocker.visible)
	var failed: Array=checks.keys().filter(func(key):return not checks[key])
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"unreachable":unreachable,"containers":loot.containers.size()},"\t"))
	quit(0 if failed.is_empty() else 1)
