extends SceneTree
var game
var report: Dictionary = {"cases":{}}
func _initialize(): call_deferred("run")
func frame():
 await process_frame
 await RenderingServer.frame_post_draw
func stats(a: Array) -> Dictionary:
 if a.is_empty():return {}
 var s: Array=a.duplicate();s.sort()
 var total: float=0
 for v in a:total+=v
 return {"mean":total/a.size(),"p50":s[s.size()/2],"p95":s[int(s.size()*0.95)],"p99":s[int(s.size()*0.99)],"max":s.back()}
func sample(label: String, count: int = 240):
 var frames: Array=[];var scripts: Array=[];var draws: Array=[]
 var gpu: Array=[];var render_cpu: Array=[]
 var sections: Dictionary={};var visuals: Dictionary={};var spikes: Array=[]
 var last: int=Time.get_ticks_usec()
 for i in range(count+60):
  await frame()
  var now: int=Time.get_ticks_usec();var ms: float=(now-last)/1000.0;last=now
  if i<60:continue
  frames.append(ms);scripts.append(game.profile_total_ms)
  draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
  gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
  render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
  for k in game.profile_sections:
   if not sections.has(k):sections[k]=[]
   sections[k].append(game.profile_sections[k])
  for k in game.presentation.profile_times:
   if not visuals.has(k):visuals[k]=[]
   visuals[k].append(game.presentation.profile_times[k])
  if ms>33:spikes.append({"frame":ms,"script":game.profile_total_ms,"parts":game.profile_sections.duplicate()})
 var result: Dictionary={"frames":count,"frame_ms":stats(frames),"game_script_ms":stats(scripts),"draw_calls":stats(draws),"parts":{},"visual_parts":{},"spikes":spikes.slice(0,20),"texture_mib":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.0}
 for k in sections:result.parts[k]=stats(sections[k])
 for k in visuals:result.visual_parts[k]=stats(visuals[k])
 report.cases[label]=result
 result.render_cpu_ms=stats(render_cpu);result.render_gpu_ms=stats(gpu)
 print("AUDIT_CASE "+label+" "+JSON.stringify(result))
func visit(p: Vector2):
 game.actors[0].position=p
 game.map_camera.center_on(p);game.map_camera.following=false
 game.room_visibility.tick(0,true)
func run():
 OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
 OS.set_environment("ESCAPE_FRAME_MODE","0")
 OS.set_environment("ESCAPE_FRAME_SETTINGS_PATH","user://audit-20261014-frame.cfg")
 OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://audit-20261014-dev.cfg")
 root.size=Vector2i(1200,720);root.content_scale_size=root.size
 RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
 var start: int=Time.get_ticks_usec()
 game=preload("res://qa/performance_optimization_20261014/game.gd").new()
 game.room_id="r04"
 root.add_child(game)
 report.startup_ready_ms=(Time.get_ticks_usec()-start)/1000.0
 await frame()
 report.first_frame_ms=(Time.get_ticks_usec()-start)/1000.0
 report.world_configure_ms=game.world.audit_configure_ms
 game.schedule.set_time_speed(0)
 game.actors[0].immune_until=INF
 await visit(game.actors[0].home)
 await sample("dorm_idle")
 game.tutorial.begin();game.tutorial.step_id="follow_work";game.tutorial.dialogue_ready=false
 await sample("tutorial_escort")
 game.tutorial.cancel()
 await visit(Vector2(1640,1750))
 await sample("workshop_apron_same_baseline")
 await visit(Vector2(1500,1380))
 await sample("workshop_interior")
 game.schedule.clock_elapsed=(840.0-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
 game.schedule.tick(false)
 await sample("afternoon_work")
 game.schedule.clock_elapsed=(1441.0-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
 game.schedule.tick(false)
 await visit(game.actors[0].home)
 await sample("night_dorm")
 game.schedule.clock_elapsed=0;game.schedule.tick(false)
 await visit(Vector2(1640,1750))
 game.schedule.set_time_speed(1)
 game.frame_settings.apply(60,false)
 await sample("cap60_running",900)
 game.frame_settings.apply(0,false)
 await sample("uncapped_running",600)
 game.actors[0].immune_until=0
 game.schedule.clock_elapsed=(21*60.0-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
 game.schedule.tick(false)
 game.guard.position=game.actors[0].position+Vector2(150,0)
 game.guard.state="chasing";game.guard.target_id=0
 await sample("night_chase",300)
 game.set_process(false);game.profile_total_ms=0;game.profile_sections.clear();game.presentation.profile_times.clear()
 await sample("frozen_simulation")
 var textures: Array=[];var seen: Dictionary={}
 for key in preload("res://scripts/presentation/world_texture.gd").cache:
  var t: Texture2D=preload("res://scripts/presentation/world_texture.gd").cache[key]
  if t==null or seen.has(t.get_rid()):continue
  seen[t.get_rid()]=true
  textures.append({"key":key,"width":t.get_width(),"height":t.get_height(),"estimated_rgba_mips_mib":t.get_width()*t.get_height()*16.0/3/1048576})
 textures.sort_custom(func(a,b):return a.estimated_rgba_mips_mib>b.estimated_rgba_mips_mib)
 report.textures=textures
 report.resources={"texture_mib":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.0,"static_mib":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"walls":game.world.walls.size(),"fixtures":game.world.fixtures.size(),"roof_cells":game.world.roofed_cells.size(),"texture_cache_count":textures.size()}
 report.renderer=RenderingServer.get_current_rendering_method();report.driver=RenderingServer.get_current_rendering_driver_name()
 report.viewport=[1200,720];report.cap=Engine.max_fps
 report.baked_hits=preload("res://scripts/presentation/runtime_texture_store.gd").hits
 report.baked_misses=preload("res://scripts/presentation/runtime_texture_store.gd").misses
 FileAccess.open("res://docs/dev/performance-optimization-2026-10-14/"+report.renderer+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 print("AUDIT_DONE "+JSON.stringify(report.resources))
 game.queue_free();await frame();await frame();quit()
