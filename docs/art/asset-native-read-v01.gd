extends SceneTree

const ROOT = "E:/Project/Godot/这次怎么逃/"

func _init() -> void:
	var report := {"engine": Engine.get_version_info(), "png": [], "audio": [], "font": {}, "scope": "native resource read only; no main scene or shared code changes"}
	var failed := false
	for folder in ["art/characters", "art/environment", "art/props", "art/ui", "art/fx"]:
		for filename in DirAccess.get_files_at(ROOT + folder):
			if not filename.ends_with(".png"):
				continue
			var image := Image.load_from_file(ROOT + folder + "/" + filename)
			if image == null or image.is_empty():
				failed = true
				continue
			var texture := ImageTexture.create_from_image(image)
			report.png.append({"file": folder + "/" + filename, "width": texture.get_width(), "height": texture.get_height(), "alpha": image.detect_alpha()})
	var font := FontFile.new()
	var font_error := font.load_dynamic_font(ROOT + "art/fonts/NotoSansCJKsc-Regular.otf")
	var missing := []
	for character in "这次怎么逃聊天撬锁力量取消已逃脱":
		if not font.has_char(character.unicode_at(0)):
			missing.append(character)
	report.font = {"load_error": font_error, "missing": missing}
	failed = failed or font_error != OK or not missing.is_empty()
	for filename in DirAccess.get_files_at(ROOT + "audio"):
		if not filename.ends_with(".wav"):
			continue
		var stream := AudioStreamWAV.load_from_file(ROOT + "audio/" + filename)
		if stream == null:
			failed = true
			continue
		report.audio.append({"file": filename, "seconds": stream.get_length(), "mix_rate": stream.mix_rate, "stereo": stream.stereo})
	report.passed = not failed
	var output := FileAccess.open(ROOT + "docs/art/qa-native-read-v01.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print(JSON.stringify({"png": report.png.size(), "audio": report.audio.size(), "font": report.font, "passed": report.passed}))
	quit(1 if failed else 0)
