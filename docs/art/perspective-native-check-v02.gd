extends SceneTree

const ROOT := "E:/Project/Godot/这次怎么逃/"

func _init() -> void:
	var delivery: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "docs/art/delivery-v02.json"))
	var report: Dictionary = {"version": delivery.version, "engine": Engine.get_version_info(), "images": [], "scope": "native resource decode; no main scene integration or gameplay validation"}
	var failed: bool = false
	for asset in delivery.assets:
		var image: Image = Image.load_from_file(ROOT + str(asset.folder) + "/" + str(asset.id) + ".png")
		if image == null or image.is_empty():
			failed = true
			continue
		var texture: ImageTexture = ImageTexture.create_from_image(image)
		var dimensions_match: bool = texture.get_width() == int(asset.w) and texture.get_height() == int(asset.h)
		failed = failed or not dimensions_match
		report.images.append({"id": asset.id, "width": texture.get_width(), "height": texture.get_height(), "alpha": image.detect_alpha(), "dimensions_match": dimensions_match})
	report.passed = not failed and report.images.size() == delivery.assets.size()
	var output: FileAccess = FileAccess.open(ROOT + "docs/art/qa-native-v02.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print(JSON.stringify({"version": report.version, "images": report.images.size(), "passed": report.passed}))
	quit(0 if report.passed else 1)
