extends "res://qa/dorm_aperture_movement_v3.gd"
const FIXED_OUT := "res://docs/tests/dorm-door-passage-v4/"
const Footprint = preload("res://scripts/core/actor_footprint.gd")
func passage_y(node) -> float:
	var upper: Rect2=node.transform*node.patch_parts[0].area
	var lower: Rect2=node.transform*node.patch_parts[1].area
	return (upper.end.y+lower.position.y)/2-Footprint.DOOR_BODY.get_center().y
func snapshot(name: String):
	await frame(); await frame()
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(FIXED_OUT+name+".png")
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXED_OUT))
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://dorm-passage-v4-qa.cfg")
	root.size=Vector2i(1200,720); root.content_scale_size=root.size
	var saved := FileAccess.get_sha256("res://data/rooms/r04.json")
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await frame(); await frame()
	game.set_process(false); game.fullscreen_ui.set_process(false)
	game.fullscreen_ui.fps_badge.hide()
	game.phase="playing"; game.selected_actor_id=0; game.schedule.close(); game.orders.clear()
	for actor in game.room_access.dorm_occupants():
		actor.set_process(false); actor.set_physics_process(false); actor.position=Vector2(2800,3000)
	var player=game.actors[0]
	game.world.update_dorm_doors(false,[],game.room_access.dorm_occupants())
	check("real input enabled",not game.mobile_controls.inputs_blocked())
	check("admission rules preserved",game.world.admission_filter.is_valid())
	var rows := {}
	for gate in game.world.dorm_gates():
		var id: String = gate.id
		var node=game.room_visibility.doorways.by_id(id)
		var rect: Rect2 = node.visual_rect
		gate.closed=false; game.world._changed(true)
		check(id+" uses shared full-body collision path",not gate.has("open_ground_solid_parts") and gate.get("body_profile","")=="full_body")
		var clear_rows: Array = []
		for y in range(ceili(rect.position.y),floori(rect.end.y)+1,2):
			var start := Vector2(rect.position.x-12,y)
			var end := Vector2(rect.end.x+40,y)
			if game.world.motion_clear(start,end,player,false,true): clear_rows.append(y)
		rows[id]=clear_rows
		check(id+" usable but bounded passage",not clear_rows.is_empty() and clear_rows.size()<20)
		var y: float = passage_y(node)
		var upper: Rect2=node.transform*node.patch_parts[0].area
		var lower: Rect2=node.transform*node.patch_parts[1].area
		check(id+" all clear rows keep head and shoes between visible leaves",clear_rows.all(func(row):return Footprint.body_at(Vector2(rect.get_center().x,row)).position.y>=upper.end.y-0.01 and Footprint.body_at(Vector2(rect.get_center().x,row)).end.y<=lower.position.y+0.01))
		print(id+" art="+str(rect)+" free rows="+str(clear_rows)+" full-body centre="+str(y))
		player.position=Vector2(rect.position.x-12,y)
		check(id+" full body fits middle",game.world.can_place_circle(player.position,8,player,true))
		walk(KEY_D,rect.end.x+60)
		check(id+" actual D crosses middle",player.position.x>=rect.end.x+60)
		walk(KEY_A,rect.position.x-12)
		check(id+" actual A crosses middle",player.position.x<=rect.position.x-12)
		for offset in [40,65,85,rect.size.y-6]:
			var head_y: float = rect.position.y+offset
			player.position=Vector2(rect.position.x-120,head_y)
			walk(KEY_D,rect.end.x+60)
			check(id+" jamb and leaf block exit offset="+str(offset),player.position.x<rect.position.x)
			player.position=Vector2(rect.end.x+70,head_y)
			walk(KEY_A,rect.position.x-12)
			check(id+" jamb and leaf block entry offset="+str(offset),player.position.x>rect.end.x)
		# Click movement from open room floor, not a teleported point at the seam.
		player.position=Vector2(rect.position.x-125,rect.end.y-32)
		var goal := Vector2(rect.end.x+80,y)
		var accepted: bool=game.orders.issue(0,goal)
		check(id+" click exit accepted",accepted)
		for step in 360: game.orders.tick(1.0/60)
		check(id+" click exit reaches exterior",player.position.distance_to(goal)<5)
		game.orders.clear()
		gate.closed=true; game.world._changed(true)
		player.position=Vector2(rect.end.x+70,y)
		walk(KEY_A,rect.position.x-12)
		check(id+" closed stops whole body",player.position.x>rect.end.x)
		gate.closed=false; game.world._changed(true)
	var door=game.room_visibility.doorways.by_id("dorm-0")
	var rect: Rect2=door.visual_rect
	game.map_camera.following=false
	game.map_camera.center_on(rect.get_center()+Vector2(-90,-5)); game.map_camera.force_update_scroll()
	player.position=Vector2(rect.position.x-120,rect.position.y+65)
	walk(KEY_D,rect.end.x+70)
	game.map_camera.following=false; game.room_visibility.tick(0,true); game.presentation.tick(0)
	await snapshot("upper-jamb-blocked")
	player.position=Vector2(rect.position.x-12,passage_y(door))
	game.room_visibility.tick(0,true); game.presentation.tick(0)
	await snapshot("aligned-to-door")
	walk(KEY_D,rect.end.x+75)
	game.map_camera.following=false; game.room_visibility.tick(0,true); game.presentation.tick(0)
	var cover=game.room_visibility.covers.filter(func(c):return c.room.id=="dorm-0")[0]
	check("roof remains above door from corridor",cover.visible and door.patch_parts.all(func(p):return p.z_index<cover.z_index))
	await snapshot("walked-outside")
	check("saved map unchanged",saved==FileAccess.get_sha256("res://data/rooms/r04.json"))
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(FIXED_OUT+("headless" if DisplayServer.get_name()=="headless" else "native")+"-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"clear_rows":rows},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)
