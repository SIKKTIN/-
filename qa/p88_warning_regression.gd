extends SceneTree
var checks: Dictionary = {}
class SightWorld extends RefCounted:
 var obstacle_revision := 0
 var crate := Rect2()
 var rects: Array[Rect2] = []
 var roof := false
 func is_under_roof(_point): return roof
 func nearby_sight(_point,_radius): return rects
class Officer extends Node2D:
 var world = SightWorld.new()
 var facing := Vector2.RIGHT
 var state := "chasing"
 var half := PI
 func view_radius(): return 110.0
 func search_zone(): return Rect2(-1000,-1000,2000,2000)
 func half_fov(): return half
 func alert_mode(): return false
var officer = Officer.new()
var warning
func _initialize(): call_deferred("run")
func check(name,ok):
 checks[name]=ok
 print(name+": "+str(ok))
func image_frame() -> Image:
 await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func refresh(): warning.refresh(Rect2(0,0,400,400),true,true)
func run():
 root.size=Vector2i(400,400)
 root.content_scale_size=root.size
 RenderingServer.set_default_clear_color(Color.BLACK)
 root.add_child(officer)
 officer.position=Vector2(200,200)
 warning=load("res://scripts/presentation/guard_warning.gd").new()
 root.add_child(warning)
 warning.configure(officer)
 for i in range(64):officer.world.rects.append(Rect2(160,160,5,5))
 refresh()
 var sparse=await image_frame()
 check("64_uniform_path",not warning.use_texture and warning.blockers.size()==64)
 warning._upload_blockers()
 warning.shader_material.set_shader_parameter("use_blocker_texture",true)
 var textured=await image_frame()
 check("uniform_texture_pixel_parity",sparse.get_data()==textured.get_data())
 check("open_east_visible",sparse.get_pixel(270,200).r>0.03)
 officer.world.rects.append(Rect2(240,180,10,40))
 officer.world.obstacle_revision+=1
 refresh()
 var dense=await image_frame()
 dense.save_png("res://docs/tests/p88-warning-dense.png")
 print(JSON.stringify({"root":str(root.size),"image":str(dense.get_size()),"occluded":str(dense.get_pixel(270,200)),"outside":str(dense.get_pixel(320,200))}))
 check("65_texture_path",warning.use_texture and warning.blockers.size()==65)
 check("65th_blocker_occludes",dense.get_pixel(270,200).r<0.003)
 check("east_before_wall_visible",dense.get_pixel(225,200).r>0.03)
 check("north_unblocked",dense.get_pixel(200,130).r>0.03)
 check("radius_exterior_hidden",dense.get_pixel(320,200).r<0.003)
 var texture=warning.blocker_texture
 officer.world.rects[64]=Rect2(180,240,40,10)
 officer.world.obstacle_revision+=1
 refresh()
 var moved=await image_frame()
 check("stationary_observer_obstacle_updates",moved.get_pixel(270,200).r>0.03 and moved.get_pixel(200,270).r<0.003)
 check("texture_reused",warning.blocker_texture==texture)
 for i in range(200):officer.world.rects.append(Rect2(160,160,5,5))
 officer.world.rects[64]=Rect2(160,160,5,5)
 officer.world.rects[264]=Rect2(180,240,40,10)
 officer.world.obstacle_revision+=1
 refresh()
 var expanded=await image_frame()
 check("265_blockers_not_truncated",warning.blockers.size()==265 and warning.blocker_image.get_width()>=265)
 check("265th_blocker_clips_after_texture_growth",expanded.get_pixel(270,200).r>0.03 and expanded.get_pixel(200,270).r<0.003)
 officer.world.rects.resize(1)
 officer.world.obstacle_revision+=1
 refresh()
 var reduced=await image_frame()
 check("dense_to_sparse_no_stale_blocker",not warning.use_texture and reduced.get_pixel(200,270).r>0.03)
 officer.half=PI/3
 refresh()
 var cone=await image_frame()
 check("night_cone_direction",cone.get_pixel(270,200).r>0.03 and cone.get_pixel(130,200).r<0.003)
 officer.world.roof=true
 refresh()
 check("roof_hides_warning",not warning.visible)
 officer.world.roof=false
 warning.refresh(Rect2(0,0,400,400),false,true)
 check("information_toggle_hides_warning",not warning.visible)
 var backend := "opengl" if OS.get_cmdline_user_args().has("opengl") else "d3d12"
 FileAccess.open("res://docs/tests/p88-warning-"+backend+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"backend":backend,"gpu":RenderingServer.get_video_adapter_name()},"\t"))
 quit(0 if checks.values().all(func(v):return v) else 1)
