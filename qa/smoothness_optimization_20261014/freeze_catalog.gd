extends SceneTree
func _initialize():
	var assets: Dictionary=load("res://scripts/presentation/prop_catalog.gd").assets()
	FileAccess.open("res://docs/dev/smoothness-optimization-2026-10-14/catalog-benchmark.json",FileAccess.WRITE).store_string(JSON.stringify(assets))
	print("FROZEN_CATALOG "+str(assets.size()));quit()
