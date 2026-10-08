extends SceneTree
var game
var checks: Dictionary = {}
func _initialize():call_deferred("run")
func check(name,ok):
 checks[name]=ok
 print(name+": "+str(ok))
func run():
 OS.set_environment("ESCAPE_FRAME_SETTINGS_PATH","user://p88-test-frame-settings.cfg")
 OS.set_environment("ESCAPE_FRAME_MODE","60")
 game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.set_process(false)
 game.routine_panel.close()
 game.schedule.set_time_speed(0)
 game.schedule.clock_elapsed=(600.0-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
 game.schedule.tick(false)
 game.presentation.lighting.set_period("day")
 game.workshop.update_gate()
 check("preset60",Engine.max_fps==60 and game.frame_settings.target_fps==60)
 var speed=game.schedule.time_speed
 var physics=Engine.physics_ticks_per_second
 game.frame_settings.apply(90,false)
 check("preset90",Engine.max_fps==90 and game.frame_settings.target_fps==90)
 check("presets_keep_clock_and_physics",game.schedule.time_speed==speed and Engine.physics_ticks_per_second==physics)
 game.frame_settings.apply(60,false)
 # P79 cafeteria coordinates now intersect fixtures. Use the clear corridor.
 game.actors[0].position=Vector2(740,600)
 game.actors[0].immune_until=0
 for actor in game.actors.slice(1):actor.immune_until=INF
 game.routines.take_control(0)
 game.workshop.grace[0]=0
 game.guard.position=Vector2(740,750)
 game.guard.release_target()
 check("fixture_clear_feet_and_sight",game.world.can_place_circle(game.actors[0].position,8,game.actors[0]) and game.world.can_place_circle(game.guard.position,8,game.guard) and game.world.line_clear(game.guard.position,game.actors[0].position))
 game.world.begin_ai_paths()
 game.world.ai_path_spent_usec=1000
 game.guard.tick(0.01)
 game.world.end_ai_paths()
 check("detection_immediate_even_when_path_budget_spent",game.guard.state=="chasing" and game.guard.target_id==0)
 for officer in game.gate_watch.guards:
  game.staff_traffic.records[officer.get_instance_id()].status="duty"
  officer.position=Vector2(740,750)
  officer.release_target()
  officer.tick(0.01)
  check("labor_chase_"+str(officer.guard_id),officer.state=="chasing" and officer.target_id==0)
 var overseer=game.workshop.overseer
 game.staff_traffic.records[overseer.get_instance_id()].status="duty"
 overseer.position=Vector2(740,650)
 game.workshop.wanted[0]=true
 overseer.tick(0.1)
 check("supervisor_actual_capture",game.actors[0].confined and game.confinement_counts[0]==1)
 for count in range(2):
  game.room_access.release(0)
  game.actors[0].immune_until=0
  game.capture_actor(0)
 check("third_capture_fails",game.phase=="failed" and game.confinement_counts[0]==3)
 var failed=checks.keys().filter(func(k):return not checks[k])
 FileAccess.open("res://docs/tests/p88-gameplay-regression.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
 quit(0 if failed.is_empty() else 1)
