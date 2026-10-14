extends Control

const SOURCE="res://docs/art/seaside-pier-concept-v01/concept-v01.png"
var water: TextureRect
var water_material: ShaderMaterial
var metric: Label
var running := true
var frozen_time := 0.0

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg=ColorRect.new();bg.color=Color("202f32");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(bg)
	var heading=Label.new();heading.text="2D 海水动态样例";heading.position=Vector2(22,10);heading.add_theme_font_size_override("font_size",22);add_child(heading)
	water=TextureRect.new();water.name="AnimatedSea"
	water.texture=preload("res://scripts/presentation/world_texture.gd").load_asset({"texture":SOURCE,"region":[20,70,1046,850],"runtime_size_limit":1024})
	water.position=Vector2(0,64);water.size=Vector2(960,780);water.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;water.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var noise=FastNoiseLite.new();noise.seed=731;noise.frequency=.026;noise.fractal_octaves=3
	var noise_texture=NoiseTexture2D.new();noise_texture.width=256;noise_texture.height=256;noise_texture.seamless=true;noise_texture.noise=noise
	water_material=ShaderMaterial.new();water_material.shader=load("res://art/fx/seaside_water_v1/water.gdshader");water_material.set_shader_parameter("flow_noise",noise_texture)
	water.material=water_material;add_child(water)
	var toggle=Button.new();toggle.text="暂停水面";toggle.position=Vector2(290,9);toggle.size=Vector2(104,36)
	toggle.pressed.connect(func():
		running=not running
		if not running:frozen_time=Time.get_ticks_msec()/1000.0;water_material.set_shader_parameter("manual_time",frozen_time)
		else:water_material.set_shader_parameter("manual_time",-1.0)
		toggle.text="暂停水面" if running else "继续流动")
	add_child(toggle)
	var label=Label.new();label.text="水纹强度";label.position=Vector2(410,15);add_child(label)
	var slider=HSlider.new();slider.position=Vector2(492,15);slider.size=Vector2(160,24);slider.min_value=0;slider.max_value=1.5;slider.step=.05;slider.value=1
	slider.value_changed.connect(func(v):water_material.set_shader_parameter("strength",v));add_child(slider)
	metric=Label.new();metric.position=Vector2(680,15);metric.add_theme_font_size_override("font_size",14);add_child(metric)
	var timer=Timer.new();timer.wait_time=.5;timer.timeout.connect(update_metric);add_child(timer);timer.start()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	update_metric()

func update_metric():
	metric.text="FPS %d · GPU %.2f ms" % [Engine.get_frames_per_second(),RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())]
