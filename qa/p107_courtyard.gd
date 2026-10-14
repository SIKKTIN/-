extends "res://qa/p105_collision.gd"

func _initialize():
	create_timer(120).timeout.connect(func():quit(124))
	call_deferred("run")

func save_report(extra := {}):
	var failed: Array = checks.keys().filter(func(key):return not checks[key])
	var report := {"checks":checks,"failed":failed}
	report.merge(extra)
	FileAccess.open("res://docs/tests/p107-courtyard.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	quit(0 if failed.is_empty() else 1)

func point(a: Array) -> Vector2: return Vector2(a[0],a[1])

func path_walk(label: String, start: Vector2, goal: Vector2):
	check(label,travel(game.actors[0],start,goal))

func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p107-courtyard.cfg")
	OS.set_environment("ESCAPE_FRAME_MODE","0")
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.schedule.set_time_speed(0)
	game.reset_round(["lockpick","chat","backpack"],106)
	game.world.admission_filter=Callable()
	game.orders.clear()
	for a in game.actors: a.position=Vector2(2300+a.actor_id*60,2700)
	var world=game.world
	world.update_dorm_doors(false,[])
	world.door_open=true
	world.set_gate_guarded(false)
	for gate in world.access_doors: world.set_access_closed(gate.id,false)
	world._changed(true)
	var main=game.actors[0]
	check("bounds_6000x4500",world.bounds==Rect2(0,0,6000,4500))
	check("default_seven_days",game.schedule.escape_days==7 and game.schedule.limit_seconds==6300)
	check("day_stays_fifteen_minutes",game.schedule.day_seconds==900)
	check("single_map_demo",game.room_config.demo_single_map and game.room_selector.disabled)
	check("three_distinct_exits",world.escape_routes.size()==3)
	var document=load("res://scripts/editor/map_document.gd").new()
	check("editable_native_map",document.open_file("res://data/rooms/r04.json"))
	var validation: Dictionary=document.validate()
	check("map_validation",validation.errors.is_empty())
	if not validation.errors.is_empty():print(validation.errors)
	# Cross every real opening in both directions through the doorway body model.
	for port in world.door_passage.portals:
		var r: Rect2=port.rect
		var vertical: bool=r.size.y>r.size.x
		var feet: Vector2=r.get_center()+Vector2(0,-preload("res://scripts/core/actor_footprint.gd").DOOR_BODY.get_center().y if vertical else 0)
		var id=str(port.gate.get("id","free-"+str(int(r.position.x))+"-"+str(int(r.position.y))))
		var walked := false
		# Furniture beside a door may obstruct its geometric centre. Sample
		# along the opening and verify a real two-way route through the jambs.
		# Full shoulder clearance leaves narrow furniture lanes; use 8px samples.
		for along in [0,8,-8,16,-16,24,-24,32,-32,40,-40,48,-48,56,-56,64,-64]:
			if walked:break
			var crossing: Vector2=feet+(Vector2(0,along) if vertical else Vector2(along,0))
			if not world.can_place_circle(crossing,8,main,false,false):continue
			for before in [45,70,100,140]:
				if walked:break
				var start: Vector2=crossing-Vector2(before,0) if vertical else crossing-Vector2(0,before)
				if not world.can_place_circle(start,8,main,false,false):continue
				for after in [120,160,80,200]:
					var goal: Vector2=crossing+Vector2(after,0) if vertical else crossing+Vector2(0,after)
					if not world.can_place_circle(goal,8,main,false,false):continue
					walked=travel(main,start,goal) and travel(main,goal,start)
					if walked:break
		check("door_"+id,walked)
	# Original gameplay destinations remain reachable after translation.
	var home: Vector2=main.home
	var work: Vector2=game.routines._target(0,"work")
	var hall:=Vector2(2300,2420)
	path_walk("home_to_assigned_work",home,work)
	path_walk("work_to_activity_hall",work,hall)
	path_walk("hall_to_meal",hall,point(game.room_config.routine_points.meal[0]))
	path_walk("meal_to_seat",point(game.room_config.routine_points.meal[0]),point(game.room_config.routine_points.dine[0]))
	for id in game.room_config.expansion.review_points:
		path_walk("visit_"+id,hall,point(game.room_config.expansion.review_points[id]))
	for r in world.escape_routes:
		path_walk("exit_approach_"+str(r.id),hall,point(r.approach))
		path_walk("exit_crossing_"+str(r.id),point(r.approach),r.rect.get_center())
	# New room walls stop actual feet, and doors never reveal through a wall.
	main.position=Vector2(1580,800)
	world.move_actor(main,Vector2(-200,0))
	check("clinic_wall_blocks",main.position.x>=1527)
	main.position=Vector2(4400,2700)
	world.set_access_closed("tools-entry",true)
	check("tools_door_blocks_closed",not world.motion_clear(Vector2(3750,2690),Vector2(3910,2690),main,false,true))
	world.set_access_closed("tools-entry",false)

	# Reported stale wall must allow a direct corridor walk, not a detour.
	main.position=Vector2(750,1250)
	world.move_actor(main,Vector2(0,300))
	check("dorm_corridor_direct_south",main.position.distance_to(Vector2(750,1550))<0.1)
	world.move_actor(main,Vector2(0,-300))
	check("dorm_corridor_direct_north",main.position.distance_to(Vector2(750,1250))<0.1)
	var loop=[Vector2(3260,2805),Vector2(3580,2805),Vector2(3580,3260),Vector2(3260,3260),Vector2(2940,3260),Vector2(2940,2805),Vector2(3260,2805)]
	for i in range(loop.size()-1):path_walk("garden_loop_"+str(i),loop[i],loop[i+1])
	for entry in [[Vector2(3260,2540),Vector2(3260,2805)],[Vector2(3260,3490),Vector2(3260,3260)],[Vector2(2640,3050),Vector2(2940,3050)],[Vector2(3910,3050),Vector2(3580,3050)]]:
		path_walk("garden_entry_"+str(entry[0]),entry[0],entry[1])
	for p in [Vector2(2900,2710),Vector2(2800,2900),Vector2(3730,3200),Vector2(3200,3090)]:
		check("planted_bed_blocks_"+str(p),not world.can_place_circle(p,8,main,false,false))
	check("garden_paving_stays_walkable",world.can_place_circle(Vector2(3260,3300),8,main,false,false))

	# Default deadline survives reset; explicit developer overrides stay explicit.
	game.schedule.reset()
	check("reset_keeps_seven_days",game.schedule.escape_days==7)
	game.schedule.set_escape_days(5)
	game.schedule.reset()
	check("explicit_deadline_preserved",game.schedule.escape_days==5)
	game.schedule.set_escape_days(7)
	game.schedule.clock_elapsed=2700.1
	game._process(0)
	check("demo_continues_past_old_three_day_limit",game.phase=="playing")
	game.schedule.clock_elapsed=6300
	game._process(0)
	check("seven_day_deadline_really_settles",game.phase!="playing" and game.schedule.result_panel.visible)
	save_report({"validation":validation,"rooms":game.room_visibility.rooms.size(),"walls":world.walls.size(),"fixtures":world.fixtures.size()})
