extends SceneTree
var game
var report: Dictionary={"cases":{}}
func _initialize():call_deferred("run")
func frame():
 await process_frame
 await RenderingServer.frame_post_draw
func stats(a: Array):
 var s=a.duplicate();s.sort()
 return {"count":a.size(),"mean":a.reduce(func(x,y):return x+y,0.0)/a.size(),"p50":s[s.size()/2],"p95":s[int(s.size()*0.95)],"p99":s[int(s.size()*0.99)],"max":s.back(),"over25":a.filter(func(v):return v>25).size(),"over33":a.filter(func(v):return v>33.333).size()}
func sample(label: String,count: int, warm: int=60):
 var frames: Array=[];var scripts: Array=[];var gpu: Array=[];var cpu: Array=[];var draws: Array=[];var spikes: Array=[];var paths: Array=[];var ticks: Array=[]
 var last:=Time.get_ticks_usec()
 for i in range(count+warm):
  await frame()
  var now:=Time.get_ticks_usec();var ms: float=(now-last)/1000.0;last=now
  if i<warm:continue
  frames.append(ms);scripts.append(game.profile_total_ms)
  cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
  gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
  draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
  var current: Array=game.world.pathfinding.audit_records.duplicate(true)
  for path in current:
   if path.ms>2:paths.append(path)
  if ms>25 or game.profile_total_ms>12:spikes.append({"frame":ms,"script":game.profile_total_ms,"minute":game.schedule.absolute_minutes(),"parts":game.profile_sections.duplicate(),"paths":current})
  if not current.is_empty():ticks.append({"frame":ms,"paths":current})
 report.cases[label]={"frame_ms":stats(frames),"script_ms":stats(scripts),"gpu_ms":stats(gpu),"render_cpu_ms":stats(cpu),"draw_calls":stats(draws),"spikes":spikes,"slow_paths":paths}
 print("CASE "+label+" "+JSON.stringify({"frame":stats(frames),"script":stats(scripts),"slow_paths":paths.size()}))
 FileAccess.open("res://docs/dev/smoothness-2026-10-14/deep-probe.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
func run():
 OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
 OS.set_environment("ESCAPE_FRAME_MODE","60")
 OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://smoothness-dev.cfg")
 OS.set_environment("ESCAPE_FRAME_SETTINGS_PATH","user://smoothness-frame.cfg")
 root.size=Vector2i(1200,720);root.content_scale_size=root.size
 root.title="监狱风云 · 流畅度诊断";root.unfocusable=true
 RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
 game=preload("res://qa/smoothness_20261014/game.gd").new();game.room_id="r04";root.add_child(game)
 await frame()
 game.actors[0].immune_until=INF
 game.map_camera.following=false
 game.map_camera.center_on(game.actors[0].position)
 report.renderer=RenderingServer.get_current_rendering_method()
 report.refresh_hz=DisplayServer.screen_get_refresh_rate()
 report.fixture_count=game.world.fixtures.size();report.wall_count=game.world.walls.size()
 report.initial_texture_mib=Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.0
 await sample("normal60",240)
 game.frame_settings.apply(0,false)
 await sample("uncapped",240)
 game.frame_settings.apply(60,false)
 for minute in [720,1440]:
  game.schedule.clock_elapsed=(float(minute)-1.5-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
  game.schedule.tick(false)
  await sample("transition_"+str(minute),240,0)
 Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
 await sample("vsync",180)
 report.texture_mib=Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.0
 report.baked_hits=preload("res://scripts/presentation/runtime_texture_store.gd").hits
 report.baked_misses=preload("res://scripts/presentation/runtime_texture_store.gd").misses
 FileAccess.open("res://docs/dev/smoothness-2026-10-14/deep-probe.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 print("DIAGNOSIS_DONE")
 game.queue_free();await frame();await frame();quit()
