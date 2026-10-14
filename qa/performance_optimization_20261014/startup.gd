extends SceneTree
var begun: int
func _initialize():call_deferred("run")
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_FRAME_MODE","60")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://perf-startup.cfg")
	root.size=Vector2i(1200,720);root.content_scale_size=root.size
	begun=Time.get_ticks_usec()
	var loading=load("res://scenes/loading.tscn").instantiate()
	root.add_child(loading);current_scene=loading
	await process_frame
	await RenderingServer.frame_post_draw
	var visible_ms: float=(Time.get_ticks_usec()-begun)/1000.0
	root.get_texture().get_image().save_png("res://docs/dev/performance-optimization-2026-10-14/loading.png")
	while current_scene==loading and Time.get_ticks_usec()-begun<30000000:await process_frame
	await process_frame;await RenderingServer.frame_post_draw
	var game=current_scene
	var ready: bool=is_instance_valid(game) and game is Node2D and game.get("world")!=null
	var store=load("res://scripts/presentation/runtime_texture_store.gd")
	var report: Dictionary={"ready":ready,"loading_visible_ms":visible_ms,"first_game_frame_ms":(Time.get_ticks_usec()-begun)/1000.0,"texture_mib":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.0,"baked_hits":store.hits,"fallback_misses":store.misses}
	FileAccess.open("res://docs/dev/performance-optimization-2026-10-14/startup.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("STARTUP "+JSON.stringify(report))
	quit(0 if ready and store.misses==0 else 1)
