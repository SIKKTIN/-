extends SceneTree

const Seating = preload("res://scripts/ui/nine_point_seating.gd")
const OUT := "res://docs/art/nine-point-v2/"

class Stage extends Control:
	var background: Texture2D
	var poses := {}
	var count := 4
	func _draw(): Seating.draw(self,background,poses,count)

func _initialize(): call_deferred("run")

func delta(picture: Image, base: Image, x: int, y: int) -> float:
	var a := picture.get_pixel(x,y)
	var b := base.get_pixel(x,y)
	return Vector3(a.r,a.g,a.b).distance_to(Vector3(b.r,b.g,b.b))

func run():
	root.size = Vector2i(1600,900)
	root.content_scale_size = root.size
	var stage := Stage.new()
	stage.background = load("res://art/ui/nine_point_v1/background.res")
	stage.size = Vector2(1600,900)
	for id in Seating.IDS:
		stage.poses[id] = {}
		for view in ["front","back","side"]: stage.poses[id][view] = load("res://art/ui/nine_point_v2/"+id+"_"+view+".res")
	root.add_child(stage)
	var checks := {}
	for count in [2,3,4]:
		stage.count = count
		stage.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		picture.save_png(OUT+"seating-%dp.png" % count)
		var base := stage.background.get_image()
		checks["%dp north torso visible" % count] = delta(picture,base,800,145) > 0.1
		checks["%dp near torso visible" % count] = delta(picture,base,800,794) > 0.1
		checks["%dp chair back covers near body" % count] = delta(picture,base,800,861) < 0.01
		checks["%dp far knees hidden by tabletop" % count] = delta(picture,base,800,185) < 0.01
		checks["%dp left occupancy" % count] = (delta(picture,base,356,393) > 0.1) == (count >= 3)
		checks["%dp right occupancy" % count] = (delta(picture,base,1242,393) > 0.1) == (count >= 4)
	var failures := []
	for key in checks:
		if not checks[key]: failures.append(key)
	FileAccess.open(OUT+"seating-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failures},"\t"))
	print("Seating checks: ",checks.size()," failed ",failures)
	quit(0 if failures.is_empty() else 1)
