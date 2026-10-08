extends SceneTree
var game
var checks := {}
var images := []
func _initialize():call_deferred("run")
func check(label: String, value: bool):
 checks[label]=value
 print(label,": ",value)
func frame():
 await process_frame
 if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func shot(label: String, origin: Vector2):
 game.room_visibility.tick(0.3)
 game.presentation.tick(0)
 game.map_camera.following=false
 game.map_camera.zoom=Vector2.ONE
 game.map_camera.position=origin
 game.map_camera.force_update_scroll()
 game.presentation.tick(0)
 await frame()
 await frame()
 if DisplayServer.get_name()=="headless":return
 var path="res://docs/tests/p89-"+label+".png"
 root.get_texture().get_image().save_png(path)
 images.append(path)
func travel(actor, from: Vector2, goal: Vector2) -> bool:
 actor.position=from
 var path: PackedVector2Array=game.world.find_path(from,goal,actor,false,true)
 if path.is_empty():return false
 var before=from
 for target in path:
  for step in range(500):
   var offset: Vector2=target-actor.position
   if offset.length()<1:break
   game.world.move_actor(actor,offset.normalized()*minf(3,offset.length()))
   if before.distance_to(actor.position)<0.001:return false
   before=actor.position
 return actor.position.distance_to(goal)<1
func run():
 root.size=Vector2i(1200,720)
 root.content_scale_size=root.size
 game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await frame()
 game.set_process(false)
 game.load_room("r04",["lockpick","chat","backpack"],85)
 game.routine_panel.close()
 game.schedule.set_time_speed(0)
 game.world.admission_filter=Callable()
 game.get_node("HUD").hide()
 for actor in game.actors:actor.position=Vector2(1100+actor.actor_id*80,2500)
 for gate in game.world.access_doors:game.world.set_access_closed(gate.id,false)
 game.world.update_dorm_doors(false,[])
 var world=game.world
 var rules=game.room_visibility
 var free_door=rules.doorways.by_id("dorm-0")
 check("target_has_free_style",free_door.style=="free")
 check("new_pair_loaded",rules.doorways.load_textures().has_all(["free","grille","locked"]))
 check("free_asset_is_distinct_from_grille",free_door.texture!=rules.doorways.by_id("dorm-1").texture)
 check("target_taller_aperture_keeps_south_wall_join",free_door.visual_rect==Rect2(680,344,20,96))
 check("hardware_inside_aperture",rules.doorways.doors.all(func(d):return d.style=="locked" or d.hardware_rects().all(func(r):return Rect2(0,0,d.length,d.depth).encloses(r))))
 check("target_stays_within_upper_dorm",free_door.visual_rect.end.y<=440)
 var main_for_art=game.actors[0]
 main_for_art.position=Vector2(740,420)
 await shot("free-door-outside",Vector2(180,120))
 var fixed_rect: Rect2=free_door.visual_rect
 var art_builds: int=free_door.draw_builds
 main_for_art.position=Vector2(650,420)
 await shot("free-door-inside",Vector2(180,120))
 check("inside_keeps_same_free_door_rect",fixed_rect==free_door.visual_rect)
 check("room_change_does_not_repaint_free_door",art_builds==free_door.draw_builds)
 var iron=rules.doorways.by_id("dorm-1")
 world.update_dorm_doors(true,[])
 main_for_art.position=Vector2(740,750)
 await shot("iron-door-closed",Vector2(180,460))
 check("iron_closes_and_free_stays_open",iron.closed and not free_door.closed)
 world.update_dorm_doors(false,[])
 await shot("iron-door-open",Vector2(180,460))
 check("iron_open_state_visible",not iron.closed)
 main_for_art.position=Vector2(1000,2500)
 check("foot_radius_8",world.RADIUS==8 and game.ACTOR_RADIUS==8)
 check("main_uses_world_foot_anchor",main_anchor_is_unchanged())
 check("closer_to_wall_than_old_body_circle",world.can_place_circle(Vector2(500,431),world.RADIUS,null,false,false) and not world.can_place_circle(Vector2(500,431),17,null,false,false))
 check("foot_overlap_still_blocked",not world.can_place_circle(Vector2(500,435),world.RADIUS,null,false,false))
 check("fixed_edges_have_solids",world.boundary_solids.size()>0)
 check("every_retained_fragment_has_identical_collision",rules.wall_edges.edges.all(func(e):return e.clips.all(func(c):return c in world.boundary_solids)))
 check("wall_caps_block_both_spatial_indices",world.boundary_solids.all(func(c):return not world.can_place_circle(c.get_center(),1,null,false,false)))
 world.planning_guard_doors=true
 check("inspecting_guards_cannot_ignore_fixed_wall_caps",world.boundary_solids.all(func(c):return not world.can_place_circle(c.get_center(),1,null,false,false)))
 world.planning_guard_doors=false
 var main=game.actors[0]
 main.position=Vector2(500,400)
 world.move_actor(main,Vector2(0,220))
 check("reported_dorm_wall_stops_actual_player_feet",main.position.y<=432.01 and main.position.y>=429)
 await shot("dorm-wall-contact",Vector2(0,100))
 main.position=Vector2(1400,1260)
 world.move_actor(main,Vector2(0,240))
 check("reported_food_wall_stops_actual_player_feet",main.position.y<=1292.01 and main.position.y>=1289)
 await shot("food-wall-contact",Vector2(800,980))
 check("outdoor_routine_markers_resolve_to_corridor",game.room_config.routine_points.free.all(func(p):return world.can_place_circle(world.routine_destination(Vector2(p[0],p[1])),world.RADIUS,null,false,false)))
 main.position=Vector2(520,390)
 check("movement_order_accepts_small_foot_clearance",game.orders.issue(0,Vector2(520,430)))
 game.orders.clear()
 main.position=Vector2(1000,2500)
 var Footprint=load("res://scripts/core/actor_footprint.gd")
 check("independent_full_body_box",Footprint.DOOR_BODY==Rect2(-18,-64,36,68) and world.RADIUS==8)
 check("side_door_taller_than_full_body",free_door.length-16>Footprint.DOOR_BODY.size.y)
 var bad_head=Vector2(690,412)
 var bad_shoes=Vector2(690,430)
 check("feet_alone_fit_bad_head_row",not world.solid_rects().any(func(r):return world._circle_hits_rect(bad_head,8,r)))
 check("head_jamb_prevents_passage",not world.can_place_circle(bad_head,8,main,false) and not world.motion_clear(Vector2(650,412),Vector2(740,412),main,false,true))
 check("lower_jamb_checks_shoes",not world.can_place_circle(bad_shoes,8,main,false))
 main.position=Vector2(740,412)
 world.move_actor(main,Vector2(-90,0))
 check("actual_player_head_stops_before_wall",main.position.x>=718-0.01)
 main.position=Vector2(740,420)
 world.move_actor(main,Vector2(-90,0))
 check("actual_player_full_body_walks_through",main.position.distance_to(Vector2(650,420))<0.01)
 main.position=Vector2(740,420)
 var body_path=world.find_path(Vector2(740,320),Vector2(600,420),main,false,true)
 check("path_uses_full_body_clearance",not body_path.is_empty() and Array(body_path).all(func(p):return world.door_body_clear(p)))
 var cursor=Vector2(740,320)
 var swept=true
 for node in body_path:
  swept=swept and world.motion_clear(cursor,node,main,false,true)
  cursor=node
 check("smoothed_path_sweeps_full_body",swept)
 main.position=Vector2(760,600)
 rules.tick(0,true)
 main.position=Vector2(500,570)
 rules.tick(0,true)
 var upper: Dictionary=rules.rooms.filter(func(r):return r.id=="dorm-0")[0]
 check("head_wall_overlap_fixture",Footprint.body_at(main.position).intersects(upper.enter_area) and not upper.enter_area.has_point(main.position))
 check("head_over_ordinary_wall_cannot_reveal",rules.active_id!="dorm-0")
 main.position=Vector2(693,420)
 rules.tick(0.3,true)
 check("valid_body_entering_door_reveals_room",rules.active_id=="dorm-0")
 await shot("full-body-entering",Vector2(180,120))
 main.position=Vector2(700,420)
 rules.tick(0.3)
 check("roof_waits_until_whole_body_exits",rules.active_id=="dorm-0")
 main.position=Vector2(724,420)
 rules.tick(0.3)
 check("roof_returns_after_full_body_clear",rules.active_id=="")
 main.position=Vector2(1060,1370)
 world.set_access_closed("cafeteria-entry",false)
 world.set_access_closed("cafeteria-entry",true)
 check("door_close_waits_for_head",not world.access_by_id("cafeteria-entry").closed)
 world.move_actor(main,Vector2(0,20))
 world.set_access_closed("cafeteria-entry",true)
 check("door_closes_after_body_clears",world.access_by_id("cafeteria-entry").closed)
 check("closed_leaf_checks_head_not_just_feet",not world.door_body_clear(Vector2(1060,1370)) and world.door_body_clear(Vector2(1060,1390)))
 world.set_access_closed("cafeteria-entry",false)
 check("horizontal_jamb_checks_shoulders",not world.door_body_clear(Vector2(996,1310)) and world.door_body_clear(Vector2(1060,1310)))
 var peer=world.access_by_id("laundry-equipment")
 world.set_access_closed("maintenance-entry",false)
 main.position=Vector2(1740,2380)
 check("linked_peer_fixture_has_real_link",str(peer.get("linked_to",""))=="maintenance-entry" and world.body_overlaps_door(main,peer.rect))
 world.set_access_closed("maintenance-entry",true)
 check("linked_door_waits_for_peer_body",not peer.closed and not world.access_by_id("maintenance-entry").closed)
 world.move_actor(main,Vector2(50,0))
 world.set_access_closed("maintenance-entry",true)
 check("linked_doors_close_after_peer_clears",peer.closed and world.access_by_id("maintenance-entry").closed)
 world.set_access_closed("maintenance-entry",false)
 main.position=Vector2(1000,2500)
 var npc=game.actors[1]
 for id in ["dorm-0","dorm-1","dorm-2","solitary-0","solitary-1","solitary-2"]:
  var view=rules.doorways.by_id(id)
  var center: Vector2=view.visual_rect.get_center()+Vector2(0,28)
  var outside=center+Vector2(50,-100)
  var inside=center-Vector2(170,0)
  check(id+"_npc_walks_in",travel(npc,outside,inside))
  check(id+"_npc_walks_out",travel(npc,inside,outside))
  var left=center-Vector2(50,0)
  var right=center+Vector2(50,0)
  if id.begins_with("dorm-"):world.update_dorm_doors(true,[])
  else:world.set_access_closed(id,true)
  check(id+"_closed_blocks_visible_opening" if id!="dorm-0" else "free_dorm_remains_passable_at_night",not world.motion_clear(left,right,null,false,true) if id!="dorm-0" else world.motion_clear(left,right,null,false,true))
  if id.begins_with("dorm-"):world.update_dorm_doors(false,[])
  else:world.set_access_closed(id,false)
  check(id+"_open_passage_is_clear",world.motion_clear(left,right,null,false,true))
  npc.position=Vector2(1100,2500)
 var old_clock=game.schedule.clock_elapsed
 game.schedule.clock_elapsed=(1500.0-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
 game.schedule.tick(false)
 for actor in game.actors:actor.immune_until=INF
 world.update_dorm_doors(true,[])
 var inspector=game.guard
 inspector.position=Vector2(740,660)
 inspector.release_target()
 inspector.returning_from_inspection=false
 inspector.inspection_route.clear()
 inspector.inspection_route.append(Vector2(600,760))
 inspector.route_index=0
 var inspector_path=world.find_path(inspector.position,Vector2(600,760),inspector,false,true)
 print(JSON.stringify({"night":game.schedule.is_sleep_time(),"inspection":inspector.inspection_allowed(),"start_clear":world.can_place_circle(inspector.position,8,inspector,false),"goal_clear":world.can_place_circle(Vector2(600,760),8,inspector,false),"guard_zone":str(world.guard_zone),"path":str(inspector_path)}))
 check("guard_key_route_keeps_full_body_jambs",not inspector_path.is_empty())
 for step in range(500):
  inspector.tick(0.02)
  if inspector.position.distance_to(Vector2(600,760))<8:break
 print("INSPECTOR END ",inspector.position," state ",inspector.state," path ",inspector.path)
 check("night_guard_physically_passes_body_sized_door",inspector.position.distance_to(Vector2(600,760))<8)
 game.schedule.clock_elapsed=old_clock
 game.schedule.tick(false)
 inspector.inspection_route.clear()
 inspector.position=world.guard_start
 world.update_dorm_doors(false,[])
 check("side_doors_have_shared_body_navigation_centres",world.grid.offset==Vector2(10,10) and world.portal_grid.offset==Vector2.ZERO)
 var food=world.access_by_id("cafeteria-entry")
 world.set_access_closed(food.id,true)
 check("food_closed_blocks_at_visible_wall_not_old_footline",not world.motion_clear(Vector2(1060,1260),Vector2(1060,1365),null,false,true))
 world.set_access_closed(food.id,false)
 check("food_open_npc_walks_to_room",travel(npc,Vector2(1060,1260),Vector2(1060,1500)))
 check("food_open_npc_walks_out",travel(npc,Vector2(1060,1500),Vector2(1060,1260)))
 npc.position=Vector2(1100,2500)
 var locked=world.access_by_id("maintenance-entry")
 world.set_access_closed(locked.id,true)
 main.position=world.door_interaction_point(locked)
 rules.tick(0.3)
 game.presentation.tick(0)
 check("maintenance_interaction_reachable_outside_visible_lock",world.can_place_circle(main.position,world.RADIUS,main,false) and game.skills.door_id(main)==locked.id)
 check("actual_lockpick_with_new_wall_collision",game.skills.toggle(0))
 game.skills.tick(20)
 check("lockpick_opens_linked_doors",not locked.closed and not world.access_by_id("laundry-equipment").closed)
 world.set_access_closed(locked.id,true)
 var key: String=game.inventory.add_ground("door_key",main.position)
 check("key_pickup",game.inventory.try_pickup(0,key).ok)
 check("key_unlock_after_boundary_change",game.inventory.try_use(0,key).ok and not locked.closed)
 game.room_access.capture(0)
 check("confinement_spawn_has_clear_feet",world.can_place_circle(main.position,world.RADIUS,main,false))
 game.room_access.release(0)
 check("confinement_release_lands_on_clear_ground",world.can_place_circle(main.position,world.RADIUS,main,false))
 var solids=world.wall_collision_rects().duplicate()
 var builds: int=world.boundary_builds
 var navigation: int=world.navigation_builds
 for i in range(60):
  main.position=Vector2(500,350) if i%2 else Vector2(740,300)
  rules.tick(0.3)
  game.presentation.tick(0)
  await frame()
 check("room_visibility_keeps_wall_collision",solids==world.wall_collision_rects())
 check("room_visibility_does_not_rebuild_boundaries_or_navigation",builds==world.boundary_builds and navigation==world.navigation_builds)
 check("map_file_unchanged",map_only_target_changed())
 game.load_room("r01",["lockpick","chat","backpack"],85)
 check("legacy_map_has_no_new_modular_boundary",world.boundary_solids.is_empty() and world.boundary_doors.is_empty())
 var failed: Array=checks.keys().filter(func(k):return not checks[k])
 var tag="headless" if DisplayServer.get_name()=="headless" else "native"
 FileAccess.open("res://docs/tests/p89-boundaries-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"total":checks.size(),"images":images},"\t"))
 quit(0 if failed.is_empty() else 1)

func main_anchor_is_unchanged() -> bool:
 var actor=game.actors[0]
 var visual=actor.get_node_or_null("ArtVisual")
 return visual!=null and visual.position==Vector2.ZERO

func map_only_target_changed() -> bool:
 return FileAccess.get_sha256("res://data/rooms/r04.json")==JSON.parse_string(FileAccess.get_file_as_string("res://docs/dev/p89/baseline.json")).map_sha256
