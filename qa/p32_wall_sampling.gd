extends SceneTree

const Volume = preload("res://scripts/presentation/world_volume.gd")
var game
var checks := {}

func _initialize() -> void:
	call_deferred("run")

func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	root.grab_focus()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(160,300)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var results: Array = []
	var montage := Image.create(480,1200,false,Image.FORMAT_RGBA8)
	var row := 0
	for index in [0,9]:
		for screen_scale in [1.0,0.75]:
			var baseline_image: Image
			for mode in range(3):
				var profile: Dictionary = game.presentation.profile.duplicate(true)
				profile.wall_outline_aa = mode > 0
				profile.wall_side_gradient = mode > 1
				var wall = Volume.new()
				viewport.add_child(wall)
				wall.configure(game.world,"wall",index,profile,game.presentation.asset_definitions)
				if wall.footprint.size.x > 24:
					push_error("Fixture must be a thin vertical wall")
					quit(2)
					return
				wall.scale = Vector2.ONE*screen_scale
				var base: Vector2 = Vector2(64,64)-wall.footprint.position*screen_scale
				var width: float = wall.footprint.size.x*screen_scale
				var luminance: Array = []
				var columns: Array = []
				var interior_error := 0.0
				for step in range(17):
					wall.position = base+Vector2(step/16.0,step/16.0)
					await frame()
					var image := viewport.get_texture().get_image()
					var sums: Array = []
					var sum := 0.0
					for x in range(60,mini(ceili(68+width),image.get_width())):
						var column := 0.0
						for y in range(96,220):
							var color := image.get_pixel(x,y)
							column += color.r*0.2126+color.g*0.7152+color.b*0.0722
						sums.append(column)
						sum += column
					luminance.append(sum)
					columns.append(sums)
					if step == 8:
						image.convert(Image.FORMAT_RGBA8)
						montage.blit_rect(image,Rect2i(0,0,160,300),Vector2i(mode*160,row*300))
						if mode == 0:
							baseline_image = image.duplicate()
						else:
							for x in range(66,floori(64+width-4*screen_scale-1)):
								for y in range(96,220):
									var difference := image.get_pixel(x,y)-baseline_image.get_pixel(x,y)
									interior_error = maxf(interior_error,maxf(absf(difference.r),maxf(absf(difference.g),absf(difference.b))))
				var ripple := 0.0
				for phase in range(1,16):
					for column in range(columns[phase].size()):
						ripple += absf(columns[phase+1][column]-2*columns[phase][column]+columns[phase-1][column])
				results.append({"wall_index":index,"width":width,"screen_scale":screen_scale,"mode":["baseline","outline_aa","outline_aa_gradient"][mode],"brightness_span":luminance.max()-luminance.min(),"column_temporal_second_difference":ripple/(15*columns[0].size()),"interior_max_rgb_error":interior_error,"samples":luminance})
				wall.free()
			row += 1
	for index in range(0,results.size(),3):
		checks["ripple_"+str(index)] = results[index+2].column_temporal_second_difference < results[index].column_temporal_second_difference*0.5
		checks["brightness_span_"+str(index)] = results[index+2].brightness_span < results[index].brightness_span*0.7
		checks["unchanged_interior_"+str(index)] = results[index+2].interior_max_rgb_error < 1.0/255
	var report := {"checks":checks,"passed":checks.values().all(func(x): return x),"results":results,"scope":"Native GPU, exact R04 long 24-unit and cell 16-unit wall commands; 1/.75 screen scales; 17 diagonal fractional-pixel phases. Cropped middle of wall isolates edges and side texture without camera/lighting variation. Framebuffer metrics do not prove physical display or human perception."}
	FileAccess.open("res://docs/tests/p32-wall-sampling.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	montage.save_png("res://docs/tests/p32-wall-sampling.png")
	for result in results:
		print(result.wall_index," scale=",result.screen_scale," ",result.mode," span=",result.brightness_span," ripple=",result.column_temporal_second_difference)
	viewport.free()
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if report.passed else 1)
