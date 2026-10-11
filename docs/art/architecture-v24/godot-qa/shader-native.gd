extends SceneTree

func _initialize() -> void:
	call_deferred("verify_render")

func verify_render() -> void:
	root.size = Vector2i(512, 384)
	var shader: Shader = load("res://art/architecture/v24/opaque_core.gdshader")
	var item := Sprite2D.new()
	item.texture = load("res://art/architecture/v24/solitary_shell_closed_v24.png")
	item.position = Vector2(256, 192)
	item.scale = Vector2(0.25, 0.25)
	var mat := ShaderMaterial.new()
	mat.shader = shader
	item.material = mat
	root.add_child(item)
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	var saved := screenshot.save_png("res://shader-native.png")
	var result := {"mode": "isolated native Forward+ draw, not headless resource load", "renderer": RenderingServer.get_video_adapter_name(), "image_size": screenshot.get_size(), "screenshot_saved": saved == OK}
	FileAccess.open("res://shader-native.json", FileAccess.WRITE).store_string(JSON.stringify(result, "\t") + "\n")
	print(JSON.stringify(result))
	quit(0 if saved == OK else 1)
