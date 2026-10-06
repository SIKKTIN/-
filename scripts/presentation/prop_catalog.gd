@tool
extends RefCounted

const FILES := ["res://art/props/prison_v08/manifest.json","res://art/props/cafeteria_v14/manifest.json","res://art/props/manifest-v03.json","res://art/props/prison_v17/manifest.json","res://art/props/security_v19/manifest.json","res://art/architecture/v23/manifest.json","res://art/architecture/v24/manifest.json","res://art/architecture/v25/manifest.json","res://art/architecture/v26/manifest.json","res://art/architecture/v27/manifest.json","res://art/architecture/v28/manifest.json","res://art/architecture/v29/manifest.json"]

static func assets() -> Dictionary:
	var result := {}
	for file in FILES:
		if not FileAccess.file_exists(file): continue
		var manifest = JSON.parse_string(FileAccess.get_file_as_string(file))
		if not manifest is Dictionary: continue
		for entry in manifest.get("assets",[]):
			var asset: Dictionary = entry.duplicate(true)
			if manifest.has("edge_shader") and not asset.has("alpha_core_shader"):
				asset.alpha_core_shader = manifest.edge_shader
			if file.contains("prison_v17") and str(asset.id) == "notice_board": asset.id = "prison_notice_board"
			result[str(asset.id)] = asset
	return result
