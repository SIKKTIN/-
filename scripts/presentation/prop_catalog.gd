@tool
extends RefCounted

const FILES := ["res://art/props/prison_v08/manifest.json","res://art/props/cafeteria_v14/manifest.json","res://art/props/manifest-v03.json","res://art/props/prison_v17/manifest.json","res://art/props/security_v19/manifest.json","res://art/architecture/v23/manifest.json"]

static func assets() -> Dictionary:
	var result := {}
	for file in FILES:
		if not FileAccess.file_exists(file): continue
		var manifest = JSON.parse_string(FileAccess.get_file_as_string(file))
		if not manifest is Dictionary: continue
		for entry in manifest.get("assets",[]):
			var asset: Dictionary = entry.duplicate(true)
			if file.contains("prison_v17") and str(asset.id) == "notice_board": asset.id = "prison_notice_board"
			result[str(asset.id)] = asset
	return result
