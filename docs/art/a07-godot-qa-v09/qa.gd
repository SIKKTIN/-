extends SceneTree

const ROOT = "E:/Project/Godot/这次怎么逃"

func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "/art/characters/manifest-v09.json"))
	var results: Array = []
	var passed := true
	for actor in manifest.actors:
		var walk: Dictionary = actor.walk_animation
		var file: String = ROOT + "/" + String(walk.texture).trim_prefix("res://")
		var source := Image.load_from_file(file)
		var animation := SpriteFrames.new()
		animation.add_animation("walk")
		animation.set_animation_speed("walk", walk.fps)
		animation.set_animation_loop("walk", true)
		var hashes: Dictionary = {}
		var entries: Array = []
		var actor_passed: bool = not source.is_empty() and FileAccess.get_sha256(file) == walk.sha256
		var atlas := ImageTexture.create_from_image(source)
		var scale_factor: float = actor.world_height / walk.scale_height
		for frame in walk.frames:
			var r: Array = frame.region
			var a: Array = frame.anchor
			var rect := Rect2i(r[0], r[1], r[2], r[3])
			var image := source.get_region(rect)
			var texture := AtlasTexture.new()
			texture.atlas = atlas
			texture.region = Rect2(rect)
			texture.filter_clip = true
			animation.add_frame("walk", texture)
			var hash_value := image.get_data().hex_encode().sha256_text()
			hashes[hash_value] = true
			var low_y := -1
			var high_y := image.get_height()
			for y in image.get_height():
				for x in image.get_width():
					if image.get_pixel(x, y).a > 32.0 / 255.0:
						low_y = maxi(low_y, y + 1)
						high_y = mini(high_y, y)
			var foot_error: float = absf((low_y - a[1]) * scale_factor)
			var valid := image.get_size() == rect.size and foot_error < 0.000001
			actor_passed = actor_passed and valid
			entries.append({"id": frame.id, "region_size": [rect.size.x, rect.size.y], "anchor": a, "scale": scale_factor, "visible_world_height": (low_y-high_y)*scale_factor, "foot_world_error": foot_error, "passed": valid})
		actor_passed = actor_passed and hashes.size() == 8 and animation.get_frame_count("walk") == 8 and animation.get_animation_speed("walk") == 12.0 and animation.get_animation_loop("walk")
		passed = passed and actor_passed
		results.append({"actor_id": actor.actor_id, "distinct_region_images": hashes.size(), "passed": actor_passed, "frames": entries})
	var output := {"passed": passed, "actors": results, "scope": "isolated headless Godot Image/AtlasTexture/SpriteFrames resource and shared-scale foot registration check; main-game integration pending producer"}
	var file := FileAccess.open(ROOT + "/docs/tests/a07-qa-godot-v09.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "  ") + "\n")
	print("A07 native resource QA passed=", passed, " actors=", results.size())
	quit(0 if passed else 1)
