extends SceneTree
const OUT := "res://docs/art/factory-detail-v44/"
var editor
func _initialize() -> void:call_deferred("run")
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func shot(center: Vector2, zoom: float, filename: String) -> void:
	editor.canvas.zoom=zoom
	editor.canvas.origin=editor.canvas.size/2-center*zoom
	editor.canvas.queue_redraw()
	await frame();await frame()
	root.get_texture().get_image().save_png(OUT+filename)
func run() -> void:
	root.size=Vector2i(1920,1200);root.content_scale_size=root.size
	root.gui_disable_input=true
	editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await frame();await frame()
	editor.open_now("res://data/rooms/r04.json")
	await frame();await frame()
	var validation: Dictionary=editor.document.validate()
	print(JSON.stringify(validation))
	if not validation.errors.is_empty():quit(1);return
	for layer in ["actors","patrol","items","routine","areas","visibility"]:editor.layers.set_visible(layer,false)
	editor.category_picker.select(0);editor.rebuild_subcategories()
	editor.subcategory_picker.select(editor.subcategory_ids.find("furnishings"));editor.rebuild_palette()
	await shot(Vector2(2080,1600),0.24,"r04-detailed-editor.png")
	await shot(Vector2(3240,1460),0.57,"warehouse-loading-editor.png")
	await shot(Vector2(1370,490),0.8,"workshop-editor.png")
	await shot(Vector2(1510,2660),0.8,"laundry-equipment-editor.png")
	# Render the actual editor canvas independently, without surrounding UI.
	var vp:=SubViewport.new();vp.size=Vector2i(2000,1500)
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var canvas=load("res://scripts/editor/map_canvas.gd").new()
	canvas.size=Vector2(2000,1500);vp.add_child(canvas)
	canvas.setup(editor.document,editor.layers)
	canvas.zoom=0.48;canvas.origin=Vector2(1000,750)-Vector2(2080,1600)*canvas.zoom
	canvas.queue_redraw();await frame();await frame();await frame()
	vp.get_texture().get_image().save_png(OUT+"r04-detail-overview.png")
	vp.queue_free()
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);editor.hide()
	await frame();game.set_process(false)
	game.load_room("r04",["lockpick","chat","backpack"],52)
	game.routine_panel.close();game.schedule.set_time_speed(0);game.orders.clear()
	game.schedule.clock_elapsed=(960-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.tick(false);game.room_access.tick()
	game.actors[0].position=Vector2(3700,1570);game.routines.take_control(0)
	game.map_camera.center_on(Vector2(3630,1450));game.map_camera.following=false
	game.presentation.tick(0);game._update_ui()
	await frame();await frame()
	root.get_texture().get_image().save_png(OUT+"loading-runtime.png")
	game.queue_free();editor.queue_free();await frame()
	print("Saved native detailed map and editor/runtime closeups.");quit()
