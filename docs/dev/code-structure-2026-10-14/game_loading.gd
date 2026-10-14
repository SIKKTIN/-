extends Control
const Textures=preload("res://scripts/presentation/world_texture.gd")
var progress: ProgressBar
var caption: Label

func _ready() -> void:
	preload("res://scripts/core/frame_settings.gd").new().configure()
	var background:=ColorRect.new()
	background.color=Color("303e40")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center:=CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box:=VBoxContainer.new()
	box.custom_minimum_size=Vector2(420,120)
	box.add_theme_constant_override("separation",18)
	center.add_child(box)
	var title:=Label.new()
	title.text="监狱风云"
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",30)
	title.add_theme_color_override("font_color",Color("eee9d7"))
	box.add_child(title)
	progress=ProgressBar.new()
	progress.custom_minimum_size=Vector2(420,14)
	progress.show_percentage=false
	box.add_child(progress)
	caption=Label.new()
	caption.text="正在准备厂区…"
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size",17)
	box.add_child(caption)
	_start.call_deferred()

func _start() -> void:
	# Show a frame before expensive work. Main stays synchronous for editor
	# playtests, regression harnesses and callers instantiating it directly.
	if DisplayServer.get_name()=="headless":await get_tree().process_frame
	else:await RenderingServer.frame_post_draw
	var requests: Array=_requests()
	var mark: int=Time.get_ticks_usec()
	for i in range(requests.size()):
		Textures.load_asset(requests[i])
		if Time.get_ticks_usec()-mark>=18000:
			progress.value=85.0*(i+1)/maxi(1,requests.size())
			caption.text="加载地面和设施… %d / %d" % [i+1,requests.size()]
			await get_tree().process_frame
			mark=Time.get_ticks_usec()
	progress.value=90
	caption.text="正在初始化角色和地图…"
	if DisplayServer.get_name()=="headless":await get_tree().process_frame
	else:await RenderingServer.frame_post_draw
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _requests() -> Array:
	var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/rooms/r04.json"))
	var args:=OS.get_cmdline_user_args()
	var preview: int=args.find("--editor-room")
	if preview>=0 and preview+1<args.size():
		var parsed=JSON.parse_string(FileAccess.get_file_as_string(args[preview+1]))
		if parsed is Dictionary:config=parsed
	var active: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/active.json"))
	var profile_id: String=OS.get_environment("ESCAPE_ART_PROFILE")
	if profile_id not in ["v01","v02","v03"]:profile_id=str(active.profile)
	var profile: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/"+profile_id+".json"))
	var definitions: Dictionary=preload("res://scripts/presentation/prop_catalog.gd").assets()
	var requests: Dictionary={}
	for field in ["environment","props"]:
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(profile[field]))
		for asset in data.get("assets",[]):
			definitions[str(asset.id)]=asset
			requests[Textures.RuntimeStore.key(asset)]=asset
	for id in preload("res://scripts/presentation/asset_dependencies.gd").ids(config,profile,definitions):
		var asset: Dictionary=definitions[id]
		requests[Textures.RuntimeStore.key(asset)]=asset
	var manifests: Dictionary={}
	for region in config.get("floor_regions",[])+config.get("terrain_patches",[]):
		for pair in [[region.get("asset_id",""),region.get("manifest",config.get("terrain_manifest","res://art/environment/factory_v45/manifest.json"))],[region.get("outline_asset_id",""),region.get("outline_manifest","")]]:
			if str(pair[0]).is_empty() or str(pair[1]).is_empty():continue
			if not FileAccess.file_exists(pair[1]):continue
			if not manifests.has(pair[1]):
				var parsed_manifest=JSON.parse_string(FileAccess.get_file_as_string(pair[1]))
				manifests[pair[1]]=parsed_manifest if parsed_manifest is Dictionary else {}
			for asset in manifests[pair[1]].get("assets",[]):
				if str(asset.id)==str(pair[0]):requests[Textures.RuntimeStore.key(asset)]=asset
	return requests.values()
