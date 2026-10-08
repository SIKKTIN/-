extends SceneTree
var game
var samples: Array=[]
var label:="before"
func _initialize():call_deferred("run")
func percentile(values: Array,q: float) -> float:
 if values.is_empty():return 0
 var sorted=values.duplicate()
 sorted.sort()
 return sorted[mini(sorted.size()-1,floori(sorted.size()*q))]
func stats(values: Array) -> Dictionary:
 return {"mean_ms":values.reduce(func(a,b):return a+b,0.0)/maxi(1,values.size()),"p95_ms":percentile(values,0.95),"p99_ms":percentile(values,0.99),"max_ms":percentile(values,1)}
func scenario(point: Vector2,name: String):
 game.reset_round()
 game.routine_panel.close()
 game.fullscreen_ui.close_menu()
 game.schedule.set_time_speed(0)
 game.schedule.clock_elapsed=(493.0-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
 game.schedule.tick(false)
 game.actors[0].position=point
 game.actors[0].immune_until=0
 for actor in game.actors.slice(1):actor.immune_until=INF
 game.routines.take_control(0)
 game.workshop.update_gate()
 game.workshop.overseer.position=Vector2(game.workshop.config.overseer_start[0],game.workshop.config.overseer_start[1])
 # Keep a real on-duty supervisor instead of the initial shift commute.
 game.staff_traffic.records[game.workshop.overseer.get_instance_id()].status="duty"
 game.workshop.overseer.escaped=false
 game.map_camera.center_on(point)
 game.map_camera.following=false
 for i in range(60):
  await process_frame
  game._process(1.0/60.0)
  await RenderingServer.frame_post_draw
 game.world.path_events.clear()
 game.world.nav_events.clear()
 var intervals: Array=[]
 var work: Array=[]
 var transition: Array=[]
 var last:=Time.get_ticks_usec()
 var saw_chase:=false
 for i in range(300):
  await process_frame
  var now:=Time.get_ticks_usec()
  intervals.append((now-last)/1000.0)
  last=now
  if i==30:game.workshop.warnings[0]=float(game.workshop.config.get("warning_seconds",8))
  var start:=Time.get_ticks_usec()
  game._process(1.0/60.0)
  work.append((Time.get_ticks_usec()-start)/1000.0)
  if i>=30 and i<60:transition.append(work.back())
  saw_chase=saw_chase or game.workshop.overseer.state=="chasing"
  await RenderingServer.frame_post_draw
 var paths: Array=game.world.path_events
 samples.append({"name":name,"frame":stats(intervals),"work":stats(work),"transition":stats(transition),"paths":stats(paths.map(func(p):return p.ms)),"path_calls":paths.size(),"slow_paths":paths.filter(func(p):return p.ms>2),"nav_events":game.world.nav_events,"saw_chase":saw_chase,"supervisor_position":str(game.workshop.overseer.position)})
 print(JSON.stringify(samples.back()))
func run():
 if not OS.get_cmdline_user_args().is_empty():label=OS.get_cmdline_user_args()[0]
 root.size=Vector2i(1200,720)
 root.content_scale_size=root.size
 game=load("res://qa/p87_profile_game.gd").new()
 game.room_id="r04"
 root.add_child(game)
 await process_frame
 game.set_process(false)
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 game.frame_settings.apply(60,false)
 await scenario(Vector2(740,750),"outside_dorm_warning_to_chase")
 await scenario(Vector2(1450,1290),"outside_workshop_warning_to_chase")
 FileAccess.open("res://docs/tests/p87-chase-"+label+".json",FileAccess.WRITE).store_string(JSON.stringify({"samples":samples,"gpu":RenderingServer.get_video_adapter_name(),"map_sha256":FileAccess.get_sha256("res://data/rooms/r04.json")},"\t"))
 quit()
