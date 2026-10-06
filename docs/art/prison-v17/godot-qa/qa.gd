extends SceneTree

const ROOT = "E:/Project/Godot/这次怎么逃"

func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "/art/props/prison_v17/manifest.json"))
	var passed := true
	var reports: Array = []
	var gate: Dictionary = {}
	for asset in manifest.assets:
		var path: String = ROOT + "/" + String(asset.texture).trim_prefix("res://")
		var image := Image.load_from_file(path)
		var r: Array = asset.region
		var rect := Rect2i(r[0], r[1], r[2], r[3])
		var own_image := image.get_region(rect)
		var texture := AtlasTexture.new()
		texture.atlas = ImageTexture.create_from_image(image)
		texture.region = Rect2(rect)
		texture.filter_clip = true
		var g: Array = asset.ground_rect
		var ground := Rect2(g[0], g[1], g[2], g[3])
		var dimensions: Array = asset.footprint_world_size
		var scale_x: float = dimensions[0] / g[2]
		var scale_y: float = dimensions[1] / g[3]
		var inside := Rect2(Vector2.ZERO, Vector2(rect.size)).encloses(ground)
		var valid: bool = not image.is_empty() and FileAccess.get_sha256(path) == asset.sha256 and own_image.get_size() == rect.size and inside and absf(scale_x-scale_y) < 0.000001
		valid = valid and absf(asset.anchor[1] - ground.end.y) < 0.000001
		if asset.render_mode == "wall_attachment":
			valid = valid and not asset.blocking and not asset.interactive and asset.mount_anchor == asset.anchor
		if asset.id == "prison_gate_closed":
			gate = asset
		if asset.id == "prison_gate_open":
			for key in ["ground_rect", "world_size", "anchor", "scale"]:
				valid = valid and asset[key] == gate[key]
			valid = valid and not asset.blocking
		passed = passed and valid
		reports.append({"id": asset.id, "native_image_size": [image.get_width(),image.get_height()], "region_size": [own_image.get_width(),own_image.get_height()], "ground_rect_enclosed": inside, "scale_x": scale_x, "scale_y": scale_y, "passed": valid})
	passed = passed and reports.size() == 9
	var output := {"passed": passed, "assets": reports, "scope": "isolated Godot4.7.2 headless Image/AtlasTexture read, source hash, region, ground registration, isotropic scale and gate-pair check; main-game integration not covered"}
	var file := FileAccess.open(ROOT + "/docs/art/prison-v17/qa-godot-v17.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "  ") + "\n")
	print("A17 native resource QA passed=", passed, " assets=", reports.size())
	quit(0 if passed else 1)
