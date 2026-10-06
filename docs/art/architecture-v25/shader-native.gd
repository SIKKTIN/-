extends SceneTree

class SampleCanvas extends Node2D:
	var portal: Texture2D
	var top: Texture2D
	func _draw() -> void:
		# Repeated TOP view; full front pillar is never used along this run.
		for step in range(3):
			draw_texture_rect(top, Rect2(24, 12 + step * 128, 24, 128), false)
		# North wall has original transparent fringe: exercise new alpha transfer.
		draw_texture_rect_region(portal, Rect2(100, 42, 288, 243), Rect2(140, 172, 573, 375))
		# Opaque body of end face and original transparent doorway both rendered.
		draw_texture_rect_region(portal, Rect2(24, 396, 24, 90), Rect2(200, 259, 74, 288))
		draw_texture_rect_region(portal, Rect2(430, 60, 150, 200), Rect2(837, 259, 407, 288))

func _initialize() -> void:
	call_deferred("verify_render")

func verify_render() -> void:
	root.size = Vector2i(640, 512)
	RenderingServer.set_default_clear_color(Color("929d87"))
	var canvas := SampleCanvas.new()
	canvas.portal = load("res://art/architecture/v24/cafeteria_portal_v24.png")
	canvas.top = load("res://art/architecture/v25/cafeteria_return_top_v25.png")
	var mat := ShaderMaterial.new()
	mat.shader = load("res://art/architecture/v25/safe_edges_v25.gdshader")
	canvas.material = mat
	root.add_child(canvas)
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var saved := img.save_png("res://shader-native.png")
	var result := {"mode": "isolated native Forward+ draw", "renderer": RenderingServer.get_video_adapter_name(), "image_size": img.get_size(), "screenshot_saved": saved == OK}
	FileAccess.open("res://shader-native.json", FileAccess.WRITE).store_string(JSON.stringify(result, "\t") + "\n")
	print(JSON.stringify(result))
	quit(0 if saved == OK else 1)
