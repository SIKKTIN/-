extends SceneTree

class Contact:
	extends Node2D
	var spec: Dictionary
	var atlas: Texture2D
	func sprite(frame: Dictionary, foot: Vector2, height: float, mirror := false) -> void:
		var region: Array = frame.region
		var anchor: Array = frame.anchor
		var s: float = height / float(spec.walk_animation.scale_height)
		draw_line(foot-Vector2(30,0),foot+Vector2(30,0),Color('#258c83'),1)
		draw_set_transform(foot,0,Vector2(-1 if mirror else 1,1))
		draw_texture_rect_region(atlas,Rect2(-Vector2(anchor[0],anchor[1])*s,Vector2(region[2],region[3])*s),Rect2(region[0],region[1],region[2],region[3]))
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	func _draw() -> void:
		draw_rect(Rect2(0,0,1024,640),Color('#e8e2d3'))
		draw_rect(Rect2(20,78,240,440),Color('#b4bfaa'))
		draw_rect(Rect2(275,78,729,440),Color('#899b8b'))
		draw_rect(Rect2(20,535,984,85),Color('#65756b'))
		var f:Font=ThemeDB.fallback_font
		draw_string(f,Vector2(22,32),'A17 | Civilian thug lookout | Original RGBA / stable-foot registration',HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color('#303b46'))
		draw_string(f,Vector2(22,60),'Plain vest, short hair, boots, wooden baton. No cap, badge or uniform. Teal line = foot origin.',HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color('#303b46'))
		var idle={'region':spec.frames.idle,'anchor':spec.anchor.idle}
		sprite(idle,Vector2(140,286),180)
		draw_string(f,Vector2(56,318),'Idle right / x3',HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color('#303b46'))
		sprite(idle,Vector2(140,466),120,true)
		draw_string(f,Vector2(52,497),'Left mirror / x2',HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color('#303b46'))
		for i in range(8):
			var p=Vector2(355+(i%4)*180,260+floori(i/4.0)*220)
			sprite(spec.walk_animation.frames[i],p,150)
			draw_string(f,p+Vector2(-35,25),'walk '+str(i),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color('#303b46'))
			var native_p=Vector2(85+i*120,605)
			sprite(spec.walk_animation.frames[i],native_p,60)
			draw_string(f,native_p+Vector2(-16,17),str(i),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color('#f2ebdd'))

func _initialize() -> void:
	call_deferred('_run')

func _run() -> void:
	root.size=Vector2i(1024,640)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO
	root.content_scale_factor=1.0
	var spec:Dictionary=JSON.parse_string(FileAccess.get_file_as_string('res://art/characters/thug_v17/manifest.json'))
	assert(spec.actor_id=='guard' and spec.world_height==60)
	assert(spec.walk_animation.fps==12 and spec.walk_animation.frames.size()==8)
	var img=Image.load_from_file(ProjectSettings.globalize_path(spec.texture))
	assert(img!=null and img.get_format()==Image.FORMAT_RGBA8)
	var hashes:Array=[]
	for frame in spec.walk_animation.frames:
		var r:Array=frame.region
		var a:Array=frame.anchor
		assert(a[0]>=0 and a[0]<=r[2] and a[1]>=0 and a[1]<=r[3])
		var raw=img.get_region(Rect2i(r[0],r[1],r[2],r[3])).get_data()
		hashes.append(hash(raw))
	assert(hashes.size()==8)
	for i in range(8):
		assert(hashes.count(hashes[i])==1)
	var view=Contact.new()
	view.spec=spec
	view.atlas=ImageTexture.create_from_image(img)
	root.add_child(view)
	await process_frame
	await RenderingServer.frame_post_draw
	var path=ProjectSettings.globalize_path('res://docs/art/a17-native-contact.png')
	assert(root.get_texture().get_image().save_png(path)==OK)
	print('A17_NATIVE_RESOURCE_PASS: RGBA, 8 independent walk crops, common scale, foot anchors and 60-world-size contact. ',path)
	quit()
