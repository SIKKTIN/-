extends "res://qa/p101_npc_responses.gd"

func _initialize():
	create_timer(60).timeout.connect(func():quit(124))
	call_deferred("run")

func travel(actor, start: Vector2, goal: Vector2) -> bool:
	actor.position = start
	var path: PackedVector2Array = game.world.find_path(start,goal,actor,false,true)
	if path.is_empty():
		print("NO PATH ",start," -> ",goal," start clear ",game.world.can_place_circle(start,8,actor,false,false)," goal clear ",game.world.can_place_circle(goal,8,actor,false,false))
		return false
	var cursor := start
	for point in path:
		if not game.world.motion_clear(cursor,point,actor,false,true): return false
		for step in range(600):
			var offset: Vector2 = point-actor.position
			if offset.length()<0.5: break
			if game.world.move_actor(actor,offset.normalized()*minf(3,offset.length())).length()<0.001:
				print("STALLED ",actor.position," -> ",point)
				return false
		cursor = actor.position
	return actor.position.distance_to(goal)<1

func capture_collision(label: String, origin: Vector2):
	if DisplayServer.get_name()=="headless": return
	game.room_visibility.tick(0.3,true)
	game.map_camera.following=false
	game.map_camera.zoom=Vector2.ONE
	game.map_camera.position=origin
	game.map_camera.force_update_scroll()
	await frame()
	game.presentation.tick(0)
	await frame()
	root.get_texture().get_image().save_png("res://docs/tests/p105-"+label+".png")

func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.reset_round(["chat","chat","backpack"],105)
	game.world.admission_filter = Callable()
	game.orders.clear()
	for actor in game.actors: actor.position = Vector2(3000+actor.actor_id*60,2400)
	for gate in game.world.access_doors: game.world.set_access_closed(gate.id,false)
	game.world.update_dorm_doors(false,[])
	var world = game.world
	var main = game.actors[0]
	var view = game.room_visibility.doorways.by_id("dorm-0")
	check("side_opening_has_usable_full_body_margin",view.visual_rect.size.y>=128)
	for y in [390,400,410,420,428]:
		main.position = Vector2(650,y)
		world.move_actor(main,Vector2(90,0))
		check("reported_door_direct_exit_at_"+str(y),main.position.distance_to(Vector2(740,y))<0.1)
		world.move_actor(main,Vector2(-90,0))
		check("reported_door_direct_enter_at_"+str(y),main.position.distance_to(Vector2(650,y))<0.1)
	check("reported_player_path_exits_dorm",travel(main,Vector2(650,428),Vector2(750,480)))
	check("reported_player_path_enters_dorm",travel(main,Vector2(750,480),Vector2(600,420)))
	for y in [374,435]:
		main.position = Vector2(650,y)
		world.move_actor(main,Vector2(90,0))
		check("side_jamb_still_stops_head_or_shoes_"+str(y),main.position.x<680)
	for id in ["dorm-1","dorm-2","solitary-0","solitary-1","solitary-2"]:
		var door = game.room_visibility.doorways.by_id(id)
		var feet: Vector2 = door.visual_rect.get_center()+Vector2(0,30)
		check(id+"_real_walk_both_sides",travel(main,feet-Vector2(80,0),feet+Vector2(80,0)) and travel(main,feet+Vector2(80,0),feet-Vector2(80,0)))
		main.position = Vector2(3000,2400)
		if id.begins_with("dorm-"): world.update_dorm_doors(true,[])
		else: world.set_access_closed(id,true)
		check(id+"_closed_blocks",not world.motion_clear(feet-Vector2(80,0),feet+Vector2(80,0),null,false,true))
		if id.begins_with("dorm-"): world.update_dorm_doors(false,[])
		else: world.set_access_closed(id,false)
	for x in [1180,1220,1440,1500,1700]:
		main.position = Vector2(x,880)
		world.move_actor(main,Vector2(0,200))
		check("workshop_wall_blocks_at_visible_top_"+str(x),main.position.y<=932.1 and main.position.y>=929)
		check("cannot_stand_in_workshop_wall_"+str(x),not world.can_place_circle(Vector2(x,980),8,main,false,false))
		main.position = Vector2(x,1120)
		world.move_actor(main,Vector2(0,-200))
		check("workshop_wall_blocks_from_corridor_"+str(x),main.position.y>=1067.9)
	main.position = Vector2(1220,900)
	world.move_actor(main,Vector2(25,160))
	check("diagonal_cannot_drill_into_wall",main.position.y<=932.1)
	main.position = Vector2(3000,2400)
	for id in ["workshop-entry","workshop-entry-east","cafeteria-entry","cafeteria-entry-east"]:
		var gate: Dictionary = world.access_by_id(id)
		if gate.is_empty(): continue # East entrances are optional map extensions.
		var door = game.room_visibility.doorways.by_id(id)
		var center: Vector2 = door.visual_rect.get_center()
		var start := Vector2.ZERO
		var goal := Vector2.ZERO
		for offset in [80,40,120]:
			var candidate: Vector2 = center-Vector2(0,offset)
			if world.can_place_circle(candidate,8,main,false,false): start=candidate; break
		for offset in [180,140,120,100]:
			var candidate: Vector2 = center+Vector2(0,offset)
			if world.can_place_circle(candidate,8,main,false,false): goal=candidate; break
		check(id+"_open_walks_both_sides",start!=Vector2.ZERO and goal!=Vector2.ZERO and travel(main,start,goal) and travel(main,goal,start))
		main.position = Vector2(3000,2400)
		world.set_access_closed(id,true)
		check(id+"_closed_body_blocked",not world.motion_clear(center-Vector2(0,100),center+Vector2(0,180),main,false,true))
		world.set_access_closed(id,false)
	main.position = Vector2(690,420)
	await capture_collision("door-clearance",Vector2(80,60))
	main.position = Vector2(1220,900)
	world.move_actor(main,Vector2(0,100))
	await capture_collision("wall-contact",Vector2(620,580))
	var failed: Array = checks.keys().filter(func(key):return not checks[key])
	var file = FileAccess.open("res://docs/tests/p105-collision.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	quit(0 if failed.is_empty() else 1)
