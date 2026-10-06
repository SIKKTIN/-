extends SceneTree

func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/architecture/v25/manifest.json"))
	var rows: Array = []
	var errors: Array = []
	for asset in manifest.assets:
		var texture: Texture2D = load(asset.texture)
		var icon: AtlasTexture = load(asset.editor_icon)
		if texture == null or icon == null:
			errors.append("Missing texture/icon " + asset.id)
			continue
		var r: Array = asset.region
		var region := Rect2(r[0], r[1], r[2], r[3])
		if icon.region != region or not icon.filter_clip:
			errors.append("Invalid atlas icon " + asset.id)
		if texture.get_size() != Vector2(asset.texture_size[0], asset.texture_size[1]):
			errors.append("Unexpected texture dimensions " + asset.id)
		if not Rect2(Vector2.ZERO, texture.get_size()).encloses(region):
			errors.append("Out-of-bounds region " + asset.id)
		var img := texture.get_image()
		if img == null or img.is_empty():
			errors.append("Unreadable image " + asset.id)
		if asset.id == "cafeteria_return_top_v25" and img.detect_alpha() != Image.ALPHA_NONE:
			errors.append("Opaque material contains alpha " + asset.id)
		rows.append({"id": asset.id, "texture_size": texture.get_size(), "region": region, "icon_size": icon.get_size(), "imported": true})
	var shader: Shader = load("res://art/architecture/v25/safe_edges_v25.gdshader")
	if shader == null:
		errors.append("Missing opaque-core shader")
	var out := {"mode": "isolated Godot import and resource load", "assets_checked": rows.size(), "rows": rows, "errors": errors, "passed": errors.is_empty() and rows.size() == 3}
	var f := FileAccess.open("res://godot-qa.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t") + "\n")
	print(JSON.stringify({"assets_checked": rows.size(), "errors": errors, "passed": out.passed}))
	quit(0 if out.passed else 1)
