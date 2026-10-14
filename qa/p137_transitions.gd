extends SceneTree
var game
var report: Dictionary={}
var checks: Dictionary={}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p137-qa.cfg")
	game=load("res://scenes/main.tscn").instantiate()
	game.set_script(preload("res://qa/p137_transition_game.gd"))
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.load_room("r04",["chat","chat","backpack"],137)
	game.world.pathfinding=preload("res://qa/p137_transition_navigation.gd").new(game.world)
	game.world.pathfinding._rebuild_navigation()
	game.actors[0].immune_until=INF
	game.schedule.set_time_speed(0)
	for minute in [540,720,840,960,1020,1080,1320,1440,1920]:
		game.schedule.clock_elapsed=(minute-0.05-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
		game._process(0.001)
		clear_metrics()
		game.schedule.set_time_speed(1)
		game._process(0.04)
		game.schedule.set_time_speed(0)
		report[str(minute)]={"script_ms":game.profile_total_ms,"sections":game.profile_sections.duplicate(),"changes_ms":game.world.changed_ms.duplicate(),"walls_ms":game.world.walls_ms.duplicate(),"navigation_ms":game.world.pathfinding.rebuild_ms.duplicate(),"cells_ms":game.world.pathfinding.cells_ms.duplicate(),"sealed_ms":game.world.pathfinding.sealed_ms.duplicate(),"paths":game.world.pathfinding.frame_records.duplicate(true)}
		await process_frame
	# Gate closure must change only affected cells; cached wall geometry is immutable.
	clear_metrics()
	var gate: Dictionary=game.world.access_by_id("workshop-entry")
	for n in range(12):
		game.world.set_access_closed("workshop-entry",not gate.closed,true)
		game.world.pathfinding._rebuild_navigation()
	report["gate_flip"]={"changes_ms":game.world.changed_ms.duplicate(),"walls_ms":game.world.walls_ms.duplicate(),"navigation_ms":game.world.pathfinding.rebuild_ms.duplicate(),"cells_ms":game.world.pathfinding.cells_ms.duplicate(),"refresh_details":game.world.pathfinding.refresh_details.duplicate(true),"finish_ms":game.world.pathfinding.finish_ms.duplicate(),"body_rects":game.world.body_solids.size(),"static_rects":game.world.static_solids.size()}
	checks["unchanged_walls_return_same_geometry"]=game.world.wall_collision_rects()==game.world.wall_collision_rects()
	var label:=OS.get_environment("ESCAPE_PERF_LABEL")
	if label.is_empty():label="after"
	FileAccess.open("res://docs/dev/p137/transitions-"+label+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"cases":report},"\t"))
	for key in report:
		print(key+" "+JSON.stringify(report[key]))
	game.queue_free()
	await process_frame
	quit()
func clear_metrics() -> void:
	game.world.changed_ms.clear()
	game.world.walls_ms.clear()
	game.world.pathfinding.rebuild_ms.clear()
	game.world.pathfinding.cells_ms.clear()
	game.world.pathfinding.refresh_details.clear()
	game.world.pathfinding.finish_ms.clear()
	game.world.pathfinding.sealed_ms.clear()
