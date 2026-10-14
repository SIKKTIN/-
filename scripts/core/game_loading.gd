extends Control
const Textures=preload("res://scripts/presentation/world_texture.gd")
const Resources = preload("res://scripts/presentation/presentation_resources.gd")
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
	var config: Dictionary = Resources.read_dictionary("res://data/rooms/r04.json")
	var args:=OS.get_cmdline_user_args()
	var preview: int=args.find("--editor-room")
	if preview>=0 and preview+1<args.size():
		var parsed: Dictionary = Resources.read_dictionary(args[preview+1])
		if not parsed.is_empty(): config=parsed
	return Resources.texture_requests(config,Resources.configuration().profile)
