extends Control

signal uncovered
const Art = preload("res://scripts/ui/nine_point_art.gd")
const FONT = preload("res://art/fonts/NotoSansCJKsc-Regular.otf")
const MASK_SIZE := Vector2i(128,176)
const THRESHOLD := 0.62
var card_value := -1
var exposed := false
var mask_image: Image
var mask_texture: ImageTexture
var cover: ColorRect
var rubbed := 0
var pointer := -2
var last_point := Vector2.ZERO

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	cover = ColorRect.new()
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform sampler2D reveal_mask : filter_linear; void fragment(){ float mark=texture(reveal_mask,UV).r; float check=mod(floor(UV.x*16.0)+floor(UV.y*22.0),2.0); vec3 ink=mix(vec3(0.21,0.32,0.40),vec3(0.42,0.54,0.61),check); float border=step(0.025,UV.x)*step(UV.x,0.975)*step(0.018,UV.y)*step(UV.y,0.982); COLOR=vec4(mix(vec3(0.89,0.88,0.82),ink,border),1.0-mark); }"
	var material_value := ShaderMaterial.new()
	material_value.shader = shader
	cover.material = material_value
	add_child(cover)
	visibility_changed.connect(func(): pointer = -2)
	get_window().focus_exited.connect(func(): pointer = -2)

func reset(value: int):
	card_value = value
	exposed = false
	rubbed = 0
	pointer = -2
	mask_image = Image.create(MASK_SIZE.x,MASK_SIZE.y,false,Image.FORMAT_R8)
	mask_image.fill(Color.BLACK)
	mask_texture = ImageTexture.create_from_image(mask_image)
	cover.material.set_shader_parameter("reveal_mask",mask_texture)
	cover.show()
	queue_redraw()

func coverage() -> float:
	return float(rubbed)/(MASK_SIZE.x*MASK_SIZE.y)

func reveal_all():
	if exposed or not visible: return
	exposed = true
	pointer = -2
	cover.hide()
	uncovered.emit()

func rub_line(from: Vector2, to: Vector2):
	if exposed or mask_image == null: return
	var a := from/size*Vector2(MASK_SIZE)
	var b := to/size*Vector2(MASK_SIZE)
	var steps := maxi(1,ceili(a.distance_to(b)/4.0))
	for step in steps+1:
		var point := a.lerp(b,float(step)/steps)
		for y in range(maxi(0,int(point.y)-12),mini(MASK_SIZE.y,int(point.y)+13)):
			for x in range(maxi(0,int(point.x)-12),mini(MASK_SIZE.x,int(point.x)+13)):
				if Vector2(x,y).distance_squared_to(point) > 144 or mask_image.get_pixel(x,y).r > 0.5: continue
				mask_image.set_pixel(x,y,Color.WHITE)
				rubbed += 1
	mask_texture.update(mask_image)
	if coverage() >= THRESHOLD: reveal_all()

func _gui_input(event: InputEvent):
	if exposed: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and pointer == -2:
		pointer = -1
		last_point = event.position
		rub_line(last_point,last_point)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed and pointer == -2:
		pointer = event.index
		last_point = event.position
		rub_line(last_point,last_point)
		accept_event()

func _input(event: InputEvent):
	if not is_visible_in_tree() or exposed or pointer == -2: return
	if event is InputEventMouseButton and pointer == -1 and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		pointer = -2
	elif event is InputEventScreenTouch and event.index == pointer and not event.pressed:
		pointer = -2
	elif (event is InputEventMouseMotion and pointer == -1) or (event is InputEventScreenDrag and event.index == pointer):
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse()*event.position
		# Leaving the card releases the stroke; re-entry requires another press.
		if not Rect2(Vector2.ZERO,size).has_point(point): pointer = -2; return
		rub_line(last_point,point)
		last_point = point
	else: return
	get_viewport().set_input_as_handled()

func _draw():
	Art.card(self,FONT,Rect2(Vector2.ZERO,size),card_value)
