extends SceneTree
const OUT := "res://docs/art/courtyard-v48/"
var editor
func _initialize():call_deferred("run")
func frame():
	await process_frame
	await RenderingServer.frame_post_draw
func shot(center: Vector2, zoom: float, name: String):
	editor.canvas.zoom=zoom
	editor.canvas.origin=editor.canvas.size/2-center*zoom
	editor.canvas.queue_redraw()
	await frame();await frame()
	root.get_texture().get_image().save_png(OUT+name)
func run():
	root.size=Vector2i(1920,1200)
	root.content_scale_size=root.size
	root.gui_disable_input=true
	editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await frame();await frame()
	editor.open_now("res://data/rooms/r04.json")
	await frame();await frame()
	for layer in ["actors","patrol","items","routine","areas","visibility"]:editor.layers.set_visible(layer,false)
	await shot(Vector2(3260,3050),1.1,"courtyard-editor.png")
	await shot(Vector2(750,1400),1.5,"dorm-corridor-editor.png")
	await shot(Vector2(4500,800),0.95,"admin-editor.png")
	await shot(Vector2(3000,1710),0.85,"second-workshop-editor.png")
	await shot(Vector2(3230,3630),0.6,"courtyard-service-editor.png")
	var vp:=SubViewport.new()
	vp.size=Vector2i(2400,1800)
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var canvas=load("res://scripts/editor/map_canvas.gd").new()
	canvas.size=Vector2(2400,1800)
	vp.add_child(canvas)
	canvas.setup(editor.document,editor.layers)
	canvas.zoom=0.39
	canvas.origin=Vector2(1200,900)-Vector2(3000,2250)*canvas.zoom
	canvas.queue_redraw()
	await frame();await frame();await frame()
	vp.get_texture().get_image().save_png(OUT+"campus-overview.png")
	print("Saved expanded campus with native editor materials.")
	quit()
