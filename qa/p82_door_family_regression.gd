extends SceneTree
var game
var checks := {}
var images := []
func _initialize() -> void: call_deferred("run")
func check(label: String, value: bool) -> void:
 checks[label] = value
 print(label+": "+str(value))
func frame() -> void:
 await process_frame
 if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func minute(value: float) -> void:
 game.schedule.clock_elapsed=(value-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
 game.schedule.tick(false)
 game.room_access.tick()
 game.workshop.update_gate()
 game.room_visibility.tick(0.3)
 game.presentation.tick(0)
func show_at(label: String, center: Vector2, inside := Vector2(740,1220), zoom := 1.0) -> void:
 game.actors[0].position=inside
 game.room_visibility.tick(0.3)
 game.presentation.tick(0)
 game.map_camera.following=false
 game.map_camera.zoom=Vector2.ONE*zoom
 game.map_camera.position=center-Vector2(root.size)/game.map_camera.zoom/2
 game.map_camera.force_update_scroll()
 await frame()
 await frame()
 if DisplayServer.get_name() == "headless": return
 var path := "res://docs/tests/p82-family-"+label+".png"
 root.get_texture().get_image().save_png(path)
 images.append(path)
func run() -> void:
 OS.set_environment("ESCAPE_FRAME_MODE","60")
 root.size=Vector2i(1200,720)
 root.content_scale_size=root.size
 game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await frame()
 game.set_process(false)
 game.load_room("r04",["lockpick","chat","backpack"],81)
 game.routine_panel.close()
 game.fullscreen_ui.close_menu()
 game.schedule.set_time_speed(0)
 game.orders.clear()
 game.get_node("HUD").hide()
 for actor in game.actors: actor.immune_until=INF
 var rules=game.room_visibility
 var layer=rules.doorways
 check("all_access_doors_have_views",game.world.access_doors.all(func(g):return layer.by_id(g.id)!=null))
 check("dorm_and_primary_have_views",range(3).all(func(i):return layer.by_id("dorm-%d" % i)!=null) and layer.by_id("primary")!=null)
 check("free_passages_have_end_caps",layer.doors.any(func(d):return d.style=="free"))
 check("formerly_painted_open_gates_now_free_passages",game.world.fixtures.filter(func(f):return str(f.asset_id).begins_with("prison_gate_") and not layer.Geometry.controlled_fixture(f)).all(func(f):return layer.by_id("fixture:"+str(f.id))!=null and layer.by_id("fixture:"+str(f.id)).style=="free"))
 check("three_door_styles",["free","grille","locked"].all(func(s):return layer.doors.any(func(d):return d.style==s)))
 check("confinement_and_maintenance_use_locked_style",["solitary-0","maintenance-entry","laundry-equipment","primary"].all(func(id):return layer.by_id(id).style=="locked"))
 check("cafeteria_and_workshop_use_grille_style",["cafeteria-entry","cafeteria-entry-east","cafeteria-rear","workshop-entry"].all(func(id):return layer.by_id(id).style=="grille"))
 check("door_layer_above_roofs",layer.z_index==4095 and rules.covers.all(func(c):return c.z_index<layer.z_index))
 check("atlas_loaded_once",layer.textures.values().all(func(t):return t!=null))
 check("new_art_has_real_alpha",layer.textures.grille.get_image().detect_alpha()!=Image.ALPHA_NONE)
 check("horizontal_thickness_24",layer.doors.filter(func(d):return d.visual_rect.size.x>d.visual_rect.size.y).all(func(d):return d.depth==24))
 check("vertical_thickness_matches_wall",layer.doors.filter(func(d):return d.visual_rect.size.y>d.visual_rect.size.x and d.style!="free").all(func(d):return d.depth==20 and is_equal_approx(d.rotation,PI/2)))
 check("food_door_at_wall_cap",layer.by_id("cafeteria-entry").visual_rect==Rect2(980,1300,160,24))
 var cafeteria=rules.rooms.filter(func(r):return r.id=="cafeteria-entry-room")[0]
 var north: Array=cafeteria.roof_plan.cutouts.filter(func(c):return c.has_point(Vector2(1060,1310)))
 check("cafeteria_notch_depth_40",north.size()==1 and north[0].size.y==40)
 check("cafeteria_roof_footprint_preserved",cafeteria.roof_plan.roof==Rect2(800,1300,1400,600))
 check("entrance_lintels_not_repainted_above_roof",rules.wall_edges.edges.all(func(e):return e.clips.all(func(c):return not rules.portal_cuts.any(func(p):return c.intersects(p)))))
 minute(719.9)
 check("before_noon_gate_and_view_closed",game.world.access_by_id("cafeteria-entry").closed and layer.by_id("cafeteria-entry").closed)
 var from:=Vector2(1060,1370)
 var to:=Vector2(1060,1455)
 game.actors[0].position=from
 check("closed_cafeteria_still_blocks_motion",not game.world.motion_clear(from,to,game.actors[0]))
 await show_at("cafeteria-closed",Vector2(1180,1340))
 minute(720)
 check("noon_gate_and_view_open",not game.world.access_by_id("cafeteria-entry").closed and not layer.by_id("cafeteria-entry").closed)
 game.actors[0].position=from
 check("noon_cafeteria_passage_walkable",game.world.motion_clear(from,to,game.actors[0]))
 await show_at("cafeteria-open",Vector2(1180,1340))
 await show_at("cafeteria-inside",Vector2(1180,1510),Vector2(1180,1550))
 for actor in game.actors:actor.position=Vector2(740,1200+actor.actor_id*40)
 minute(840)
 check("two_pm_food_closed_again",game.world.access_by_id("cafeteria-entry").closed and layer.by_id("cafeteria-entry").closed)
 check("two_pm_workshop_and_linked_door_close",["workshop-entry","workshop-entry-east"].all(func(id):return game.world.access_by_id(id).closed and layer.by_id(id).closed))
 await show_at("workshop-closed",Vector2(1520,980))
 minute(1080)
 check("six_pm_workshop_opens",not game.world.access_by_id("workshop-entry").closed and not layer.by_id("workshop-entry").closed)
 game.world.set_access_closed("solitary-0",true)
 layer.tick()
 await show_at("confinement-locked",Vector2(680,1430))
 game.room_access.capture(0)
 rules.tick(0.3)
 check("capture_closes_locked_cell",layer.by_id("solitary-0").closed and game.actors[0].confined)
 game.room_access.release(0)
 rules.tick(0.3)
 check("release_retracts_locked_leaf",not layer.by_id("solitary-0").closed and not game.actors[0].confined)
 await show_at("confinement-open",Vector2(680,1430))
 game.world.set_access_closed("maintenance-entry",true)
 game.actors[0].position=Vector2(2100,1945)
 rules.tick(0.3)
 check("maintenance_lockpick_target",game.skills.door_id(game.actors[0])=="maintenance-entry")
 check("maintenance_actual_lockpick_starts",game.skills.toggle(0))
 game.skills.tick(20)
 rules.tick(0.3)
 check("lockpick_opens_both_linked_views",["maintenance-entry","laundry-equipment"].all(func(id):return not game.world.access_by_id(id).closed and not layer.by_id(id).closed))
 game.world.set_access_closed("maintenance-entry",true,true)
 game.actors[0].position=Vector2(2100,1945)
 rules.tick(0.3)
 var key: String = game.inventory.add_ground("door_key",game.actors[0].position)
 check("key_can_be_picked_up",game.inventory.try_pickup(0,key).ok)
 check("actual_key_unlocks",game.inventory.try_use(0,key).ok)
 rules.tick(0.3)
 check("key_consumed_and_linked_views_open",game.inventory.instances[key].location=="consumed" and ["maintenance-entry","laundry-equipment"].all(func(id):return not layer.by_id(id).closed))
 await show_at("maintenance-unlocked",Vector2(1850,2060))
 await show_at("free-passage",Vector2(2600,1130))
 game.presentation.lighting.set_period("night")
 await show_at("cafeteria-night",Vector2(1180,1340))
 game.presentation.lighting.set_period("day")
 await frame()
 var ids: Array=layer.doors.map(func(d):return d.get_instance_id())
 var draws: Array=layer.doors.map(func(d):return d.draw_builds)
 var builds: int=layer.geometry_builds
 var collision: Array=[]
 for i in range(200):collision.append(game.world.can_place_circle(Vector2(120+(i%20)*185,260+floori(i/20.0)*210),17,null,false))
 for i in range(120):
  game.actors[0].position=Vector2(1180,1550) if i%2 else Vector2(740,1220)
  rules.tick(0.3)
  game.presentation.tick(0)
  await frame()
 check("door_nodes_retained_on_room_entry",layer.geometry_builds==builds and ids==layer.doors.map(func(d):return d.get_instance_id()))
 check("door_commands_not_redrawn_on_entry",draws==layer.doors.map(func(d):return d.draw_builds))
 check("door_transition_keeps_collision",range(200).all(func(i):return collision[i]==game.world.can_place_circle(Vector2(120+(i%20)*185,260+floori(i/20.0)*210),17,null,false)))
 check("legacy_door_art_suppressed",game.presentation.volumes.filter(func(v):return v.kind=="fixture" and layer.Geometry.managed_fixture(game.world.fixtures[v.wall_index])).all(func(v):return not v.visible))
 check("map_untouched",FileAccess.get_sha256("res://data/rooms/r04.json")==str(JSON.parse_string(FileAccess.get_file_as_string("res://docs/dev/p82/baseline.json")).map_sha256))
 game.load_room("r04",["lockpick","chat","backpack"],81)
 check("reload_replaces_single_door_layer",game.get_children().filter(func(c):return c.name=="RetainedDoorways").size()==1 and game.room_visibility.doorways.by_id("cafeteria-entry")!=null)
 var failed: Array=checks.keys().filter(func(k):return not checks[k])
 var report: Dictionary={"checks":checks,"failed":failed,"total":checks.size(),"images":images,"door_count":game.room_visibility.doorways.doors.size()}
 var tag:="headless" if DisplayServer.get_name()=="headless" else "native"
 FileAccess.open("res://docs/tests/p82-family-doorways-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 print(JSON.stringify(report))
 quit(0 if failed.is_empty() else 1)
