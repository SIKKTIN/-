extends SceneTree
const OUT := "res://docs/tests/dorm-aperture-movement-v3/"
const Geometry = preload("res://scripts/presentation/doorway_geometry.gd")
var checks := {}
var game
func check(label: String, passed: bool): checks[label]=passed
func _initialize(): call_deferred("run")
func frame():
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func shot(name: String):
	await frame(); await frame()
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(OUT+name+".png")
func key(code: int, pressed: bool):
	var event := InputEventKey.new(); event.keycode=code; event.pressed=pressed
	game.mobile_controls._input(event)
func walk(code: int, target_x: float):
	key(code,true)
	for step in 120:
		game.mobile_controls.tick(1.0/60)
		if (code==KEY_D and game.actors[0].position.x>=target_x) or (code==KEY_A and game.actors[0].position.x<=target_x): break
	key(code,false)
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://dorm-aperture-v3-qa.cfg")
	root.size=Vector2i(1200,720); root.content_scale_size=root.size
	var saved := FileAccess.get_sha256("res://data/rooms/r04.json")
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await frame(); await frame()
	game.set_process(false); game.fullscreen_ui.set_process(false)
	game.phase="playing"; game.selected_actor_id=0
	game.schedule.close(); game.orders.clear()
	for actor in game.room_access.dorm_occupants():
		actor.set_process(false); actor.set_physics_process(false); actor.position=Vector2(2800,3000)
	var player=game.actors[0]
	check("actual input remains enabled",not game.mobile_controls.inputs_blocked())
	check("real admission rules remain installed",game.world.admission_filter.is_valid())
	var gates: Array = game.world.dorm_gates()
	game.world.update_dorm_doors(false,[],game.room_access.dorm_occupants())
	for gate in gates:
		var id: String = gate.id
		var node=game.room_visibility.doorways.by_id(id)
		var rect: Rect2 = node.visual_rect
		gate.closed=false; game.world._changed(true)
		var aperture: Rect2 = Geometry.opening(game.world,gate)
		check(id+" complete wall aperture including outermost pixel",aperture.encloses(rect))
		var crossed := 0
		for y in range(ceili(rect.position.y)+24,floori(rect.end.y)-23,6):
			var start := Vector2(rect.position.x-12,y)
			var goal := Vector2(rect.end.x+40,y)
			player.position=start
			check(id+" starting position valid y="+str(y),game.world.can_place_circle(start,game.world.RADIUS,player,true))
			walk(KEY_D,goal.x)
			check(id+" D exits actual door y="+str(y),player.position.x>=goal.x)
			walk(KEY_A,start.x)
			check(id+" A reenters actual door y="+str(y),player.position.x<=start.x)
			crossed+=1
		print(id+" tested actual bidirectional movement heights: "+str(crossed))
		# Click movement must negotiate the room furniture, not jump over it.
		player.position=Vector2(rect.position.x-95,rect.end.y-35)
		var destination := Vector2(rect.end.x+80,rect.get_center().y)
		var accepted: bool = game.orders.issue(0,destination)
		check(id+" click route accepted",accepted)
		for step in 360: game.orders.tick(1.0/60)
		check(id+" click route exits room",player.position.distance_to(destination)<5)
		game.orders.clear()
		# Close the gate from a safe exterior position; the same input cannot
		# walk back through, while an authorized inspection uses open contacts.
		player.position=Vector2(rect.end.x+80,rect.get_center().y)
		gate.closed=true; game.world._changed(true)
		walk(KEY_A,rect.position.x-12)
		check(id+" closed door stops real A movement",player.position.x>rect.end.x)
		check(id+" inspection bypass leaves no phantom frame",not game.world.door_passage.solids(true).any(func(r):return r.has_point(rect.get_center())))
		gate.closed=false; game.world._changed(true)
	# Reproduce the screenshot's position in the centre of the visible frame.
	var door=game.room_visibility.doorways.by_id("dorm-0")
	var rect: Rect2 = door.visual_rect
	player.position=Vector2(rect.get_center().x,rect.position.y+rect.size.y*0.45)
	game.map_camera.following=false
	game.map_camera.center_on(rect.get_center()+Vector2(-90,-5)); game.map_camera.force_update_scroll()
	game.room_visibility.tick(0,true); game.presentation.tick(0)
	await shot("at-reported-stuck-position")
	walk(KEY_D,rect.end.x+75)
	check("reported stuck position exits with D",player.position.x>=rect.end.x+75)
	game.map_camera.following=false
	game.room_visibility.tick(0,true); game.presentation.tick(0)
	var cover=game.room_visibility.covers.filter(func(c):return c.room.id=="dorm-0")[0]
	check("exterior roof covers inward door",cover.visible and door.patch_parts.all(func(p):return p.z_index<cover.z_index))
	await shot("walked-outside")
	walk(KEY_A,rect.position.x-40)
	check("reported position can reenter with A",player.position.x<=rect.position.x-40)
	game.map_camera.following=false
	game.room_visibility.tick(0,true); game.presentation.tick(0)
	check("inside roof reveals room",not cover.visible)
	await shot("walked-back-inside")
	check("map not rewritten",saved==FileAccess.get_sha256("res://data/rooms/r04.json"))
	var failed: Array = checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+("headless" if DisplayServer.get_name()=="headless" else "native")+"-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)
