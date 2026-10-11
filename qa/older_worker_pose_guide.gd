extends SceneTree
var diagram

class PoseGuide extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(0,0,1600,900),Color("eae7de"))
		for frame in range(8):
			var origin := Vector2(200+400*(frame%4),70+450*(frame/4))
			var phase := float(frame)*TAU/8
			var near_foot := Vector2(65*cos(phase),340-28*maxf(0,sin(phase)))
			var far_foot := Vector2(-65*cos(phase),340-28*maxf(0,-sin(phase)))
			var near_knee := Vector2(near_foot.x*0.6+14*maxf(0,sin(phase)),278)
			var far_knee := Vector2(far_foot.x*0.6+14*maxf(0,-sin(phase)),278)
			var hip := Vector2(0,205)
			# Far leg/arm are brown; near leg/arm are bright orange.
			draw_line(origin+hip,origin+far_knee,Color("77572f"),26,true)
			draw_line(origin+far_knee,origin+far_foot,Color("77572f"),26,true)
			draw_line(origin+far_foot-Vector2(8,0),origin+far_foot+Vector2(24,0),Color("45484b"),20,true)
			draw_line(origin+Vector2(0,100),origin+Vector2(40*cos(phase),191),Color("77572f"),22,true)
			draw_line(origin+Vector2(0,83),origin+hip,Color("d58a27"),70,true)
			draw_line(origin+hip,origin+near_knee,Color("f69b25"),26,true)
			draw_line(origin+near_knee,origin+near_foot,Color("f69b25"),26,true)
			draw_line(origin+near_foot-Vector2(8,0),origin+near_foot+Vector2(24,0),Color("303336"),20,true)
			draw_line(origin+Vector2(0,100),origin+Vector2(-40*cos(phase),191),Color("f69b25"),22,true)
			draw_circle(origin+Vector2(0,37),43,Color("e6b984"))
			draw_circle(origin+Vector2(15,35),5,Color("303336"))
			draw_line(origin+Vector2(26,50),origin+Vector2(36,46),Color("303336"),3,true)
			draw_line(origin+Vector2(-140,352),origin+Vector2(140,352),Color("979990"),2)
			draw_string(ThemeDB.fallback_font,origin+Vector2(-130,387),"POSE %d"%(frame+1),HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("334347"))

func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1600,900)
	diagram = PoseGuide.new()
	root.add_child(diagram)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/dev/older-worker-walk"))
	root.get_texture().get_image().save_png("res://docs/dev/older-worker-walk/pose-guide.png")
	quit()
