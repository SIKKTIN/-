extends SceneTree
const OldDialogue=preload("res://docs/performance/android-frame-investigation-20261014/outdoor-baseline/npc_dialogue.gd")
const OUT="res://docs/performance/android-frame-investigation-20261014/"
func _initialize():call_deferred("run")
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://outdoor-hotpaths-qa.cfg")
	var game=load("res://scripts/core/escape_game.gd").new();game.room_id="r04"
	root.add_child(game);await process_frame
	game.set_process(false);game.fullscreen_ui.set_process(false)
	var old=OldDialogue.new();old.game=game;old.config=game.dialogue.config
	var radius: float=game.dialogue.config.range
	var failures: Array=[]
	var points: Array=[Vector2(1640,1900),Vector2(1500,1380),Vector2(2900,1400)]
	for target in old.targets():
		for offset in [0.0,radius-0.01,radius,radius+0.01]:points.append(target.node.position+Vector2(offset,0))
	var rng:=RandomNumberGenerator.new();rng.seed=20261014
	for i in range(100):points.append(Vector2(rng.randf_range(0,6000),rng.randf_range(0,4500)))
	for point in points:
		game.actors[0].position=point;game.room_visibility.tick(0,true)
		var expected: Array=old.targets().filter(func(t):return point.distance_to(t.node.position)<=radius).map(func(t):return t.id)
		var actual: Array=game.dialogue.targets(point,radius).map(func(t):return t.id)
		if expected!=actual:failures.append(str(point))
	var timings: Array=[0,0]
	for i in range(300):
		var point: Vector2=points[i%points.size()]
		for kind in [i%2,1-i%2]:
			var start:=Time.get_ticks_usec()
			if kind==0:old.targets().filter(func(t):return point.distance_to(t.node.position)<=radius)
			else:game.dialogue.targets(point,radius)
			timings[kind]+=Time.get_ticks_usec()-start
	var hud=game.fullscreen_ui
	hud.safe_area();var stamp: int=hud._safe_area_checked_at
	for i in range(120):hud.safe_area()
	var cache_reused: bool=hud._safe_area_checked_at==stamp
	hud._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	var resumed_invalidates: bool=hud._safe_area_checked_at==-1000
	root.size=Vector2i(1600,720);root.content_scale_size=root.size;await process_frame
	hud.layout()
	var resized: bool=hud._safe_area_size==game.get_viewport_rect().size and hud._layout_safe_area==hud.safe_area()
	var report: Dictionary={"target_positions_checked":points.size(),"target_mismatches":failures,"candidate_search_mean_ms":{"before":timings[0]/300000.0,"after":timings[1]/300000.0},"safe_area_cache_reused":cache_reused,"resume_invalidates_safe_area":resumed_invalidates,"resize_updates_safe_area":resized,"scope":"Windows CPU and cache behavior; Android Java call cost and frame pacing not measured"}
	FileAccess.open(OUT+"outdoor-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));old.free();game.queue_free();await process_frame
	quit(0 if failures.is_empty() and cache_reused and resumed_invalidates and resized else 1)
