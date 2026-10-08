extends SceneTree
var game
var checks := {}
var tag := "after"
var images := []
func _initialize() -> void: call_deferred("run")
func frame() -> void:
 await process_frame
 if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
func check(label: String, result: bool) -> void:
 checks[label]=result
 print(label+": "+str(result))
func picture(label: String, point: Vector2, origin: Vector2) -> void:
 game.actors[0].position=point
 game.room_visibility.tick(0.3)
 game.presentation.tick(0)
 game.map_camera.following=false
 game.map_camera.zoom=Vector2.ONE
 game.map_camera.position=origin
 game.map_camera.force_update_scroll()
 await frame()
 await frame()
 if DisplayServer.get_name()=="headless": return
 var path:="res://docs/tests/p82-"+tag+"-"+label+".png"
 root.get_texture().get_image().save_png(path)
 images.append(path)
func run() -> void:
 if not OS.get_cmdline_user_args().is_empty():tag=OS.get_cmdline_user_args()[0]
 root.size=Vector2i(1200,720)
 root.content_scale_size=root.size
 game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await frame()
 game.set_process(false)
 game.load_room("r04",["lockpick","chat","backpack"],82)
 game.routine_panel.close()
 game.get_node("HUD").hide()
 game.schedule.set_time_speed(0)
 game.schedule.clock_elapsed=(610-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
 game.schedule.tick(false)
 game.room_access.tick()
 game.world.update_dorm_doors(false,[])
 game.room_visibility.doorways.tick(true)
 await picture("reported-open-side",Vector2(500,1430),Vector2(0,944))
 game.world.update_dorm_doors(true,[])
 game.room_visibility.doorways.tick(true)
 await picture("reported-closed-side",Vector2(500,1430),Vector2(0,944))
 var rules=game.room_visibility
 var views=rules.doorways
 var expected: Array=[Rect2(680,400,20,40),Rect2(680,740,20,40),Rect2(680,1080,20,60),Rect2(680,1420,20,40),Rect2(680,1740,20,40),Rect2(680,2060,20,60)]
 var ids: Array=["dorm-0","dorm-1","dorm-2","solitary-0","solitary-1","solitary-2"]
 for i in range(ids.size()):
  var door=views.by_id(ids[i])
  check("side_projection_"+ids[i],door.visual_rect==expected[i])
  check("threshold_has_corridor_floor_"+ids[i],door.get("floor_texture")!=null and door.get("floor_asset")=="loading_floor_v46")
 check("dorm_and_confinement_collision_lengths_unchanged",game.world.dorm_doors.all(func(g):return g.rect.size==Vector2(20,120)) and game.world.access_doors.filter(func(g):return g.kind=="confinement").all(func(g):return g.rect.size==Vector2(20,120)))
 var second_wall:=Rect2(680,1140,20,120)
 check("neighbour_facade_not_cut_away",not rules.portal_cuts.any(func(c):return c.intersects(second_wall)))
 var shared_edge=rules.wall_edges.edges.filter(func(e):return e.wall_index==59)
 check("neighbour_original_stone_corner_retained",shared_edge.size()==1 and shared_edge[0].clips.any(func(c):return c.has_point(Vector2(690,1150))))
 check("door_port_not_assigned_to_next_room",rules.rooms.filter(func(r):return r.id=="cell-0")[0].roof_plan.ports.all(func(p):return p.id!="dorm-2"))
 check("only_owner_room_has_each_dorm_port",range(3).all(func(i):return rules.rooms.filter(func(r):return r.roof_plan.ports.any(func(p):return p.id=="dorm-%d" % i)).size()==1))
 check("cafeteria_north_appearance_preserved",views.by_id("cafeteria-entry").visual_rect==Rect2(980,1300,160,24))
 if tag!="before":
  check("trailing_hardware_within_visible_side_span",ids.all(func(id):return views.by_id(id).hardware_end()<=views.by_id(id).length))
  game.world.update_dorm_doors(false,[])
  views.tick(true)
  for shot in [{"id":"dorm-row","inside":Vector2(500,650),"camera":Vector2(0,390)},{"id":"solitary-row","inside":Vector2(500,1730),"camera":Vector2(0,1300)}]:
   await picture(shot.id,shot.inside,shot.camera)
  game.presentation.lighting.set_period("night")
  await picture("night-side",Vector2(500,1430),Vector2(0,944))
  game.presentation.lighting.set_period("day")
  await picture("cafeteria-north",Vector2(740,1220),Vector2(580,980))
  await frame()
  var builds: Array=views.doors.map(func(d):return d.draw_builds)
  var geometry: int=views.geometry_builds
  var solid: Array=[]
  for i in range(200):solid.append(game.world.can_place_circle(Vector2(120+(i%20)*185,260+floori(i/20.0)*210),17,null,false))
  for i in range(60):
   game.actors[0].position=Vector2(500,1430) if i%2 else Vector2(740,1250)
   rules.tick(0.3)
   game.presentation.tick(0)
   await frame()
  check("threshold_commands_cached_on_room_entry",views.geometry_builds==geometry and builds==views.doors.map(func(d):return d.draw_builds))
  check("visibility_keeps_real_collision",range(200).all(func(i):return solid[i]==game.world.can_place_circle(Vector2(120+(i%20)*185,260+floori(i/20.0)*210),17,null,false)))
 check("map_unchanged",FileAccess.get_sha256("res://data/rooms/r04.json")==JSON.parse_string(FileAccess.get_file_as_string("res://docs/dev/p82/baseline.json")).map_sha256)
 var failed: Array=checks.keys().filter(func(k):return not checks[k])
 var report: Dictionary={"checks":checks,"failed":failed,"total":checks.size(),"images":images,"side_doors":ids.map(func(id):return {"id":id,"visual":str(views.by_id(id).visual_rect)})}
 var suffix:="headless" if DisplayServer.get_name()=="headless" else "native"
 FileAccess.open("res://docs/tests/p82-"+tag+"-"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 print(JSON.stringify(report))
 quit(0 if tag=="before" or failed.is_empty() else 1)
