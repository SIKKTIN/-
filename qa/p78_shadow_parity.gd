extends SceneTree
var checks := {}
var differences := {}
var game
func _initialize() -> void: call_deferred("run")
func capture() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run() -> void:
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r04",["chat","lockpick","backpack"],70)
	game.routine_panel.close()
	game.orders.clear()
	game.get_node("HUD").hide()
	var cached=game.presentation.scene_layers.filter(func(l):return l.kind=="fixture_shadows")[0]
	var reference=load("res://qa/p78_reference_shadows.gd").new()
	game.add_child(reference)
	reference.game=game
	reference.z_index=cached.z_index
	reference.hide()
	for warning in game.presentation.guard_warnings.values(): warning.hide()
	for period in ["day","night"]:
		game.presentation.lighting.set_period(period)
		for point in [Vector2(1340,1016),Vector2(1060,1444),Vector2(2640,950),Vector2(750,1300)]:
			game.actors[0].position=point
			game.room_visibility.tick(0.3)
			game.map_camera.center_on(point)
			game.presentation.tick(0)
			for warning in game.presentation.guard_warnings.values(): warning.hide()
			cached.show()
			reference.hide()
			var actual: Image=await capture()
			cached.hide()
			reference.show()
			reference.queue_redraw()
			var expected: Image=await capture()
			var key: String=str(period)+"-"+str(point)
			var a:=actual.get_data()
			var b:=expected.get_data()
			var bytes_changed:=0
			var max_delta:=0
			for i in range(a.size()):
				if a[i]!=b[i]: bytes_changed+=1; max_delta=maxi(max_delta,absi(int(a[i])-int(b[i])))
			differences[key]={"bytes_changed":bytes_changed,"max_delta":max_delta}
			checks[key]=bytes_changed==0
			reference.hide()
			cached.show()
	var batch_builds: int=cached.fixture_shadow_builds
	game.world.open_door()
	game.presentation.tick(0)
	await capture()
	checks.real_door_change_updates_static_cache=game.presentation.scene_layers.filter(func(l):return l.kind=="ground_static").all(func(l):return l.ground_key[0]==game.world.obstacle_revision)
	checks.door_does_not_rebuild_fixture_geometry=cached.fixture_shadow_builds==batch_builds
	game.reset_round(["chat","lockpick","backpack"],70)
	game.routine_panel.close()
	await capture()
	checks.round_reset_keeps_shadow_batches=cached.shadow_batches.size()>0
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open("res://docs/tests/p78-shadow-parity.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"differences":differences},"\t"))
	print(JSON.stringify({"checks":checks,"failed":failed,"differences":differences}))
	quit(0 if failed.is_empty() else 1)
