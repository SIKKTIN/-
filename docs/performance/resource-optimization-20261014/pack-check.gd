extends SceneTree
func _initialize():call_deferred("run")
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://pack-smoke-qa.cfg")
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;game.set_process(false)
	var store=load("res://scripts/presentation/runtime_texture_store.gd")
	var checks: Dictionary={"main_scene_ready":game.world!=null,"room_json_in_pack":game.room_id=="r04","runtime_index_present":FileAccess.file_exists("res://art/runtime_textures/index.json"),"baked_resources_used":store.hits>=300,"no_stale_bake_fallback":store.misses==0,"qa_excluded":not ResourceLoader.exists("res://qa/dorm_door_interaction.gd"),"dev_reports_excluded":not FileAccess.file_exists("res://docs/dev/performance-audit-2026-10-14/report.txt"),"dev_json_excluded":not FileAccess.file_exists("res://docs/dev/performance-audit-2026-10-14/forward_plus.json")}
	for room in ["r01","r02","r03","r04"]:
		checks["load_room_"+room]=game.load_room(room,["chat","chat","backpack"],136)
		await process_frame;await process_frame
		checks["exit_icon_"+room]=game.world.art_textures.has("exit_v01")
	checks["no_fallback_after_all_maps"]=store.misses==0
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	var output: Dictionary={"checks":checks,"failed":failed,"baked_hits":store.hits,"baked_misses":store.misses}
	FileAccess.open("E:/Project/Godot/这次怎么逃/docs/performance/resource-optimization-20261014/pack-smoke.json",FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	print("PACK_SMOKE "+JSON.stringify(output));game.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
