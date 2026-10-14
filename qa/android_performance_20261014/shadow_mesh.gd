extends SceneTree
var game
var out="res://docs/performance/android-frame-investigation-20261014/"
func _initialize():call_deferred("run")
func frame():
	await process_frame
	await RenderingServer.frame_post_draw
func freeze(node: Node):
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func run():
	if RenderingServer.get_current_rendering_method()!="gl_compatibility":out+="shadow-forwardplus/"
	DirAccess.make_dir_recursive_absolute(out)
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_FRAME_MODE","0")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://shadow-mesh-parity.cfg")
	root.size=Vector2i(1600,720);root.content_scale_size=root.size
	game=load("res://scripts/core/escape_game.gd").new();game.room_id="r04"
	root.add_child(game);await frame();freeze(game)
	game.get_node("HUD").hide();game.orders.stop(0)
	var actual=game.presentation.scene_layers.filter(func(l):return l.kind=="fixture_shadows")[0]
	var reference=load("res://docs/performance/android-frame-investigation-20261014/workshop-baseline/scene_layers.gd").new()
	game.add_child(reference);game.move_child(reference,actual.get_index()+1)
	reference.configure(game,game.presentation,"fixture_shadows");reference.hide()
	var cases: Dictionary={}
	for period in ["day","night"]:
		game.presentation.lighting.set_period(period)
		for entry in [{"id":"workshop","point":Vector2(1500,1380)},{"id":"outside","point":Vector2(1640,1900)},{"id":"workshop_two","point":Vector2(2900,1400)}]:
			game.actors[0].position=entry.point
			game.room_visibility.tick(0,true);game.map_camera.center_on(entry.point);game.presentation.tick(0)
			reference.sync_shadow_visibility()
			actual.show();reference.hide();await frame();await frame()
			var picture_a:=root.get_texture().get_image()
			var draw_a:=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			actual.hide();reference.show();await frame();await frame()
			var picture_b:=root.get_texture().get_image()
			var draw_b:=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			var label: String=period+"-"+entry.id
			picture_a.save_png(out+"mesh-"+label+".png");picture_b.save_png(out+"reference-"+label+".png")
			cases[label]={"after_draws":draw_a,"before_draws":draw_b}
	var builds: int=actual.fixture_shadow_builds
	game.world.open_door();game.presentation.tick(0)
	var report: Dictionary={"cases":cases,"door_keeps_shadow_geometry":actual.fixture_shadow_builds==builds,"mesh_count":actual.shadow_meshes.size()}
	FileAccess.open(out+"shadow-mesh-check.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));game.queue_free();await frame();quit()
