extends SceneTree
const OUT := "res://docs/art/asset-cleanup-20261007/"
var checks: Array = []
func check(label: String, result: bool) -> void:
	checks.append({"name":label,"passed":result})
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var assets: Dictionary = load("res://scripts/presentation/prop_catalog.gd").assets()
	var aliases: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/props/legacy-aliases.json")).aliases
	var catalog = load("res://scripts/editor/editor_catalog.gd").new()
	var world_texture = load("res://scripts/presentation/world_texture.gd")
	for id in assets:
		check("source exists: "+str(id), FileAccess.file_exists(str(assets[id].texture)))
	for id in aliases:
		var target: String = str(aliases[id])
		check("legacy alias uses replacement: "+str(id), assets.has(id) and assets[id].texture == assets[target].texture and assets[id].region == assets[target].region)
		check("legacy ID hidden; replacement placeable: "+str(id), not catalog.is_placeable(id) and catalog.is_placeable(target))
		check("legacy alias shares current texture cache: "+str(id), world_texture.load_asset(assets[id]) == world_texture.load_asset(assets[target]) and world_texture.load_asset(assets[id]) != null)
	for entry in catalog.entries:
		if entry.get("icon","") != "":
			check("palette icon exists: "+str(entry.id), ResourceLoader.exists(entry.icon))
	check("live carried meal tray preserved",assets.has("cafeteria_tray") and world_texture.load_asset(assets.cafeteria_tray) != null)
	var receipt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT+"receipt.json"))
	for path in receipt.map_sha256:
		check("map file unchanged: "+str(path),FileAccess.get_sha256("res://"+path)==receipt.map_sha256[path])
	for item in receipt.files:
		check("retired source removed: "+str(item.path),not FileAccess.file_exists("res://"+item.path))
		check("external archive byte-identical: "+str(item.path),FileAccess.get_sha256(receipt.archive+"/files/"+item.path)==item.sha256)
	var editor = load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	editor.open_now("res://data/rooms/r04.json")
	await process_frame
	check("native R04 editor validates",editor.document.validate().errors.is_empty())
	check("native R04 editor loads every fixture texture",editor.document.data.fixtures.all(func(f):return editor.canvas.textures.has(f.asset_id) and editor.canvas.textures[f.asset_id] != null))
	var failed: Array = checks.filter(func(c):return not c.passed)
	var report := {"checks":checks,"passed":checks.size()-failed.size(),"failed":failed}
	var output := FileAccess.open(OUT+"checks.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify({"passed":report.passed,"failed":failed}))
	editor.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
