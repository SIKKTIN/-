extends SceneTree
const OUT := "res://docs/art/factory-terrain-v46/"
var game
func _initialize() -> void:call_deferred("run")
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	root.size=Vector2i(1200,760);root.content_scale_size=root.size
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await frame();game.set_process(false)
	game.load_room("r04",["strong","chat","backpack"],52)
	game.routine_panel.close();game.schedule.set_time_speed(0);game.orders.clear()
	game.actors[0].position=Vector2(450,420);game.room_visibility.tick(0,true)
	game.map_camera.center_on(Vector2(500,480));game.presentation.tick(0);game._update_ui()
	await frame();await frame()
	root.get_texture().get_image().save_png(OUT+"upright-west-dorm.png")
	game.actors[0].position=Vector2(400,1440);game.room_visibility.tick(0,true)
	game.map_camera.center_on(Vector2(500,1420));game.presentation.tick(0)
	await frame();await frame()
	root.get_texture().get_image().save_png(OUT+"upright-west-confinement.png")
	game.queue_free();await frame();print("Upright terrain native runtime captures saved.");quit()
