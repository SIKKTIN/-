extends SceneTree
const OUT := "res://docs/art/energy-south-road-v1/"
func _initialize() -> void:call_deferred("run")
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func shot(name: String) -> void:
	await frame();await frame()
	root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://energy-south-road-preview.cfg")
	root.size=Vector2i(1650,1000);root.content_scale_size=root.size
	var path := "res://data/rooms/r04.json"
	var disk := FileAccess.get_sha256(path)
	var doc=load("res://scripts/editor/map_document.gd").new()
	assert(doc.open_file(path))
	assert(doc.validate().errors.is_empty())
	var game=load("res://scenes/main.tscn").instantiate();game.room_id="r04";root.add_child(game)
	await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.get_node("HUD").hide()
	for actor in game.actors:
		actor.set_process(false);actor.set_physics_process(false);actor.immune_until=INF
	game.guard.position=Vector2(3500,1600);game.dog.position=Vector2(3500,1700)
	game.actors[0].position=Vector2(3690,4045)
	game.room_visibility.tick(0,true);game.presentation.tick(0)
	game.map_camera.following=false;game.map_camera.zoom=Vector2(.5,.5)
	game.map_camera.position=Vector2(3620,3500)-Vector2(root.size);game.map_camera.force_update_scroll()
	game.presentation.tick(0)
	await shot("runtime-paved")
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"before-map.json"))
	var report := {"map_valid":true,"tile_material_loaded":load("res://scripts/presentation/region_terrain.gd").texture("loading_floor_v46","res://art/environment/factory_v46/manifest.json")!=null,
		"existing_obstacles_unchanged":before.fixtures==doc.data.fixtures and before.walls==doc.data.walls and before.access_doors==doc.data.access_doors,
		"south_walkway_route_reachable":not game.world.find_path(Vector2(2380,4040),Vector2(4880,4040),game.actors[0],false,true).is_empty()}
	game.queue_free();await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await frame();await frame();editor.open_now(path);await frame();await frame()
	editor.canvas.zoom=.35;editor.canvas.origin=editor.canvas.size/2-Vector2(3620,3500)*editor.canvas.zoom
	editor.canvas.queue_redraw();await shot("editor-paved")
	report.saved_map_unchanged=FileAccess.get_sha256(path)==disk
	FileAccess.open(OUT+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit()
