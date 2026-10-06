extends SceneTree

class Contact:
	extends Node2D
	var assets:Array
	var tools:Array
	var loaded:Dictionary
	var font:Font
	func cell(entry:Dictionary,index:int,y0:float,path_key:String) -> void:
		var origin=Vector2(16+(index%7)*156,y0+floori(index/7.0)*116)
		draw_style_box(paper(),Rect2(origin,Vector2(148,106)))
		draw_string(font,origin+Vector2(8,19),entry.name,HORIZONTAL_ALIGNMENT_LEFT,132,14,Color('#303b46'))
		var texture:Texture2D=loaded.get(entry[path_key])
		if texture:
			draw_texture_rect(texture,Rect2(origin+Vector2(8,35),Vector2(48,48)),false)
			draw_texture_rect(texture,Rect2(origin+Vector2(73,26),Vector2(64,64)),false)
		draw_string(font,origin+Vector2(16,100),'48',HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color('#536052'))
		draw_string(font,origin+Vector2(93,100),'64',HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color('#536052'))
	func paper() -> StyleBoxFlat:
		var box=StyleBoxFlat.new()
		box.bg_color=Color('#f2ebdd')
		box.border_color=Color('#7c897c')
		box.set_border_width_all(1)
		box.set_corner_radius_all(8)
		return box
	func _draw() -> void:
		draw_rect(Rect2(0,0,1120,820),Color('#dce2d5'))
		draw_string(font,Vector2(20,32),'A18 · 编辑器图标 · 每卡固定48 / 64像素框',HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color('#303b46'))
		draw_string(font,Vector2(20,59),'14项摆设引用已验收PNG；逻辑点使用专用符号，图标尺寸不改变世界素材尺寸。',HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color('#536052'))
		for i in range(assets.size()): cell(assets[i],i,74,'editor_icon')
		draw_string(font,Vector2(20,333),'操作 / 人物 / 物品 / 日常与区域',HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color('#303b46'))
		for i in range(tools.size()): cell(tools[i],i,348,'icon')

func _initialize() -> void:
	call_deferred('_run')

func _run() -> void:
	root.size=Vector2i(1120,820)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO
	root.content_scale_factor=1.0
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string('res://art/editor/v01/manifest.json'))
	var checks:Dictionary={}
	var textures:Dictionary={}
	var samples:Dictionary={}
	checks['asset_count_14']=manifest.assets.size()==14
	var ids:Dictionary={}
	for entry in manifest.assets: ids[entry.id]=true
	checks['asset_unique_ids']=ids.size()==14
	checks['required_tools']= ['gate_guards','merchants','items','work','meal','dine','free','zones','dorm_doors'].all(func(id): return manifest.tools.any(func(t): return t.id==id))
	for group in ['assets','tools']:
		for entry in manifest[group]:
			var path:String=entry.editor_icon if group=='assets' else entry.icon
			var texture=load(path)
			checks[group+'_'+entry.id+'_load']=texture is Texture2D
			if not texture is Texture2D: continue
			textures[path]=texture
			checks[group+'_'+entry.id+'_square']=is_equal_approx(texture.get_width(),texture.get_height())
			var img:Image=texture.get_image()
			checks[group+'_'+entry.id+'_image']=img!=null
			if not samples.has(path):
				var sample=SubViewport.new()
				sample.size=Vector2i(64,64)
				sample.transparent_bg=true
				sample.world_2d=World2D.new()
				sample.render_target_update_mode=SubViewport.UPDATE_ALWAYS
				root.add_child(sample)
				var icon=TextureRect.new()
				icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
				icon.texture=texture
				icon.size=Vector2(64,64)
				icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				sample.add_child(icon)
				samples[path]=sample
			if group=='assets': checks['category_'+entry.id]=entry.category in ['furniture','cafeteria','props']
	var view=Contact.new()
	view.assets=manifest.assets
	view.tools=manifest.tools
	view.loaded=textures
	view.font=load('res://art/fonts/NotoSansCJKsc-Regular.otf')
	root.add_child(view)
	await process_frame
	await RenderingServer.frame_post_draw
	for group in ['assets','tools']:
		for entry in manifest[group]:
			var path:String=entry.editor_icon if group=='assets' else entry.icon
			if not samples.has(path): continue
			var img:Image=samples[path].get_texture().get_image()
			checks[group+'_'+entry.id+'_transparent']=img.get_pixel(0,0).a<0.01 and img.get_pixel(63,0).a<0.01 and img.get_pixel(0,63).a<0.01 and img.get_pixel(63,63).a<0.01
	var contact=root.get_texture().get_image()
	checks['native_contact_saved']=contact.save_png(ProjectSettings.globalize_path('res://docs/art/a18-icon-contact.png'))==OK
	var failed:Array=checks.keys().filter(func(k): return not checks[k])
	var report={'passed':failed.is_empty(),'check_count':checks.size(),'checks':checks,'failed':failed,'engine':'Godot4.7.2 Windows D3D12','scope':'Actual ResourceLoader Texture2D load, square virtual frame, 64px transparent SubViewport four-corner alpha and native48/64 contact; editor integration owned by producer P51'}
	var file=FileAccess.open('res://docs/art/a18-resource-qa.json',FileAccess.WRITE)
	file.store_string(JSON.stringify(report,'\t')+'\n')
	file.close()
	print('A18_RESOURCE_QA ',JSON.stringify({'passed':report.passed,'checks':checks.size(),'failed':failed}))
	quit(0 if failed.is_empty() else 1)
