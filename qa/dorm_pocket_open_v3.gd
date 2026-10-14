extends "res://qa/dorm_door_passage_v4.gd"
const POCKET_OUT := "res://docs/tests/dorm-pocket-open-v3/"
func save_view(name: String):
	game.actors[0].moved_this_frame=false
	game.actors[0].queue_redraw()
	game.presentation.interaction.hint.hide()
	await frame(); await frame()
	if DisplayServer.get_name()!="headless":
		var capture := root.get_texture().get_image()
		capture.save_png(POCKET_OUT+name+".png")
		if name=="closed-inside":
			var door=game.room_visibility.doorways.by_id("dorm-0")
			var area := Rect2()
			for part in door.patch_parts:
				if not part.state_closed: continue
				var projected: Rect2=door.get_global_transform_with_canvas()*part.area
				area=projected if not area.has_area() else area.merge(projected)
			var roi := Rect2i(Vector2i(area.position.floor())-Vector2i(2,2),Vector2i(area.size.ceil())+Vector2i(4,4))
			capture.get_region(roi).save_png(POCKET_OUT+"closed-door-only.png")
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(POCKET_OUT))
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://dorm-pocket-open-v3-qa.cfg")
	root.size=Vector2i(1200,720); root.content_scale_size=root.size
	var map_sha := FileAccess.get_sha256("res://data/rooms/r04.json")
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await frame(); await frame()
	game.set_process(false); game.fullscreen_ui.set_process(false)
	game.fullscreen_ui.fps_badge.hide()
	game.phase="playing"; game.selected_actor_id=0; game.schedule.close(); game.orders.clear()
	for actor in game.room_access.dorm_occupants():
		actor.set_process(false); actor.set_physics_process(false); actor.position=Vector2(2800,3000)
	var player=game.actors[0]
	for room_id in ["dorm-1","dorm-2","dorm-extra-0","dorm-extra-1"]:
		var id: String=game.keycards.create({"kind":"dorm_card","room_id":room_id})
		game.inventory.instances[id].location="bag"
		game.inventory.instances[id].actor_id=0
		game.inventory.bags[0].append(id)
	game.world.update_dorm_doors(false,[],game.room_access.dorm_occupants())
	check("actual controls and admission retained",not game.mobile_controls.inputs_blocked() and game.world.admission_filter.is_valid())
	var scan := {}
	for gate in game.world.dorm_gates():
		var id: String=gate.id
		var door=game.room_visibility.doorways.by_id(id)
		var rect: Rect2=door.visual_rect
		gate.closed=false; game.world._changed(true)
		check(id+" larger physical and painted opening",rect.size.y==200 and Geometry.opening(game.world,gate).encloses(rect))
		check(id+" no inward swung leaves",gate.visual_solid_parts.size()==2 and str(gate.get("design","")).begins_with("in-wall-pocket"))
		check(id+" open threshold rails beneath character",door.patch_parts[2].z_index==12)
		var clear: Array=[]
		for y in range(ceili(rect.position.y),floori(rect.end.y)+1,2):
			if game.world.motion_clear(Vector2(rect.position.x-12,y),Vector2(rect.end.x+45,y),player,false,true): clear.append(y)
		scan[id]=clear
		check(id+" at least 60 units of usable foot-height",clear.size()>=30 and float(clear[-1])-float(clear[0])>=60)
		check(id+" whole body remains inside visible opening",clear.all(func(y):return Footprint.body_at(Vector2(rect.get_center().x,y)).position.y>=rect.position.y+14-0.01 and Footprint.body_at(Vector2(rect.get_center().x,y)).end.y<=rect.end.y-14+0.01))
		print(id+" opening="+str(rect)+" clear="+str(clear))
		# Exercise the actual control route across the entire usable band.
		for y in range(int(clear[0])+2,int(clear[-1]),10):
			player.position=Vector2(rect.position.x-12,y)
			check(id+" valid approach y="+str(y),game.world.can_place_circle(player.position,8,player,true))
			walk(KEY_D,rect.end.x+65)
			check(id+" D exits y="+str(y),player.position.x>=rect.end.x+65)
			walk(KEY_A,rect.position.x-12)
			check(id+" A enters y="+str(y),player.position.x<=rect.position.x-12)
		for y in [rect.position.y+65,rect.end.y-4,rect.end.y+26]:
			player.position=Vector2(rect.position.x-120,y); walk(KEY_D,rect.end.x+65)
			check(id+" exit beyond opening blocked y="+str(y),player.position.x<rect.position.x)
			player.position=Vector2(rect.end.x+70,y); walk(KEY_A,rect.position.x-12)
			check(id+" entry beyond opening blocked y="+str(y),player.position.x>rect.end.x)
		player.position=Vector2(rect.position.x-12,float(clear[0])+4)
		key(KEY_S,true); walk(KEY_D,rect.end.x+65); key(KEY_S,false)
		check(id+" diagonal D+S exits",player.position.x>=rect.end.x+65)
		player.position=Vector2(rect.end.x+65,float(clear[-1])-4)
		key(KEY_W,true); walk(KEY_A,rect.position.x-12); key(KEY_W,false)
		check(id+" diagonal A+W enters",player.position.x<=rect.position.x-12)
		player.position=Vector2(rect.position.x-12,float(clear[0])+16)
		var pad=game.mobile_controls.pad
		var pad_center: Vector2=pad.get_global_rect().get_center()
		check(id+" joystick accepts drag",game.mobile_controls.begin_pad(81,pad_center+Vector2(70,0)))
		for step in 80: game.mobile_controls.tick(1.0/60)
		game.mobile_controls.release_pad()
		check(id+" joystick exits",player.position.x>=rect.end.x+65)
		var y: float=rect.get_center().y-Footprint.DOOR_BODY.get_center().y
		player.position=Vector2(rect.position.x-125,rect.end.y-30)
		check(id+" room-floor approach valid",game.world.can_place_circle(player.position,8,player,true))
		walk(KEY_D,rect.end.x+65)
		check(id+" straight D exits from room floor",player.position.x>=rect.end.x+65)
		walk(KEY_A,rect.position.x-125)
		check(id+" straight A returns to room floor",player.position.x<=rect.position.x-125)
		player.position=Vector2(rect.position.x-125,rect.end.y-32)
		var destination := Vector2(rect.end.x+90,y)
		check(id+" click route from room accepted",game.orders.issue(0,destination))
		for step in 360: game.orders.tick(1.0/60)
		check(id+" click route exits around furniture",player.position.distance_to(destination)<5)
		game.orders.clear()
		gate.closed=true; game.world._changed(true)
		for offset in [-24,0,24]:
			player.position=Vector2(rect.end.x+70,y+offset); walk(KEY_A,rect.position.x-12)
			check(id+" closed blocks broad aperture offset="+str(offset),player.position.x>rect.end.x)
		gate.closed=false; game.world._changed(true)
	var door=game.room_visibility.doorways.by_id("dorm-0")
	var rect: Rect2=door.visual_rect
	var y: float=rect.get_center().y-Footprint.DOOR_BODY.get_center().y
	game.map_camera.following=false; game.map_camera.center_on(rect.get_center()+Vector2(-90,-5)); game.map_camera.force_update_scroll()
	# Reproduce a guard near the lower edge: the wider upper band stays usable.
	game.guard.position=Vector2(rect.end.x+30,y+40)
	player.position=Vector2(rect.position.x-12,y-20)
	walk(KEY_D,rect.end.x+65)
	check("pass guard through upper half",player.position.x>=rect.end.x+65)
	game.guard.position=Vector2(2800,3000)
	player.position=Vector2(rect.position.x-80,y+20)
	game.room_visibility.tick(0,true); game.presentation.tick(0)
	await save_view("open-inside")
	walk(KEY_D,rect.end.x+75)
	game.room_visibility.tick(0,true); game.presentation.tick(0)
	var cover=game.room_visibility.covers.filter(func(c):return c.room.id=="dorm-0")[0]
	check("roof above door from corridor",cover.visible and door.patch_parts.all(func(p):return p.z_index<cover.z_index))
	await save_view("open-outside")
	player.position=Vector2(rect.position.x-65,y)
	var result: Dictionary=game.room_access.toggle_dorm(0,"dorm-0")
	check("actual action closes pocket door",result.ok and door.closed)
	game.room_visibility.tick(0,true); game.presentation.tick(0)
	await save_view("closed-inside")
	check("saved map preserved",map_sha==FileAccess.get_sha256("res://data/rooms/r04.json"))
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(POCKET_OUT+("headless" if DisplayServer.get_name()=="headless" else "native")+"-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"clear_rows":scan},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)
