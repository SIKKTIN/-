extends SceneTree
func _initialize():call_deferred("run")
func frame():
	await process_frame
	await RenderingServer.frame_post_draw
func run():
	root.size=Vector2i(1600,1000);root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor);await frame();await frame()
	for target in [["before-canteen",Vector2(1660,2290),.8],["before-tools",Vector2(4000,1300),1.0],["before-overview",Vector2(3000,2180),.2]]:
		editor.canvas.zoom=target[2];editor.canvas.origin=editor.canvas.size/2-target[1]*target[2];editor.canvas.queue_redraw();await frame();await frame()
		root.get_texture().get_image().save_png("res://docs/tests/floor-coverage-repair/"+target[0]+".png")
	quit()