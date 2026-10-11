extends SceneTree
const OUT := "res://docs/art/factory-occupations-v48/"
var game
func _initialize() -> void:call_deferred("run")
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	root.size=Vector2i(1280,820);root.content_scale_size=root.size
	var gallery=load(OUT+"gallery.gd").new();root.add_child(gallery)
	await frame();await frame()
	root.get_texture().get_image().save_png(OUT+"native-lineup.png")
	gallery.queue_free();await frame()
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await frame();game.set_process(false)
	game.load_room("r04",["lockpick","chat","backpack"],52);game.schedule.set_time_speed(0)
	game.tutorial.cancel()
	paused=false
	game.room_config.character_appearances={"actor:0":"canteen_cook","actor:1":"clinic_medic","actor:2":"maintenance_technician","guard":"warehouse_clerk","overseer":"truck_driver","merchant:prison_dealer":"cleaner"}
	game.presentation.reset()
	var p: Array=game.room_config.routine_points.get("free",game.room_config.starts)[0]
	var center:=Vector2(p[0],p[1])
	game.actors[0].position=center
	game.actors[1].position=center+Vector2(85,15)
	game.actors[2].position=center+Vector2(175,10)
	game.guard.position=center+Vector2(270,5)
	if game.workshop.overseer!=null:game.workshop.overseer.position=center+Vector2(360,15)
	game.map_camera.center_on(center+Vector2(130,-70));game.map_camera.following=false
	game.trade.actors["prison_dealer"].position=center+Vector2(445,10)
	game.room_visibility.tick(0,true);game.presentation.tick(0)
	game._update_ui();await frame();await frame()
	root.get_texture().get_image().save_png(OUT+"native-game.png")
	game.queue_free();await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await frame();await frame();editor.open_now("res://data/rooms/r04.json")
	editor.document.set_character_appearance({"group":"starts","index":1},"clinic_medic")
	editor.selection={"group":"starts","index":1};editor.canvas.selection=editor.selection;editor.refresh_inspector()
	await frame();await frame()
	var picker=editor.inspector.get_node_or_null("CharacterAppearance")
	print("Native character selector options: ",picker.item_count if picker else -1)
	root.get_texture().get_image().save_png(OUT+"native-editor.png")
	var valid: bool=picker!=null and picker.item_count==15
	editor.queue_free();await frame();quit(0 if valid else 1)
