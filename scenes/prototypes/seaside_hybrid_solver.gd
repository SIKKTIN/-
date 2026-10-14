extends Node
## Heightfield shallow-water solver. No CPU readback during normal rendering.
## Algorithm adapted from godot_swe_ocean2d (MIT); see provenance.json.
signal advanced
signal snapshot_ready(data: Dictionary)
signal textures_ready

const ASSET := "res://art/fx/seaside_hybrid_v3/"
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
var foam_textures: Array[Texture2DRD] = [Texture2DRD.new(),Texture2DRD.new()]
var ocean_texture := Texture2DArrayRD.new()
var _foam: Array[RID] = []
var _seed := RID()
var _fft_a := RID()
var _fft_b := RID()
var _ocean := RID()
var _fft_shaders: Array[RID] = []
var _fft_pipelines: Array[RID] = []
var _fft_sets: Array[RID] = []
var _seed_data := PackedByteArray()
var qa_single_mode := false
var foam_transport_only := false
var _qa_single := false
const FFT_SIZE := 128
const FFT_TEXTURE_BYTES := 3145728

func simulation_bytes() -> int:
	return grid_size.x*grid_size.y*76+FFT_TEXTURE_BYTES


func _ready() -> void:
	# Load imported SPIR-V on the main thread before using the render thread.
	var code: Array[String] = []
	for name in ["initialize", "velocity", "height_foam", "foam", "spectrum", "ifft", "unpack"]:
		var text:=FileAccess.get_file_as_string(ASSET+name+".glsl").replace("#[compute]","")
		text=text.replace('#include "common.glslinc"',FileAccess.get_file_as_string(ASSET+"common.glslinc"))
		code.append(text)
	_seed_data=_make_spectrum()
	busy = true
	RenderingServer.call_on_render_thread(_initialize_gpu.bind(code, grid_size, _settings()))

func _settings() -> Vector4:
	return Vector4(initial_mode, float(foam_enabled), float(flat_bed), float(foam_transport_only))

func _process(delta: float) -> void:
	if not automatic or paused or not initialized or busy or not RenderingServer.render_loop_enabled:
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
	_qa_single=qa_single_mode
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

func _initialize_gpu(source: Array[String], size: Vector2i, options: Vector4) -> void:
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		call_deferred("_failed", "当前渲染器没有 RenderingDevice，无法运行计算海水。")
		return
	var code: Array[RDShaderSPIRV]=[]
	for text in source:
		var shader_source:=RDShaderSource.new();shader_source.source_compute=text
		var spirv:=_rd.shader_compile_spirv_from_source(shader_source,true)
		var error:=spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE)
		if not error.is_empty():call_deferred("_failed",error);return
		code.append(spirv)
	_states = [_make_texture(RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT, size),
		_make_texture(RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT, size)]
	_bed = _make_texture(RenderingDevice.DATA_FORMAT_R32_SFLOAT, size)
	_velocity = _make_texture(RenderingDevice.DATA_FORMAT_R32G32_SFLOAT, size)
	_foam = [_make_texture(RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT,size),_make_texture(RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT,size)]
	_seed = _make_array(2,[_seed_data])
	_fft_a = _make_array(4,[]); _fft_b = _make_array(4,[]); _ocean = _make_array(2,[])
	for i in range(4,7):
		var shader:=_rd.shader_create_from_spirv(code[i]); _fft_shaders.append(shader)
		_fft_pipelines.append(_rd.compute_pipeline_create(shader))
	_fft_sets.append(_rd.uniform_set_create([_image_uniform(0,_seed),_image_uniform(1,_fft_a)],_fft_shaders[0],0))
	_fft_sets.append(_rd.uniform_set_create([_image_uniform(0,_fft_a),_image_uniform(1,_fft_b)],_fft_shaders[1],0))
	_fft_sets.append(_rd.uniform_set_create([_image_uniform(0,_fft_b),_image_uniform(1,_fft_a)],_fft_shaders[1],0))
	_fft_sets.append(_rd.uniform_set_create([_image_uniform(0,_fft_a),_image_uniform(1,_ocean)],_fft_shaders[2],0))
	for spirv in code.slice(0,4):
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
				_image_uniform(2, _bed), _image_uniform(3, _velocity),
				_image_uniform(4,_ocean),_image_uniform(5,_foam[i]),_image_uniform(6,_foam[1-i])], shader, 0))
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
	_fft_dispatch(list,0.0,amplitude)
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
	_fft_dispatch(list,_gpu_time+count*FIXED_DT,amplitude if waves else 0.0)
	for step in count:
		_gpu_time += FIXED_DT
		var bytes := _constants(_gpu_time, amplitude, waves, piers_enabled, options,
			pulse if step == 0 else Vector4.ZERO)
		_dispatch(list, 1, _gpu_front, bytes)
		_rd.compute_list_add_barrier(list)
		_dispatch(list, 2, _gpu_front, bytes)
		_rd.compute_list_add_barrier(list)
		_dispatch(list,3,_gpu_front,bytes)
		_rd.compute_list_add_barrier(list)
		_gpu_front = 1-_gpu_front
	_rd.compute_list_end()
	if capture: _rd.capture_timestamp("seaside_swe_end")
	call_deferred("_finished", _gpu_front, _gpu_time, measured)

func _publish_resources(states: Array, bed: RID, device: String) -> void:
	if _disposed: return
	for i in 2: state_textures[i].texture_rd_rid = states[i]
	bed_texture.texture_rd_rid = bed
	for i in 2: foam_textures[i].texture_rd_rid=_foam[i]
	ocean_texture.texture_rd_rid=_ocean
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
		"sim_time": _gpu_time, "foam":_rd.texture_get_data(_foam[_gpu_front],0).to_float32_array(),
		"ocean":_rd.texture_get_data(_ocean,0).to_float32_array(), "ocean_small":_rd.texture_get_data(_ocean,1).to_float32_array()}
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
	ocean_texture.texture_rd_rid=RID()
	for t in foam_textures:t.texture_rd_rid=RID()
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
	for rid in _fft_sets:
		if _rd.uniform_set_is_valid(rid):_rd.free_rid(rid)
	for rid in _fft_pipelines:_rd.free_rid(rid)
	for rid in _fft_shaders:_rd.free_rid(rid)
	for rid in _foam+[_seed,_fft_a,_fft_b,_ocean]:
		if rid.is_valid():_rd.free_rid(rid)
	_fft_sets.clear();_fft_pipelines.clear();_fft_shaders.clear();_foam.clear()
	_seed=RID();_fft_a=RID();_fft_b=RID();_ocean=RID()
	_sets.clear(); _pipelines.clear(); _shaders.clear(); _states.clear()
	_bed = RID(); _velocity = RID()

func _make_array(layers: int, data: Array) -> RID:
	var f:=RDTextureFormat.new();f.texture_type=RenderingDevice.TEXTURE_TYPE_2D_ARRAY
	f.width=FFT_SIZE;f.height=FFT_SIZE;f.array_layers=layers;f.format=RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	f.usage_bits=RenderingDevice.TEXTURE_USAGE_STORAGE_BIT|RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT|RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	# Godot expects one byte array per array layer.
	var images: Array[PackedByteArray]=[]
	if not data.is_empty():
		for layer in layers:images.append(data[0].slice(layer*FFT_SIZE*FFT_SIZE*16,(layer+1)*FFT_SIZE*FFT_SIZE*16))
	return _rd.texture_create(f,RDTextureView.new(),images)

func _make_spectrum() -> PackedByteArray:
	var rng:=RandomNumberGenerator.new();rng.seed=0x5048494c
	var result:=PackedFloat32Array();result.resize(FFT_SIZE*FFT_SIZE*8)
	for cascade in 2:
		var length_m:=134.4 if cascade==0 else 33.6
		var energy:=0.0
		for y in FFT_SIZE:
			for x in FFT_SIZE:
				var offset:=(cascade*FFT_SIZE*FFT_SIZE+y*FFT_SIZE+x)*4
				var k:=Vector2(x if x<FFT_SIZE/2 else x-FFT_SIZE,y if y<FFT_SIZE/2 else y-FFT_SIZE)*TAU/length_m
				var mag:=k.length()
				if mag<0.0001 or x==FFT_SIZE/2 or y==FFT_SIZE/2:continue
				var wavelength:=TAU/mag
				if cascade==0 and wavelength<6.0:continue
				if cascade==1 and (wavelength>=6.0 or wavelength<0.65):continue
				# Phillips spectrum: gravity/wind cutoff, directional spread, small-wave damping.
				var direction:=k.normalized().dot(Vector2(0.18,0.98).normalized())
				var directional:=(0.12+0.88*pow(absf(direction),6.0))*(1.0 if direction<0.0 else 0.16)
				var power:=exp(-1.0/pow(mag*16.0,2.0))/pow(mag,4.0)*directional*exp(-mag*mag*0.012)
				result[offset]=rng.randfn()*sqrt(power*0.5);result[offset+1]=rng.randfn()*sqrt(power*0.5)
				energy+=result[offset]*result[offset]+result[offset+1]*result[offset+1]
		var rms:=0.22 if cascade==0 else 0.055
		var gain:=rms*FFT_SIZE*FFT_SIZE/sqrt(2.0*energy)
		for i in range(cascade*FFT_SIZE*FFT_SIZE*4,(cascade+1)*FFT_SIZE*FFT_SIZE*4,4):
			result[i]*=gain;result[i+1]*=gain
	return result.to_byte_array()

func _fft_dispatch(list: int,time: float,amplitude: float) -> void:
	_rd.compute_list_bind_compute_pipeline(list,_fft_pipelines[0]);_rd.compute_list_bind_uniform_set(list,_fft_sets[0],0)
	var bytes:=PackedFloat32Array([time,amplitude/0.32,float(_qa_single),0]).to_byte_array()
	_rd.compute_list_set_push_constant(list,bytes,16);_rd.compute_list_dispatch(list,16,16,2);_rd.compute_list_add_barrier(list)
	_rd.compute_list_bind_compute_pipeline(list,_fft_pipelines[1])
	for axis in 2:
		_rd.compute_list_bind_uniform_set(list,_fft_sets[1+axis],0)
		bytes=PackedInt32Array([axis,0,0,0]).to_byte_array()
		_rd.compute_list_set_push_constant(list,bytes,16);_rd.compute_list_dispatch(list,128,4,1);_rd.compute_list_add_barrier(list)
	_rd.compute_list_bind_compute_pipeline(list,_fft_pipelines[2]);_rd.compute_list_bind_uniform_set(list,_fft_sets[3],0)
	_rd.compute_list_set_push_constant(list,PackedByteArray(),0)
	_rd.compute_list_dispatch(list,16,16,2);_rd.compute_list_add_barrier(list)
