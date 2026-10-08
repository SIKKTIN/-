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
func shot(label: String, point: Vector2, camera: Vector2):
 game.actors[0].position=point
 game.room_visibility.tick(0.3)
 game.presentation.tick(0)
 game.map_camera.following=false
 game.map_camera.zoom=Vector2.ONE
 game.map_camera.position=camera
 game.map_camera.force_update_scroll()
 await frame()
 await frame()
 if DisplayServer.get_name()=="headless":return
 var path="res://docs/tests/p86-"+label+".png"
 root.get_texture().get_image().save_png(path)
 images.append(path)
func run():
 root.size=Vector2i(1200,720)
 root.content_scale_size=root.size
 game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await frame()
 game.set_process(false)
 game.load_room("r04",["lockpick","chat","backpack"],86)
 game.routine_panel.close()
 game.schedule.set_time_speed(0)
 game.world.admission_filter=Callable()
 game.get_node("HUD").hide()
 for actor in game.actors:actor.position=Vector2(1100+actor.actor_id*80,2500)
 game.world.update_dorm_doors(false,[])
 var world=game.world
 var views=game.room_visibility.doorways
 var door=views.by_id("dorm-0")
 check("free_type_and_aperture_unchanged",door.style=="free" and door.visual_rect==Rect2(680,400,20,40))
 check("all_caps_remain_inside_apertures",views.doors.all(func(d):return d.style=="locked" or d.hardware_rects().all(func(r):return Rect2(0,0,d.length,d.depth).encloses(r))))
 check("main_can_cross_free_entrance",world.motion_clear(Vector2(640,420),Vector2(740,420),null,false,true))
 await shot("free-outside",Vector2(740,410),Vector2(180,120))
 var builds: int=door.draw_builds
 var geometry: int=views.geometry_builds
 var solids=world.wall_collision_rects().duplicate()
 var navigation: int=world.navigation_builds
 await shot("free-inside",Vector2(650,390),Vector2(180,120))
 check("entry_keeps_door_commands_cached",builds==door.draw_builds and geometry==views.geometry_builds)
 check("entry_keeps_physics_and_navigation",solids==world.wall_collision_rects() and navigation==world.navigation_builds)
 world.update_dorm_doors(true,[])
 views.tick()
 check("free_remains_open_at_night",not door.closed and world.motion_clear(Vector2(640,420),Vector2(740,420),null,false,true))
 var iron=views.by_id("dorm-1")
 check("iron_still_blocks_when_closed",iron.closed and not world.motion_clear(Vector2(640,760),Vector2(740,760),null,false,true))
 await shot("iron-closed",Vector2(740,750),Vector2(180,460))
 world.update_dorm_doors(false,[])
 views.tick()
 check("iron_still_opens",not iron.closed and world.motion_clear(Vector2(640,760),Vector2(740,760),null,false,true))
 await shot("iron-open",Vector2(740,750),Vector2(180,460))
 var baseline: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/dev/p86/baseline.json"))
 check("map_is_byte_unchanged",FileAccess.get_sha256("res://data/rooms/r04.json")==baseline.map_sha256)
 check("original_free_sprite_unchanged",FileAccess.get_sha256("res://art/architecture/doorways_v49/free.png")==baseline.free_png_sha256)
 var failed: Array=checks.keys().filter(func(k):return not checks[k])
 var tag="headless" if DisplayServer.get_name()=="headless" else "native"
 FileAccess.open("res://docs/tests/p86-door-readability-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"total":checks.size(),"images":images},"\t"))
 quit(0 if failed.is_empty() else 1)
