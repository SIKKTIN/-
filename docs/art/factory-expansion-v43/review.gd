extends SceneTree
const OUT := "res://docs/art/factory-expansion-v43/"
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
	if not editor.has_method("open_now") or editor.canvas==null:
		push_error("Native editor did not initialize.")
		quit(1);return
	editor.open_now("res://data/rooms/r04.json")
	await frame();await frame()
	if not editor.document.validate().errors.is_empty():
		push_error("Native R04 validation failed.")
		quit(1);return
	for i in range(editor.document.data.fixtures.size()):
		var fixture: Dictionary=editor.document.data.fixtures[i]
		if not str(fixture.asset_id).ends_with("_v43"):continue
		var node=editor.canvas.architecture_preview.nodes["fixture:"+str(i)]
		if not node.display_rect.has_area():
			push_error("Native new prop geometry missing: "+str(fixture.id))
			quit(1);return
	for layer in ["actors","patrol","items","routine","areas"]:editor.layers.set_visible(layer,false)
	editor.category_picker.select(0);editor.rebuild_subcategories()
	editor.subcategory_picker.select(editor.subcategory_ids.find("furnishings"));editor.rebuild_palette()
	await shot(Vector2(2080,1600),0.285,"r04-expanded-editor.png")
	await shot(Vector2(3120,1450),0.55,"warehouse-loading-editor.png")
	await shot(Vector2(1740,2620),0.8,"laundry-equipment-editor.png")
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);editor.hide()
	await frame();game.set_process(false)
	game.load_room("r04",["lockpick","chat","backpack"],52)
	game.routine_panel.close();game.schedule.set_time_speed(0);game.orders.clear()
	game.schedule.clock_elapsed=(960-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.tick(false);game.room_access.tick()
	game.actors[0].position=Vector2(3560,1570)
	game.routines.take_control(0)
	game.map_camera.center_on(Vector2(3630,1300));game.map_camera.following=false
	game.presentation.tick(0);game._update_ui()
	await frame();await frame()
	root.get_texture().get_image().save_png(OUT+"loading-runtime.png")
	game.queue_free();editor.queue_free();await frame()
	print("Saved native full map, warehouse, service rooms and runtime reviews.")
	quit()
