extends SceneTree
var game
var report: Dictionary={"cases":{},"transitions":[]}
var tag: String="baseline"
func _initialize():call_deferred("run")
func frame():
	await process_frame
	await RenderingServer.frame_post_draw
func stats(a: Array)->Dictionary:
	if a.is_empty():return {}
	var s:=a.duplicate();s.sort()
	return {"mean":a.reduce(func(x,y):return x+y,0.0)/a.size(),"p95":s[int(s.size()*0.95)],"p99":s[int(s.size()*0.99)],"max":s.back()}
func collect(values: Dictionary,key: String,value: float):
	if not values.has(key):values[key]=[]
	values[key].append(value)
func visit(point: Vector2):
	game.orders.stop(0)
	game.actors[0].position=point
	game.map_camera.center_on(point);game.map_camera.following=false
func sample(label: String,count:=150):
	for i in range(30):await frame()
	var values: Dictionary={};var start:=Time.get_ticks_usec()
	for i in range(count):
		await frame()
		var now:=Time.get_ticks_usec()
		collect(values,"frame_ms",(now-start)/1000.0);start=now
		collect(values,"game_ms",game.profile_total_ms)
		collect(values,"draw_calls",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		collect(values,"engine_process_ms",Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
		for key in game.profile_sections:collect(values,"logic: "+key,game.profile_sections[key])
		for key in game.presentation.profile_times:collect(values,"visual: "+key,game.presentation.profile_times[key])
	var result: Dictionary={}
	for key in values:result[key]=stats(values[key])
	report.cases[label]=result
	print("CASE ",label," ",JSON.stringify({"frame":result.frame_ms,"game":result.game_ms,"draws":result.draw_calls}))
func run():
	if not OS.get_cmdline_user_args().is_empty():tag=OS.get_cmdline_user_args()[0]
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_FRAME_MODE","0")
	OS.set_environment("ESCAPE_FRAME_SETTINGS_PATH","user://android-frame-investigation.cfg")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://android-frame-investigation-dev.cfg")
	root.size=Vector2i(1600,720);root.content_scale_size=root.size
	game=preload("res://qa/android_performance_20261014/game.gd").new()
	game.room_id="r04";root.add_child(game)
	game.schedule.set_time_speed(0);game.actors[0].immune_until=INF
	await sample("spawn")
	visit(Vector2(1640,1900));await sample("outdoor")
	visit(Vector2(1500,1380));await sample("workshop")
	var micro: Dictionary={}
	var actor=game.actors[0]
	var prompt=game.presentation.interaction
	var operations: Dictionary={"keycards_tick":func():game.keycards.tick(),"room_access_tick":func():game.room_access.tick(),"hud_refresh":func():game.fullscreen_ui.refresh(),"interaction_refresh":func():prompt.refresh(),"items":func():prompt._refresh_items(actor),"loot":func():prompt._refresh_loot(actor),"bath":func():prompt._refresh_bath(actor),"npcs":func():prompt._refresh_npcs(actor),"nine_point":func():prompt._refresh_nine_point(actor),"card_nearby_all":func():
		for gate in game.keycards.gates():game.keycards.nearby(actor,gate)
	}
	for key in operations:
		var values: Array=[]
		for i in range(40):
			prompt.targets.clear()
			var begin:=Time.get_ticks_usec();operations[key].call();values.append((Time.get_ticks_usec()-begin)/1000.0)
		micro[key]=stats(values)
	report.micro=micro
	# Synthetic crossings isolate visibility work; these do not validate walking/doors.
	for i in range(12):
		var old_room: String=game.room_visibility.active_id
		visit(Vector2(1640,1900) if i%2==0 else Vector2(1500,1380))
		for first in range(2):
			var start:=Time.get_ticks_usec();await frame()
			report.transitions.append({"crossing":i,"frame":first,"from":old_room,"to":game.room_visibility.active_id,"frame_ms":(Time.get_ticks_usec()-start)/1000.0,"logic":game.profile_sections.duplicate(),"visual":game.presentation.profile_times.duplicate()})
		for wait in range(20):await frame()
	game.tutorial.begin();await sample("tutorial_dialogue")
	game.tutorial.cancel()
	game.get_node("HUD").hide();game.fullscreen_ui.set_process(false)
	await sample("hud_disabled")
	game.set_process(false)
	game.profile_total_ms=0;game.profile_sections.clear();game.presentation.profile_times.clear()
	await sample("simulation_disabled")
	report.renderer=RenderingServer.get_current_rendering_method()
	report.device=RenderingServer.get_video_adapter_name()
	report.scope="Windows GPU, desktop textures, synthetic crossings; not Android performance"
	report.viewport=[1600,720]
	report.baked_misses=preload("res://scripts/presentation/runtime_texture_store.gd").misses
	FileAccess.open("res://docs/performance/android-frame-investigation-20261014/"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("PROFILE_DONE ",tag);game.queue_free();await frame();quit()
