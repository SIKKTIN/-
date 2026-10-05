extends SceneTree

const WorldTexture = preload("res://scripts/presentation/world_texture.gd")
var game

func _initialize() -> void:
	call_deferred("run")

func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.load_room("r04",["chat","lockpick","strong"],26)
	game.set_process(false)
	game.map_camera.following = false
	root.grab_focus()
	# Native R04 artwork and actual drawing sizes, isolated from floor/lighting
	# so a static prop's changing brightness cannot come from gameplay or lamps.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(340,160)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var layer := Node2D.new()
	viewport.add_child(layer)
	var results: Array = []
	var montage := Image.create(680,640,false,Image.FORMAT_RGBA8)
	var fixture_index := 0
	var row := 0
	for volume in game.presentation.volumes:
		if volume.kind != "fixture" or volume.prop_id() != "cell_bars" or fixture_index >= 2:
			continue
		var source: Texture2D = load(game.presentation.asset_definitions.cell_bars.texture)
		var region: Array = game.presentation.asset_definitions.cell_bars.region
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		atlas.region = Rect2(region[0],region[1],region[2],region[3])
		atlas.filter_clip = true
		var candidate := WorldTexture.load_asset(game.presentation.asset_definitions.cell_bars)
		for screen_scale in [1.0,0.75]:
			var size: Vector2 = volume.display_rect.size*screen_scale
			for mode in range(2):
				var prop := Node2D.new()
				var texture: Texture2D = atlas if mode == 0 else candidate
				prop.draw.connect(func(): prop.draw_texture_rect(texture,Rect2(Vector2.ZERO,size),false))
				prop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if mode == 0 else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				layer.add_child(prop)
				var luminance: Array = []
				var columns: Array = []
				for step in range(17):
					prop.position = Vector2(60,50)+Vector2(step/16.0,step/16.0)
					await frame()
					var image := viewport.get_texture().get_image()
					var sums: Array = []
					var sum := 0.0
					for x in range(58,ceili(64+size.x)):
						var column := 0.0
						for y in range(48,ceili(54+size.y)):
							var color := image.get_pixel(x,y)
							column += color.r*0.2126+color.g*0.7152+color.b*0.0722
						sums.append(column)
						sum += column
					luminance.append(sum)
					columns.append(sums)
					if step == 8:
						image.convert(Image.FORMAT_RGBA8)
						montage.blit_rect(image,Rect2i(0,0,340,160),Vector2i(mode*340,row*160))
				var ripple := 0.0
				for i in range(1,16):
					for x in range(columns[i].size()):
						ripple += absf(columns[i+1][x]-2*columns[i][x]+columns[i-1][x])
				results.append({"width":size.x,"screen_scale":screen_scale,"mode":"original_linear" if mode == 0 else "cropped_mipmaps_anisotropic","source_has_mipmaps":source.get_image().has_mipmaps(),"candidate_has_mipmaps":candidate.get_image().has_mipmaps(),"brightness_span":luminance.max()-luminance.min(),"column_temporal_second_difference":ripple/(15*columns[0].size()),"brightness_samples":luminance})
				prop.free()
			row += 1
		fixture_index += 1
	var checks: Array = []
	for i in range(0,results.size(),2):
		checks.append(results[i+1].brightness_span < results[i].brightness_span*0.4 and results[i+1].column_temporal_second_difference < results[i].column_temporal_second_difference*0.4)
	var passed: bool = checks.size() == 4 and checks.all(func(v): return v)
	var report := {"passed":passed,"checks":checks,"results":results,"scope":"Native GPU framebuffer: two actual R04 bar draw sizes at 1x/0.75x screen scale, 17 diagonal subpixel phases over one pixel. Frozen isolated props, no light or simulation variation. Brightness span and column second difference quantify sampling instability, not physical scanout or human perception."}
	FileAccess.open("res://docs/tests/p26-bar-sampling.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	montage.save_png("res://docs/tests/p26-bar-sampling.png")
	print(JSON.stringify(report))
	viewport.free()
	game.presentation.stop_all()
	root.remove_child(game)
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
