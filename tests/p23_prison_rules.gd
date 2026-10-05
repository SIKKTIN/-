extends SceneTree

var game
var checks := {}
var metrics := {}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r04",["backpack","lockpick","strong"],23)
	var world = game.world
	checks.three_prison_zones = game.room_config.zones.size() == 3
	checks.seven_fixture_types = ["bunk_bed","cell_bars","toilet_sink","workbench","tool_locker","communal_table","notice_board"].all(func(id): return world.fixtures.any(func(f): return f.asset_id == id))
	checks.fixtures_in_bounds = world.fixtures.all(func(f): return world.bounds.encloses(f.rect))
	checks.homes_free = game.actors.all(func(a): return world.can_place_circle(a.home,17,a,false))
	checks.cargo_free = game.room_config.items.all(func(i): return world.can_place_circle(Vector2(i.position[0],i.position[1]),17,null,false))
	checks.merchant_free = world.can_place_circle(Vector2(540,650),17,null,false)
	checks.guard_waypoints_free = world.patrol.all(func(p): return world.can_place_circle(p,17,game.guard,false))
	checks.fixture_collision = world.fixtures.filter(func(f): return f.blocks_movement).all(func(f): return not world.can_place_circle(f.rect.get_center(),17,null,false))
	var bed: Rect2 = world.fixtures.filter(func(f): return f.id == "bed_0")[0].rect
	checks.see_across_bed = world.line_clear(Vector2(bed.position.x-5,bed.get_center().y),Vector2(bed.end.x+5,bed.get_center().y))
	var bars: Rect2 = world.fixtures.filter(func(f): return f.id == "bars_left_0")[0].rect
	checks.see_through_bars = world.line_clear(bars.get_center()-Vector2(0,30),bars.get_center()+Vector2(0,30))
	checks.cannot_walk_through_bars = not world.motion_clear(bars.get_center()-Vector2(0,30),bars.get_center()+Vector2(0,30))
	var locker: Rect2 = world.fixtures.filter(func(f): return f.id == "locker_0")[0].rect
	checks.locker_blocks_sight = not world.line_clear(locker.get_center()-Vector2(80,0),locker.get_center()+Vector2(80,0))
	checks.locker_clips_ray = world.clip_ray(locker.get_center()-Vector2(80,0),Vector2.RIGHT,160).distance_to(Vector2(locker.position.x,locker.get_center().y)) < 0.01
	checks.only_high_fixtures_occlude = world.sight_rects().size() == world.walls.size()+2+3
	checks.all_solid_fixtures_in_navigation = world.solid_rects().size() == world.walls.size()+2+23
	game.presentation.lighting.tick()
	checks.real_lights_use_sight_obstacles = game.presentation.lighting.occluders.size() == world.sight_rects().size()
	checks.ten_room_lamps = game.presentation.lighting.lamps.size() == 10
	for id in range(3):
		var route: PackedVector2Array = world.find_path(game.actors[id].home,Vector2(540,970),game.actors[id],false)
		checks["cell_"+str(id)+"_has_doorway_route"] = not route.is_empty()
	checks.safe_to_workshop = not world.find_path(Vector2(540,970),Vector2(1020,310),null,false).is_empty()
	checks.workshop_to_hall = not world.find_path(Vector2(1020,310),Vector2(1430,1250),null,false).is_empty()
	checks.exit_initially_blocked = world.find_path(Vector2(1780,760),Vector2(2000,760),null,false).is_empty()
	world.open_door()
	checks.open_door_reaches_exit = not world.find_path(Vector2(1780,760),world.exit_area.get_center(),null,false).is_empty()
	game.load_room("r04",["backpack","lockpick","strong"],23)
	var transitions := 0
	var previous: int = game.guard.route_index
	var within_zone := true
	var mobile := true
	for tick in range(7200):
		game.elapsed += 1.0/60
		game.guard.tick(1.0/60)
		within_zone = within_zone and game.guard.movement_allowed(game.guard.position)
		mobile = mobile and game.guard.stalled_time < 2
		if previous != game.guard.route_index:
			transitions += 1
			previous = game.guard.route_index
	checks.guard_two_minutes_no_stall = mobile and transitions >= 8
	checks.guard_stays_in_supervised_zone = within_zone
	checks.safe_cell_undetected = game.captures == 0 and game.guard.state == "patrol"
	metrics.patrol_transitions_120s = transitions
	metrics.fixture_count = world.fixtures.size()
	metrics.sight_fixture_count = 3
	game.presentation.lighting.set_period("night")
	checks.night_shorter_sight = game.guard.view_radius() == 155
	game.presentation.lighting.set_period("day")
	checks.day_longer_sight = game.guard.view_radius() == 210
	for room in ["r01","r02","r03"]:
		game.load_room(room,["chat","lockpick","strong"],23)
		checks[room+"_legacy_obstacles_unchanged"] = world.fixtures.is_empty() and world.sight_rects() == world.solid_rects()
	var passed: bool = checks.values().all(func(value): return value == true)
	var file := FileAccess.open("res://docs/tests/p23-prison-rules.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"metrics":metrics,"scope":"Physics/navigation/sight and continuous 120s guard AI at 60Hz; art registration and rendered/mobile checks are separate."},"\t"))
	print(JSON.stringify({"passed":passed,"checks":checks,"metrics":metrics}))
	quit(0 if passed else 1)
