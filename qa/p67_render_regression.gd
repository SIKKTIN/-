extends SceneTree

const Geometry = preload("res://scripts/presentation/visibility_geometry.gd")
var game
var checks := {}
var draws := {}

func _initialize() -> void:
	call_deferred("run")

func frame() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func legacy_polygon() -> PackedVector2Array:
	var guard = game.guard
	var angles: Array[float] = []
	var base_angle: float = guard.facing.angle()
	var half: float = guard.half_fov()
	for index in range(40 if guard.curfew_alert() else 41):
		angles.append(base_angle-half+2*half*index/40.0)
	for rect in game.world.solid_rects():
		for corner in [rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)]:
			var relative: float = wrapf((corner-guard.position).angle()-base_angle,-PI,PI)
			if absf(relative) < half:
				for epsilon in [-0.0001,0.0,0.0001]: angles.append(base_angle+relative+epsilon)
	angles.sort()
	var polygon := PackedVector2Array() if guard.curfew_alert() else PackedVector2Array([Vector2.ZERO])
	for angle in angles:
		var direction := Vector2.from_angle(angle)
		var distance: float = guard.view_radius()
		var zone: Rect2 = guard.search_zone()
		if absf(direction.x) > 0.00001: distance = minf(distance,((zone.end.x if direction.x>0 else zone.position.x)-guard.position.x)/direction.x)
		if absf(direction.y) > 0.00001: distance = minf(distance,((zone.end.y if direction.y>0 else zone.position.y)-guard.position.y)/direction.y)
		polygon.append(game.world.clip_ray(guard.position,direction,maxf(0,distance))-guard.position)
	return polygon

func record_draw(key: String) -> void:
	draws[key] = int(draws.get(key,0))+1

func run() -> void:
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.load_room("r04",["chat","lockpick","backpack"],67)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 67
	var slabs_ok := true
	for i in range(1000):
		var from := Vector2(rng.randf_range(-20,20),rng.randf_range(-20,20))
		var delta := Vector2(rng.randf_range(-50,50),rng.randf_range(-50,50))
		if i%4 == 0: delta.x = 0
		if i%4 == 1: delta.y = 0
		if i%4 == 2: delta = Vector2.ZERO
		var rect := Rect2(Vector2(rng.randf_range(-25,25),rng.randf_range(-25,25)),Vector2(rng.randf_range(1,20),rng.randf_range(1,20)))
		var old: float = game.world.ray_rect_fraction(from,from+delta,rect)
		var now := Geometry.fraction(from,delta,rect)
		if absf(old-now) > 0.00001: slabs_ok = false
	checks.slab_1000_cases_equivalent = slabs_ok
	var max_error := 0.0
	var cases := 0
	for minute in [600.0,1300.0,1500.0]:
		game.schedule.clock_elapsed = (minute-480)/1440*game.schedule.day_seconds
		game.schedule.tick(false)
		game.room_access.tick()
		for point in [Vector2(560,500),Vector2(1030,1150),Vector2(1010,1300),Vector2(2300,810)]:
			game.guard.position = point
			game.guard.facing = Vector2.from_angle(cases*0.51)
			var old := legacy_polygon()
			var now: PackedVector2Array = game.guard.view_polygon()
			var matches := old.size() == now.size()
			var case_error := 0.0
			if matches:
				for i in range(old.size()): case_error = maxf(case_error,old[i].distance_to(now[i]))
			max_error = maxf(max_error,case_error)
			checks["view_case_%d" % cases] = matches and case_error < 0.001
			cases += 1
	game.schedule.clock_elapsed = 0
	game.schedule.tick(false)
	game.room_access.tick()
	game.map_camera.center_on(Vector2(1010,1230))
	game.presentation.tick(0)
	await frame()
	for i in range(game.presentation.volumes.size()):
		game.presentation.volumes[i].draw.connect(record_draw.bind("volume%d" % i))
	var ground = game.presentation.scene_layers.filter(func(n): return n.kind=="ground_static")[0]
	ground.draw.connect(record_draw.bind("ground"))
	for i in range(5):
		game.presentation.tick(0)
		await frame()
	checks.static_commands_retained = draws.is_empty()
	game.map_camera.center_on(Vector2(1100,1300))
	game.presentation.tick(0)
	await frame()
	checks.camera_does_not_rebuild_static_world = draws.is_empty()
	game.world.set_access_closed("cafeteria-entry",false)
	game.presentation.tick(0)
	await frame()
	var gate = game.presentation.volumes.filter(func(v): return v.kind=="fixture" and game.world.fixtures[v.wall_index].get("access_id","")=="cafeteria-entry")[0]
	checks.gate_asset_changes = gate._visual_asset == str(game.world.fixtures[gate.wall_index].open_asset)
	checks.gate_shadow_invalidated = draws.has("ground")
	draws.clear()
	game.world.set_access_closed("cafeteria-entry",true)
	game.presentation.tick(0)
	await frame()
	checks.gate_closes_without_stale_image = gate._visual_asset == str(game.world.fixtures[gate.wall_index].closed_asset) and not draws.is_empty()
	draws.clear()
	game.world.crate.position += Vector2(5,0)
	game.presentation.tick(0)
	await frame()
	var crate = game.presentation.volumes.filter(func(v): return v.kind=="crate")[0]
	checks.crate_pose_and_shadow_updated = crate.footprint == game.world.crate and draws.has("ground")
	game.select_actor(2)
	game.fullscreen_ui.toggle_bag()
	await frame()
	checks.capacity_switch_immediate = game.inventory_panel.slots[2].visible and game.fullscreen_ui.bag_button.text.contains("0/3")
	var item: String = game.inventory.add_ground("scrap",game.actors[2].position)
	var result: Dictionary = game.inventory.try_pickup(2,item)
	game._update_ui()
	checks.pickup_updates_inventory = result.reason.is_empty() and game.inventory_panel.slots[0].icon == game.items_view.icon_for("scrap") and game.fullscreen_ui.bag_button.text.contains("1/3")
	game.inventory.wallet += 8
	game._update_ui()
	checks.wallet_updates = game.fullscreen_ui.wallet.text == "8"
	var world_point := Vector2(800,600)
	checks.minimap_round_trip = game.mini_map.to_world(game.mini_map.to_map(world_point)).distance_to(world_point) < 0.001
	game.routine_panel.toggle()
	await frame()
	checks.planner_pauses_and_hides_controls = paused and not game.fullscreen_ui.action_button.visible
	game.routine_panel.close()
	await frame()
	checks.resume_restores_controls = not paused and game.fullscreen_ui.action_button.visible
	var failed: Array = checks.keys().filter(func(k): return not checks[k])
	var report := {"checks":checks,"failed":failed,"passed":checks.size()-failed.size(),"total":checks.size(),"max_visibility_error_world_units":max_error,"native":DisplayServer.get_name()!="headless"}
	FileAccess.open("res://docs/tests/p67-render-regression.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failed.is_empty() else 1)
