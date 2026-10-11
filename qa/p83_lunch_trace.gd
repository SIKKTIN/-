extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.set_process(false)
 game.load_room("r04",["lockpick","chat","backpack"],83)
 game.routine_panel.close()
 game.schedule.set_time_speed(1)
 for actor in game.actors: actor.immune_until=INF
 var last=-1
 for i in range(1500):
  if paused:game.routine_panel.close()
  game._process(0.2)
  var minute=game.schedule.clock_minutes()
  if minute>=720 and minute<811 and int(minute/15)!=last:
   last=int(minute/15)
   for id in [1,2]:
    var rec=game.routines.records.get(id,{})
    var goal=rec.get("goal",Vector2.ZERO)
    print("TRACE ",minute," id=",id," p=",game.actors[id].position," rec=",rec," foodclosed=",game.world.access_by_id("cafeteria-entry").closed," goalclear=",game.world.can_place_circle(goal,17,game.actors[id],false)," blockers=",game.world.solid_rects(false).filter(func(r):return game.world._circle_hits_rect(goal,17,r))," path=",game.world.find_path(game.actors[id].position,goal,game.actors[id]))
  if minute>=811:break
 quit()
