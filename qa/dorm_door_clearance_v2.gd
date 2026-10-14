extends SceneTree
const OUT := "res://docs/tests/dorm-door-clearance-v2/"
const Depth = preload("res://scripts/presentation/world_depth.gd")
var checks := {}
func check(label: String, passed: bool): checks[label] = passed
func _initialize(): call_deferred("run")
func frame():
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func shot(name: String):
	await frame(); await frame()
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(OUT+name+".png")
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://dorm-clearance-v2-qa.cfg")
	root.size = Vector2i(1200,720); root.content_scale_size = root.size
	var saved := FileAccess.get_sha256("res://data/rooms/r04.json")
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT+"before-manifest.json"))
	var old: Dictionary = legacy.assets.filter(func(a):return a.id=="doorway_dorm_side_open_v1")[0].door_presentation
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game); await frame(); await frame()
	game.set_process(false); game.fullscreen_ui.set_process(false); game.get_node("HUD").hide()
	game.world.admission_filter = Callable()
	for actor in game.room_access.dorm_occupants():
		actor.set_process(false); actor.set_physics_process(false); actor.position = Vector2(2800,3000)
	var player = game.actors[0]
	var gates: Array = game.world.dorm_gates()
	check("all five doors present",gates.size()==5)
	for gate in gates:
		var id: String = gate.id
		var node = game.room_visibility.doorways.by_id(id)
		gate.closed = false
		var new_parts: Array = gate.visual_solid_parts.duplicate(true)
		var ground_parts: Array = gate.open_ground_solid_parts.duplicate(true)
		var current := preload("res://scripts/presentation/doorway_geometry.gd").art_spec(gate)
		check(id+" original artwork and patch dimensions unchanged",current.door_open_patches==old.door_open_patches and current.door_closed_patches==old.door_closed_patches)
		check(id+" closed leaf remains full strength",current.closed_visual_solid_parts[-1]==old.closed_visual_solid_parts[-1])
		var probes: Array[Vector2] = []
		for x in range(int(node.visual_rect.position.x)-130,int(node.visual_rect.end.x)+85,6):
			for y in range(int(node.visual_rect.position.y)-10,int(node.visual_rect.end.y)+80,6): probes.append(Vector2(x,y))
		gate.erase("open_ground_solid_parts")
		gate.visual_solid_parts = old.visual_solid_parts.duplicate(true); game.world._changed(true)
		var previously_blocked: Array[Vector2] = []
		for point in probes:
			if not game.world.motion_clear(point,point+Vector2(0,1),player,false,true): previously_blocked.append(point)
		gate.open_ground_solid_parts=ground_parts
		gate.visual_solid_parts = new_parts; game.world._changed(true)
		var freed: Array[Vector2] = previously_blocked.filter(func(p):return game.world.motion_clear(p,p+Vector2(0,1),player,false,true))
		check(id+" real approaches gain usable clearance",freed.size()>10)
		var y: float = gate.rect.position.y+20
		var inside := Vector2(node.visual_rect.position.x-65,y)
		var outside := Vector2(node.visual_rect.end.x+70,y)
		if not game.world.motion_clear(inside,outside,player,false,true):
			print("blocked "+id+" "+str(inside)+" -> "+str(outside)+" gate="+str(gate.rect)+" art="+str(node.visual_rect))
			for obstacle in game.world.body_solids:
				if game.world.ray_rect_fraction(inside,outside,obstacle)>=0: print("body obstacle "+str(obstacle))
			for obstacle in game.world.solid_rects(false):
				if game.world._segment_hits_rect(inside,outside,obstacle): print("ground obstacle "+str(obstacle))
		check(id+" open passes both directions",game.world.motion_clear(inside,outside,player,false,true) and game.world.motion_clear(outside,inside,player,false,true))
		gate.closed = true; game.world._changed(true)
		check(id+" closed still blocks passage",not game.world.motion_clear(inside,outside,player,false,true))
		check(id+" authorized inspection keeps small ground contacts",not game.world.door_passage.solids(true).any(func(r):return r.has_point(Vector2(node.visual_rect.get_center().x,y))))
		gate.closed = false; game.world._changed(true)
		var cover = game.room_visibility.covers.filter(func(c):return c.ports.any(func(p):return str(p.id)==id))[0]
		check(id+" roof above whole door assembly",node.z_index<cover.z_index and node.patch_parts.all(func(p):return p.z_index<cover.z_index))
		check(id+" upper lower depth relation retained",node.patch_parts[0].z_index<node.patch_parts[1].z_index)
		check(id+" floor stays below player",node.get_node("ThresholdFloor").z_index==12)
		print(id+" newly usable probe positions: "+str(freed.size()))
	var door = game.room_visibility.doorways.by_id("dorm-0")
	var cover = game.room_visibility.covers.filter(func(c):return c.room.id=="dorm-0")[0]
	player.position = Vector2(door.visual_rect.end.x+75,door.gate.rect.position.y+20)
	game.map_camera.center_on(door.visual_rect.get_center()+Vector2(-90,-5)); game.map_camera.force_update_scroll()
	game.room_visibility.tick(0,true); game.presentation.tick(0); game.room_visibility.doorways.tick(true)
	check("outside roof is opaque",cover.visible and cover.modulate.a==1)
	var depths: Array = door.patch_parts.map(func(p):return p.z_index)
	var corrected_panels: Array[Rect2] = cover.panels.duplicate()
	cover.panels.assign(preload("res://scripts/presentation/roof_geometry.gd").subtract_all(cover.roof,cover.cutouts))
	cover.queue_redraw()
	for part in door.patch_parts:
		var base := 0.0
		for corner in [part.area.position,part.area.end,Vector2(part.area.end.x,part.area.position.y),Vector2(part.area.position.x,part.area.end.y)]: base=maxf(base,(door.transform*corner).y)
		part.z_index=Depth.for_y(base+3.01,game.world.bounds.end.y)-1
	await shot("exterior-before")
	var before: Image
	if DisplayServer.get_name() != "headless": before=root.get_texture().get_image()
	for index in door.patch_parts.size(): door.patch_parts[index].z_index=depths[index]
	cover.panels.assign(corrected_panels); cover.queue_redraw()
	await shot("exterior-open")
	if DisplayServer.get_name() != "headless":
		var after: Image = root.get_texture().get_image()
		var changed := 0
		for y in after.get_height():
			for x in after.get_width():
				var delta: Color = after.get_pixel(x,y)-before.get_pixel(x,y)
				if absf(delta.r)+absf(delta.g)+absf(delta.b)>.12: changed+=1
		check("native pixels show roof covering inward leaf",changed>100)
		print("roof corrected native pixels: "+str(changed))
	door.gate.closed=true; game.world._changed(true); game.room_visibility.doorways.tick(true)
	await shot("exterior-closed")
	door.gate.closed=false; game.world._changed(true); game.room_visibility.doorways.tick(true)
	player.position=Vector2(door.visual_rect.position.x-95,door.gate.rect.position.y+20)
	game.room_visibility.tick(0,true); game.presentation.tick(0)
	check("inside own roof hidden",not cover.visible)
	await shot("interior-open")
	check("saved map unchanged",saved==FileAccess.get_sha256("res://data/rooms/r04.json"))
	var failed: Array = checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+("headless" if DisplayServer.get_name()=="headless" else "native")+"-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)
