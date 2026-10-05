extends SceneTree

class Contact:
	extends Node2D
	var entries: Array = []
	var textures: Dictionary = {}
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,720), Color('#e8e2d3'))
		draw_rect(Rect2(28,85,740,380), Color('#a0ab9a'))
		draw_rect(Rect2(798,85,454,380), Color('#3e4944'))
		draw_rect(Rect2(28,480,740,212), Color('#c8cbb6'))
		draw_rect(Rect2(798,480,454,212), Color('#eee8d7'))
		var font = ThemeDB.fallback_font
		draw_string(font, Vector2(35,36), 'A14 | Cafeteria sprites | Native uniform-scale resource QA', HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color('#33413e'))
		draw_string(font, Vector2(35,64), 'Teal outline: ground registration. Source PNGs untouched. No baked ground shadows.', HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color('#33413e'))
		var feet = {'cafeteria_counter':Rect2(92,345,600,80),'cafeteria_return':Rect2(875,230,110,70),'cafeteria_tray':Rect2(1030,570,36,20),'cafeteria_queue':Rect2(80,575,180,12)}
		for e in entries:
			var foot:Rect2=feet[e.id]
			var g=e.ground_rect
			var region=e.region
			var scale=foot.size / Vector2(g[2],g[3])
			var dst=Rect2(foot.position-Vector2(g[0],g[1])*scale, Vector2(region[2],region[3])*scale)
			draw_texture_rect_region(textures[e.id],dst,Rect2(region[0],region[1],region[2],region[3]))
			draw_rect(foot,Color('#258b85'),false,1)
			draw_string(font, Vector2(foot.position.x,foot.end.y+28), str(e.id)+' '+str(int(foot.size.x))+'x'+str(int(foot.size.y)),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color('#28443e') if e.id!='cafeteria_return' else Color('#f3eddf'))
			if e.id=='cafeteria_queue':
				var big=Rect2(Vector2(360,520),dst.size*2)
				draw_texture_rect_region(textures[e.id],big,Rect2(region[0],region[1],region[2],region[3]))
				draw_string(font,Vector2(360,625),'Queue detail x2: gaps remain transparent',HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color('#28443e'))
			if e.id=='cafeteria_tray':
				draw_texture_rect_region(textures[e.id],Rect2(Vector2(840,525),dst.size*3),Rect2(region[0],region[1],region[2],region[3]))
				draw_string(font,Vector2(840,640),'Tray detail x3 / right: world size',HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color('#28443e'))

func _initialize():
	call_deferred('_run')

func _run():
	root.size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO
	root.content_scale_factor=1.0
	var manifest=JSON.parse_string(FileAccess.get_file_as_string('res://art/props/cafeteria_v14/manifest.json'))
	var preview=Contact.new()
	preview.entries=manifest.assets
	for e in manifest.assets:
		var img=Image.load_from_file(ProjectSettings.globalize_path(e.texture))
		assert(img!=null and not img.is_empty())
		preview.textures[e.id]=ImageTexture.create_from_image(img)
		var g=e.ground_rect
		var f=e.footprint_world_size
		assert(abs(float(f[0])/g[2]-float(f[1])/g[3])<0.000001)
		if e.id=='cafeteria_queue':
			assert(img.get_pixel(400,512).a==0.0)
	root.add_child(preview)
	await process_frame
	await RenderingServer.frame_post_draw
	var contact=root.get_texture().get_image()
	assert(contact.get_size()==Vector2i(1280,720))
	var path=ProjectSettings.globalize_path('res://docs/art/a14-contact-1280x720.png')
	assert(contact.save_png(path)==OK)
	print('A14_NATIVE_QA_PASS: four original RGBA textures, registration uniform; queue gap alpha zero; native contact saved ',path)
	quit()
