extends Node
## Heightfield shallow-water solver. No CPU readback during normal rendering.
## Algorithm adapted from godot_swe_ocean2d (MIT); see provenance.json.
signal advanced
signal snapshot_ready(data: Dictionary)
signal textures_ready

const ASSET := "res://art/fx/seaside_swe_v1/"
const FIXED_DT := 1.0 / 120.0
const WIDTH_METRES := 134.4
var grid_size := Vector2i(384, 256)
var automatic := true
var paused := false
var waves_enabled := true
var foam_enabled := true
var piers_enabled := true
var flat_bed := false
var wave_amplitude := 0.32
var initial_mode := 1.0
var state_textures: Array[Texture2DRD] = [Texture2DRD.new(), Texture2DRD.new()]
var bed_texture := Texture2DRD.new()
var front := 0
var sim_time := 0.0
var compute_gpu_ms := -1.0
var gpu_name := ""
var initialized := false
var busy := false
var _accumulator := 0.0
var _last_drawn_frame := -1
var _last_timestamp_drawn_frame := -1
var _pending_impulse := Vector4(-1, -1, 0.025, 0)
var _rd: RenderingDevice
var _states: Array[RID] = []
var _bed := RID()
var _velocity := RID()
var _shaders: Array[RID] = []
var _pipelines: Array[RID] = []
var _sets: Array = []
var _gpu_front := 0
var _gpu_time := 0.0
var _disposed := false

func _ready() -> void:
	# Load imported SPIR-V on the main thread before using the render thread.
	var code: Array[RDShaderSPIRV] = []
	for name in ["initialize", "velocity", "height_foam"]:
		var file := load(ASSET + name + ".glsl") as RDShaderFile
		code.append(file.get_spirv())
	busy = true
	RenderingServer.call_on_render_thread(_initialize_gpu.bind(code, grid_size, _settings()))

func _settings() -> Vector4:
	return Vector4(initial_mode, float(foam_enabled), float(flat_bed), 0)

func _process(delta: float) -> void:
	if not automatic or paused or not initialized or busy:
		return
	# Godot can continue _process while a minimized window stops drawing.
	# Submit at most one update per rendered frame, and freeze invisible simulation.
	var drawn := Engine.get_frames_drawn()
	if drawn == _last_drawn_frame:
		return
	_last_drawn_frame = drawn
	_accumulator += minf(delta, 0.10)
	var count := mini(int(_accumulator / FIXED_DT), 8)
	if count > 0:
		_accumulator -= count * FIXED_DT
		advance(count)

func advance(count: int) -> void:
	if not initialized or busy:
		return
	busy = true
	var pulse := _pending_impulse
	_pending_impulse.w = 0.0
	RenderingServer.call_on_render_thread(_step_gpu.bind(clampi(count, 1, 64), wave_amplitude,
		waves_enabled, _settings(), pulse))

func add_impulse(uv: Vector2, amplitude: float = 0.38) -> void:
	_pending_impulse = Vector4(uv.x, uv.y, 0.024, amplitude)

func reset() -> void:
	if not initialized:
		return
	busy = true
	_accumulator = 0.0
	_pending_impulse.w = 0.0
	RenderingServer.call_on_render_thread(_reset_gpu.bind(wave_amplitude, piers_enabled, _settings()))

func request_snapshot() -> void:
	# QA only: synchronous readback is never called by the interactive sample.
	RenderingServer.call_on_render_thread(_snapshot_gpu)

func _image_uniform(binding: int, rid: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = binding
	u.add_id(rid)
	return u

func _make_texture(format: int, size: Vector2i) -> RID:
	var f := RDTextureFormat.new()
	f.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	f.width = size.x
	f.height = size.y
	f.format = format
	f.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	return _rd.texture_create(f, RDTextureView.new(), [])

func _initialize_gpu(code: Array[RDShaderSPIRV], size: Vector2i, options: Vector4) -> void:
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		call_deferred("_failed", "当前渲染器没有 RenderingDevice，无法运行计算海水。")
		return
	_states = [_make_texture(RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT, size),
		_make_texture(RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT, size)]
	_bed = _make_texture(RenderingDevice.DATA_FORMAT_R32_SFLOAT, size)
	_velocity = _make_texture(RenderingDevice.DATA_FORMAT_R32G32_SFLOAT, size)
	for spirv in code:
		var shader := _rd.shader_create_from_spirv(spirv)
		if not shader.is_valid():
			call_deferred("_failed", "海水计算着色器初始化失败。")
			_free_gpu()
			return
		_shaders.append(shader)
		_pipelines.append(_rd.compute_pipeline_create(shader))
		var pair: Array[RID] = []
		for i in 2:
			pair.append(_rd.uniform_set_create([
				_image_uniform(0, _states[i]), _image_uniform(1, _states[1-i]),
				_image_uniform(2, _bed), _image_uniform(3, _velocity)], shader, 0))
		_sets.append(pair)
	_reset_gpu(wave_amplitude, piers_enabled, options)
	call_deferred("_publish_resources", _states.duplicate(), _bed, _rd.get_device_name())

func _constants(time: float, amplitude: float, waves: bool, piers: bool, options: Vector4, pulse: Vector4) -> PackedByteArray:
	return PackedFloat32Array([grid_size.x, grid_size.y, WIDTH_METRES/grid_size.x, FIXED_DT,
		time, amplitude, float(waves), float(piers), pulse.x, pulse.y, pulse.z, pulse.w,
		options.x, options.y, options.z, options.w]).to_byte_array()

func _dispatch(list: int, pass_index: int, source: int, bytes: PackedByteArray) -> void:
	_rd.compute_list_bind_compute_pipeline(list, _pipelines[pass_index])
	_rd.compute_list_bind_uniform_set(list, _sets[pass_index][source], 0)
	_rd.compute_list_set_push_constant(list, bytes, bytes.size())
	_rd.compute_list_dispatch(list, ceili(grid_size.x/8.0), ceili(grid_size.y/8.0), 1)

func _reset_gpu(amplitude: float, piers: bool, options: Vector4) -> void:
	if _disposed or _pipelines.is_empty():
		return
	_gpu_front = 0
	_gpu_time = 0.0
	var bytes := _constants(0, amplitude, false, piers, options, Vector4.ZERO)
	var list := _rd.compute_list_begin()
	_dispatch(list, 0, 0, bytes)
	_rd.compute_list_add_barrier(list)
	_dispatch(list, 0, 1, bytes)
	_rd.compute_list_end()
	call_deferred("_finished", 0, 0.0, -1.0)

func _step_gpu(count: int, amplitude: float, waves: bool, options: Vector4, pulse: Vector4) -> void:
	if _disposed:
		return
	var measured := -1.0
	var begin := -1
	for i in _rd.get_captured_timestamps_count():
		var label := _rd.get_captured_timestamp_name(i)
		if label == "seaside_swe_begin": begin = _rd.get_captured_timestamp_gpu_time(i)
		elif label == "seaside_swe_end" and begin >= 0:
			# RenderingDevice GPU query results are nanoseconds (driver implementation).
			measured = float(_rd.get_captured_timestamp_gpu_time(i)-begin)/1000000.0
	var drawn := Engine.get_frames_drawn()
	var capture := drawn != _last_timestamp_drawn_frame
	if capture:
		_last_timestamp_drawn_frame = drawn
		_rd.capture_timestamp("seaside_swe_begin")
	var list := _rd.compute_list_begin()
	for step in count:
		_gpu_time += FIXED_DT
		var bytes := _constants(_gpu_time, amplitude, waves, piers_enabled, options,
			pulse if step == 0 else Vector4.ZERO)
		_dispatch(list, 1, _gpu_front, bytes)
		_rd.compute_list_add_barrier(list)
		_dispatch(list, 2, _gpu_front, bytes)
		_rd.compute_list_add_barrier(list)
		_gpu_front = 1-_gpu_front
	_rd.compute_list_end()
	if capture: _rd.capture_timestamp("seaside_swe_end")
	call_deferred("_finished", _gpu_front, _gpu_time, measured)

func _publish_resources(states: Array, bed: RID, device: String) -> void:
	if _disposed: return
	for i in 2: state_textures[i].texture_rd_rid = states[i]
	bed_texture.texture_rd_rid = bed
	gpu_name = device
	initialized = true
	textures_ready.emit()

func _finished(index: int, time: float, measured: float) -> void:
	if _disposed: return
	front = index
	sim_time = time
	if measured >= 0.0: compute_gpu_ms = measured
	busy = false
	advanced.emit()

func _snapshot_gpu() -> void:
	if _disposed or _states.is_empty(): return
	var data := {"state": _rd.texture_get_data(_states[_gpu_front], 0).to_float32_array(),
		"bed": _rd.texture_get_data(_bed, 0).to_float32_array(), "size": grid_size,
		"sim_time": _gpu_time}
	call_deferred("_send_snapshot", data)

func _send_snapshot(data: Dictionary) -> void:
	snapshot_ready.emit(data)

func _failed(message: String) -> void:
	busy = false
	push_error(message)

func _exit_tree() -> void:
	_disposed = true
	initialized = false
	for texture in state_textures: texture.texture_rd_rid = RID()
	bed_texture.texture_rd_rid = RID()
	RenderingServer.call_on_render_thread(_free_gpu)

func _free_gpu() -> void:
	if _rd == null: return
	for pair in _sets:
		for rid in pair:
			if _rd.uniform_set_is_valid(rid): _rd.free_rid(rid)
	for rid in _pipelines: _rd.free_rid(rid)
	for rid in _shaders: _rd.free_rid(rid)
	for rid in _states: _rd.free_rid(rid)
	if _bed.is_valid(): _rd.free_rid(_bed)
	if _velocity.is_valid(): _rd.free_rid(_velocity)
	_sets.clear(); _pipelines.clear(); _shaders.clear(); _states.clear()
	_bed = RID(); _velocity = RID()
