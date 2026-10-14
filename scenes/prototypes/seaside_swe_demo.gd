extends Control
## Independent validation scene: all water and coastline pixels are drawn from simulation.
const Solver = preload("res://scenes/prototypes/seaside_swe_solver.gd")
var solver: Node
var water: ColorRect
var surface_material: ShaderMaterial
var metric: Label
var note: Label
var pier: Control
var mode := 0
var show_pier := true

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new(); bg.color = Color("192b30"); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var heading := Label.new(); heading.text = "2D 计算海水 · 浅水方程验证"; heading.position = Vector2(20,10); heading.add_theme_font_size_override("font_size",22); add_child(heading)
	metric = Label.new(); metric.position = Vector2(710,15); metric.add_theme_font_size_override("font_size",15); add_child(metric)
	water = ColorRect.new(); water.position = Vector2(0,112); water.size = Vector2(1200,700)
	surface_material = ShaderMaterial.new(); surface_material.shader = load("res://art/fx/seaside_swe_v1/surface.gdshader")
	water.material = surface_material; water.mouse_filter = Control.MOUSE_FILTER_STOP
	water.gui_input.connect(_water_input); add_child(water)
	pier = Control.new(); pier.position = water.position; pier.size = water.size; pier.mouse_filter = Control.MOUSE_FILTER_IGNORE; pier.draw.connect(_draw_pier); add_child(pier)
	solver = Solver.new(); solver.automatic = not OS.get_cmdline_user_args().has("--qa-manual")
	solver.textures_ready.connect(_refresh); solver.advanced.connect(_refresh); add_child(solver)
	var pause := _button("暂停", Vector2(20,50), 76)
	pause.pressed.connect(func(): solver.paused = not solver.paused; pause.text = "继续" if solver.paused else "暂停")
	var waves := _check("连续来浪", Vector2(112,55), true)
	waves.toggled.connect(func(v): solver.waves_enabled=v)
	var pillars := _check("桥墩碰撞", Vector2(238,55), true)
	pillars.toggled.connect(func(v): solver.piers_enabled=v; solver.reset())
	var foam := _check("显示泡沫", Vector2(368,55), true)
	foam.toggled.connect(func(v): surface_material.set_shader_parameter("draw_foam",v))
	var label := Label.new(); label.text="浪高"; label.position=Vector2(498,56); add_child(label)
	var slider := HSlider.new(); slider.position=Vector2(542,58); slider.size=Vector2(130,22); slider.min_value=.05; slider.max_value=.65; slider.step=.01; slider.value=.32; add_child(slider)
	slider.value_changed.connect(func(v):solver.wave_amplitude=v)
	var views := OptionButton.new(); views.position=Vector2(696,50); views.size=Vector2(158,38)
	for title in ["水面效果", "水位变化", "流速方向", "泡沫状态"]: views.add_item(title)
	views.item_selected.connect(set_view); add_child(views)
	var deck := _check("显示栈桥", Vector2(876,55), true)
	deck.toggled.connect(func(v): show_pier=v; pier.queue_redraw())
	_button("重置",Vector2(1024,50),76).pressed.connect(func():solver.reset())
	note=Label.new(); note.position=Vector2(20,88); note.add_theme_font_size_override("font_size",13)
	note.text="左键点击水面施加扰动；关闭来浪后观察传播与消散。切换桥墩会重置水面。"; add_child(note)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	var timer:=Timer.new(); timer.wait_time=.5; timer.timeout.connect(_metrics); add_child(timer); timer.start()

func _button(title: String, at: Vector2, width: float) -> Button:
	var b:=Button.new(); b.text=title; b.position=at; b.size=Vector2(width,38); add_child(b); return b

func _check(title: String, at: Vector2, on: bool) -> CheckBox:
	var b:=CheckBox.new(); b.text=title; b.position=at; b.button_pressed=on; add_child(b); return b

func _water_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		solver.add_impulse(event.position/water.size)

func _refresh() -> void:
	if not solver.initialized: return
	surface_material.set_shader_parameter("sim_state", solver.state_textures[solver.front])
	surface_material.set_shader_parameter("bed_map", solver.bed_texture)
	surface_material.set_shader_parameter("dx", solver.WIDTH_METRES/solver.grid_size.x)

func set_view(index: int) -> void:
	mode=index
	surface_material.set_shader_parameter("display_mode",index)
	pier.queue_redraw()

func _metrics() -> void:
	if not is_instance_valid(solver) or not solver.initialized: return
	var compute_text := "测量中" if solver.compute_gpu_ms<0 else "%.2f ms" % solver.compute_gpu_ms
	metric.text="FPS %d · 计算 %s · %d×%d · t %.1fs" % [Engine.get_frames_per_second(),compute_text,solver.grid_size.x,solver.grid_size.y,solver.sim_time]

func _draw_pier() -> void:
	if not show_pier or mode!=0: return
	var s:=water.size
	var walkway:=Rect2(s*Vector2(.48,.46),s*Vector2(.04,.49))
	var platform:=Rect2(s*Vector2(.41,.34),s*Vector2(.18,.14))
	for r in [walkway,platform]:
		pier.draw_rect(Rect2(r.position+Vector2(5,8),r.size),Color(0,0,0,.22))
		pier.draw_rect(r,Color("77684e")); pier.draw_rect(r,Color("b2a185"),false,2)
		for y in range(int(r.position.y)+3,int(r.end.y),8):
			pier.draw_line(Vector2(r.position.x,y),Vector2(r.end.x,y),Color("554936"),1)
	for x in [.41,.59]:
		pier.draw_line(s*Vector2(x,.34),s*Vector2(x,.48),Color("455b60"),4)
		for y in [.34,.375,.41,.445,.48]:
			pier.draw_circle(s*Vector2(x,y),3,Color("c9c6ac"))
	pier.draw_line(s*Vector2(.41,.34),s*Vector2(.59,.34),Color("455b60"),4)
	for x in [.48,.52]:
		pier.draw_line(s*Vector2(x,.48),s*Vector2(x,.94),Color("455b60"),3)
		for y in [.5,.59,.67,.75,.83,.91]: pier.draw_circle(s*Vector2(x,y),2.5,Color("c9c6ac"))
	for x in [.425,.555]:
		pier.draw_rect(Rect2(s*Vector2(x,.365),s*Vector2(.02,.065)),Color("574c39"))
		pier.draw_rect(Rect2(s*Vector2(x,.365)+Vector2(0,-2),s*Vector2(.02,.065)),Color("b2945f"))
	pier.draw_circle(s*Vector2(.5,.40)+Vector2(2,5),9,Color(0,0,0,.2))
	pier.draw_circle(s*Vector2(.5,.405),7,Color("c97526"))
	pier.draw_circle(s*Vector2(.5,.39),5,Color("d5b480"))
