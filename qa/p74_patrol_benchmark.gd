extends SceneTree
const Guard=preload("res://scripts/actors/guard.gd")
var game
var extras: Array=[]
var label := "before"
var samples: Array=[]
var run_ai := true
var simulate_game := true
var information
var previous := 0
var profile := {}
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	await process_frame
	var now:=Time.get_ticks_usec()
	var delta: float=clampf((now-previous)/1000000.0,0,0.1)
	previous=now
	var begin:=Time.get_ticks_usec()
	if simulate_game: game._process(delta)
	var middle:=Time.get_ticks_usec()
	if run_ai:
		for officer in extras: officer.tick(delta)
	var finish:=Time.get_ticks_usec()
	profile.game_ms=(middle-begin)/1000.0
	profile.extra_ai_ms=(finish-middle)/1000.0
	await RenderingServer.frame_post_draw
func mean(v: Array) -> float: return v.reduce(func(a,b): return a+b,0.0)/maxi(1,v.size())
func measure(name: String) -> void:
	var warm:=Time.get_ticks_usec()
	while Time.get_ticks_usec()-warm<1000000: await frame()
	var start:=Time.get_ticks_usec()
	var last:=start
	var times: Array=[]
	var ai: Array=[]
	var main: Array=[]
	var calls: Array=[]
	while Time.get_ticks_usec()-start<4000000:
		await frame()
		var now:=Time.get_ticks_usec()
		times.append((now-last)/1000.0)
		last=now
		ai.append(profile.extra_ai_ms)
		main.append(profile.game_ms)
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	times.sort()
	var result: Dictionary={"name":name,"fps":1000.0/mean(times),"p95_ms":times[floori(times.size()*0.95)],"game_ms":mean(main),"extra_ai_ms":mean(ai),"draw_calls":mean(calls),"extra_count":extras.size()}
	samples.append(result)
	print(JSON.stringify(result))
func set_clock(minute: float) -> void:
	game.schedule.clock_elapsed=(minute-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.room_access.tick()
	game.workshop.update_gate()
	game.routines.tick()
func add_guards(count: int) -> void:
	for i in range(count):
		var officer=Guard.new()
		game.add_child(officer)
		officer.configure(game.world,game)
		for attempt in range(100):
			var point:=Vector2(800+(i%6)*180,860+(i/6)*120)+Vector2(attempt*7,0)
			if game.world.can_place_circle(point,17,officer,false):
				officer.position=point
				break
		extras.append(officer)
		game.prison_alert.reinforcements.append(officer)
		game.gate_watch.attach_visual(officer)
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if not args.is_empty(): label=args[0]
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await RenderingServer.frame_post_draw
	game.set_process(false)
	game.load_room("r04",["lockpick","chat","backpack"],74)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	set_clock(600)
	game.orders.clear()
	for actor in game.actors:
		actor.position=game.routines._target(actor.actor_id,"work")
		game.routines.resume(actor.actor_id)
		actor.immune_until=INF
	game.map_camera.center_on(Vector2(1250,980))
	game.map_camera.following=false
	information=game.presentation.scene_layers.filter(func(n): return n.kind=="information")[0]
	previous=Time.get_ticks_usec()
	await measure("day_4_guards")
	add_guards(12)
	await measure("day_16_guards")
	information.hide()
	await measure("day_16_without_information")
	information.show()
	run_ai=false
	await measure("day_16_without_extra_ai")
	run_ai=true
	set_clock(1500)
	await measure("night_16_guards")
	game.presentation.lighting.hide()
	await measure("night_16_without_lighting")
	game.presentation.lighting.show()
	root.get_texture().get_image().save_png("res://docs/tests/p74-"+label+".png")
	var micros := {}
	var officer=extras[0]
	for method in ["view_polygon","view_mesh"]:
		var begin:=Time.get_ticks_usec()
		for i in range(60):
			officer.position+=Vector2(0.01,0)
			officer.call(method)
		micros[method+"_cold_ms"]=(Time.get_ticks_usec()-begin)/60000.0
	var report: Dictionary={"label":label,"samples":samples,"microbench":micros,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"map_sha256":FileAccess.get_sha256("res://data/rooms/r04.json"),"guard_count":game.guard.warning_officers().size(),"failed":[],"source_guard_sha256":FileAccess.get_sha256("res://scripts/actors/guard.gd")}
	FileAccess.open("res://docs/tests/p74-"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit()
