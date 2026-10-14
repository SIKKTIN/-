"""Build isolated v3 adaptations; original prototypes and live map remain intact."""
from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[1]
art=root/'art/fx/seaside_hybrid_v3'
doc=root/'docs/art/seaside-hybrid-v3';doc.mkdir(parents=True,exist_ok=True)
source=root/'art/fx/seaside_swe_v1'
common=(source/'common.glslinc').read_text(encoding='utf-8')
common=common[:common.index('float incoming(')]+'''#include "ocean.glslinc"
float incoming(vec2 uv, float t) { return ocean(uv*p.grid.xy*p.grid.z).x; }
'''
common=common.replace('#include "ocean.glslinc"',(art/'ocean.glslinc').read_text(encoding='utf-8'))
(art/'common.glslinc').write_text(common,encoding='utf-8')
for name in ['initialize','velocity','height_foam']:
    code=(source/f'{name}.glsl').read_text(encoding='utf-8')
    if name=='initialize':
        code=code.replace('imageStore(terrain,q,vec4(z));','imageStore(foam_out,q,vec4(foam,foam*0.65,uv*p.grid.xy*p.grid.z));\n    imageStore(terrain,q,vec4(z));')
    if name=='height_foam':
        code=code.replace('if (p.impulse.w!=0.0', '''// Open-ocean overlap: relax toward the spectral field only in deep water.
    // The shallow zone remains the nonlinear SWE with wet/dry boundaries and obstacles.
    if(p.wave.z>0.5 && p.options.z<0.5){
        float coupling=smoothstep(2.25,2.9,-bed(q));
        vec4 spectral=ocean(uv*p.grid.xy*p.grid.z);
        float weight=1.0-exp(-p.grid.w*1.8*coupling);
        h=mix(h,max(0.0,-bed(q)+spectral.x),weight);
        v=mix(v,spectral.yz*1.5,weight*0.4);
    }
    if (p.impulse.w!=0.0''')
    code=code.replace('#version 450','#version 450\n// Hybrid common ABI revision 3: transported material coordinates.')
    (art/f'{name}.glsl').write_text(code,encoding='utf-8')
solver=(root/'scenes/prototypes/seaside_swe_solver.gd').read_text(encoding='utf-8')
solver=solver.replace('seaside_swe_v1/','seaside_hybrid_v3/')
solver=solver.replace('var _disposed := false','''var _disposed := false
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
\treturn grid_size.x*grid_size.y*76+FFT_TEXTURE_BYTES
''')
solver=solver.replace('for name in ["initialize", "velocity", "height_foam"]:', 'for name in ["initialize", "velocity", "height_foam", "foam", "spectrum", "ifft", "unpack"]:')
solver=solver.replace('var code: Array[RDShaderSPIRV] = []','var code: Array[String] = []')
solver=solver.replace('var file := load(ASSET + name + ".glsl") as RDShaderFile\n\t\tcode.append(file.get_spirv())', '''var text:=FileAccess.get_file_as_string(ASSET+name+".glsl").replace("#[compute]","")
\t\ttext=text.replace('#include "common.glslinc"',FileAccess.get_file_as_string(ASSET+"common.glslinc"))
\t\tcode.append(text)''')
solver=solver.replace('func _initialize_gpu(code: Array[RDShaderSPIRV],','func _initialize_gpu(source: Array[String],')
solver=solver.replace('\t_states = [', '''\tvar code: Array[RDShaderSPIRV]=[]
\tfor text in source:
\t\tvar shader_source:=RDShaderSource.new();shader_source.source_compute=text
\t\tvar spirv:=_rd.shader_compile_spirv_from_source(shader_source,true)
\t\tvar error:=spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE)
\t\tif not error.is_empty():call_deferred("_failed",error);return
\t\tcode.append(spirv)
\t_states = [''',1)
solver=solver.replace('\tbusy = true\n\tRenderingServer.call_on_render_thread(_initialize_gpu', '\t_seed_data=_make_spectrum()\n\tbusy = true\n\tRenderingServer.call_on_render_thread(_initialize_gpu',1)
solver=solver.replace('float(flat_bed), 0)','float(flat_bed), float(foam_transport_only))')
solver=solver.replace('busy = true\n\tvar pulse', 'busy = true\n\t_qa_single=qa_single_mode\n\tvar pulse')
solver=solver.replace('if not automatic or paused or not initialized or busy:', 'if not automatic or paused or not initialized or busy or not RenderingServer.render_loop_enabled:')
solver=solver.replace('\tfor spirv in code:', '''\t_foam = [_make_texture(RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT,size),_make_texture(RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT,size)]
\t_seed = _make_array(2,[_seed_data])
\t_fft_a = _make_array(4,[]); _fft_b = _make_array(4,[]); _ocean = _make_array(2,[])
\tfor i in range(4,7):
\t\tvar shader:=_rd.shader_create_from_spirv(code[i]); _fft_shaders.append(shader)
\t\t_fft_pipelines.append(_rd.compute_pipeline_create(shader))
\t_fft_sets.append(_rd.uniform_set_create([_image_uniform(0,_seed),_image_uniform(1,_fft_a)],_fft_shaders[0],0))
\t_fft_sets.append(_rd.uniform_set_create([_image_uniform(0,_fft_a),_image_uniform(1,_fft_b)],_fft_shaders[1],0))
\t_fft_sets.append(_rd.uniform_set_create([_image_uniform(0,_fft_b),_image_uniform(1,_fft_a)],_fft_shaders[1],0))
\t_fft_sets.append(_rd.uniform_set_create([_image_uniform(0,_fft_a),_image_uniform(1,_ocean)],_fft_shaders[2],0))
\tfor spirv in code.slice(0,4):''')
solver=solver.replace('_image_uniform(2, _bed), _image_uniform(3, _velocity)]','_image_uniform(2, _bed), _image_uniform(3, _velocity),\n\t\t\t\t_image_uniform(4,_ocean),_image_uniform(5,_foam[i]),_image_uniform(6,_foam[1-i])]')
solver=solver.replace('\t_dispatch(list, 0, 0, bytes)', '\t_fft_dispatch(list,0.0,amplitude)\n\t_dispatch(list, 0, 0, bytes)')
solver=solver.replace('\tfor step in count:\n', '\t_fft_dispatch(list,_gpu_time+count*FIXED_DT,amplitude if waves else 0.0)\n\tfor step in count:\n')
solver=solver.replace('\t\t_gpu_front = 1-_gpu_front','\t\t_dispatch(list,3,_gpu_front,bytes)\n\t\t_rd.compute_list_add_barrier(list)\n\t\t_gpu_front = 1-_gpu_front')
solver=solver.replace('\tbed_texture.texture_rd_rid = bed','\tbed_texture.texture_rd_rid = bed\n\tfor i in 2: foam_textures[i].texture_rd_rid=_foam[i]\n\tocean_texture.texture_rd_rid=_ocean')
solver=solver.replace('"sim_time": _gpu_time}', '"sim_time": _gpu_time, "foam":_rd.texture_get_data(_foam[_gpu_front],0).to_float32_array(),\n\t\t"ocean":_rd.texture_get_data(_ocean,0).to_float32_array(), "ocean_small":_rd.texture_get_data(_ocean,1).to_float32_array()}')
solver=solver.replace('\tbed_texture.texture_rd_rid = RID()', '\tbed_texture.texture_rd_rid = RID()\n\tocean_texture.texture_rd_rid=RID()\n\tfor t in foam_textures:t.texture_rd_rid=RID()')
solver=solver.replace('\t_sets.clear();', '''\tfor rid in _fft_sets:
\t\tif _rd.uniform_set_is_valid(rid):_rd.free_rid(rid)
\tfor rid in _fft_pipelines:_rd.free_rid(rid)
\tfor rid in _fft_shaders:_rd.free_rid(rid)
\tfor rid in _foam+[_seed,_fft_a,_fft_b,_ocean]:
\t\tif rid.is_valid():_rd.free_rid(rid)
\t_fft_sets.clear();_fft_pipelines.clear();_fft_shaders.clear();_foam.clear()
\t_seed=RID();_fft_a=RID();_fft_b=RID();_ocean=RID()
\t_sets.clear();''')
solver+='''
func _make_array(layers: int, data: Array) -> RID:
\tvar f:=RDTextureFormat.new();f.texture_type=RenderingDevice.TEXTURE_TYPE_2D_ARRAY
\tf.width=FFT_SIZE;f.height=FFT_SIZE;f.array_layers=layers;f.format=RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
\tf.usage_bits=RenderingDevice.TEXTURE_USAGE_STORAGE_BIT|RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT|RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
\t# Godot expects one byte array per array layer.
\tvar images: Array[PackedByteArray]=[]
\tif not data.is_empty():
\t\tfor layer in layers:images.append(data[0].slice(layer*FFT_SIZE*FFT_SIZE*16,(layer+1)*FFT_SIZE*FFT_SIZE*16))
\treturn _rd.texture_create(f,RDTextureView.new(),images)

func _make_spectrum() -> PackedByteArray:
\tvar rng:=RandomNumberGenerator.new();rng.seed=0x5048494c
\tvar result:=PackedFloat32Array();result.resize(FFT_SIZE*FFT_SIZE*8)
\tfor cascade in 2:
\t\tvar length_m:=134.4 if cascade==0 else 33.6
\t\tvar energy:=0.0
\t\tfor y in FFT_SIZE:
\t\t\tfor x in FFT_SIZE:
\t\t\t\tvar offset:=(cascade*FFT_SIZE*FFT_SIZE+y*FFT_SIZE+x)*4
\t\t\t\tvar k:=Vector2(x if x<FFT_SIZE/2 else x-FFT_SIZE,y if y<FFT_SIZE/2 else y-FFT_SIZE)*TAU/length_m
\t\t\t\tvar mag:=k.length()
\t\t\t\tif mag<0.0001 or x==FFT_SIZE/2 or y==FFT_SIZE/2:continue
\t\t\t\tvar wavelength:=TAU/mag
\t\t\t\tif cascade==0 and wavelength<6.0:continue
\t\t\t\tif cascade==1 and (wavelength>=6.0 or wavelength<0.65):continue
\t\t\t\t# Phillips spectrum: gravity/wind cutoff, directional spread, small-wave damping.
\t\t\t\tvar direction:=k.normalized().dot(Vector2(0.18,0.98).normalized())
\t\t\t\tvar directional:=(0.12+0.88*pow(absf(direction),6.0))*(1.0 if direction<0.0 else 0.16)
\t\t\t\tvar power:=exp(-1.0/pow(mag*16.0,2.0))/pow(mag,4.0)*directional*exp(-mag*mag*0.012)
\t\t\t\tresult[offset]=rng.randfn()*sqrt(power*0.5);result[offset+1]=rng.randfn()*sqrt(power*0.5)
\t\t\t\tenergy+=result[offset]*result[offset]+result[offset+1]*result[offset+1]
\t\tvar rms:=0.22 if cascade==0 else 0.055
\t\tvar gain:=rms*FFT_SIZE*FFT_SIZE/sqrt(2.0*energy)
\t\tfor i in range(cascade*FFT_SIZE*FFT_SIZE*4,(cascade+1)*FFT_SIZE*FFT_SIZE*4,4):
\t\t\tresult[i]*=gain;result[i+1]*=gain
\treturn result.to_byte_array()

func _fft_dispatch(list: int,time: float,amplitude: float) -> void:
\t_rd.compute_list_bind_compute_pipeline(list,_fft_pipelines[0]);_rd.compute_list_bind_uniform_set(list,_fft_sets[0],0)
\tvar bytes:=PackedFloat32Array([time,amplitude/0.32,float(_qa_single),0]).to_byte_array()
\t_rd.compute_list_set_push_constant(list,bytes,16);_rd.compute_list_dispatch(list,16,16,2);_rd.compute_list_add_barrier(list)
\t_rd.compute_list_bind_compute_pipeline(list,_fft_pipelines[1])
\tfor axis in 2:
\t\t_rd.compute_list_bind_uniform_set(list,_fft_sets[1+axis],0)
\t\tbytes=PackedInt32Array([axis,0,0,0]).to_byte_array()
\t\t_rd.compute_list_set_push_constant(list,bytes,16);_rd.compute_list_dispatch(list,128,4,1);_rd.compute_list_add_barrier(list)
\t_rd.compute_list_bind_compute_pipeline(list,_fft_pipelines[2]);_rd.compute_list_bind_uniform_set(list,_fft_sets[3],0)
\t_rd.compute_list_set_push_constant(list,PackedByteArray(),0)
\t_rd.compute_list_dispatch(list,16,16,2);_rd.compute_list_add_barrier(list)
'''
(root/'scenes/prototypes/seaside_hybrid_solver.gd').write_text(solver,encoding='utf-8')
# Keep the original base UI unchanged; make a v3-specific base with its own solver.
ui=(root/'scenes/prototypes/seaside_swe_demo.gd').read_text(encoding='utf-8').replace('seaside_swe_solver.gd','seaside_hybrid_solver.gd')
(root/'scenes/prototypes/seaside_hybrid_ui.gd').write_text(ui,encoding='utf-8')
style=(root/'scenes/prototypes/seaside_swe_style_demo.gd').read_text(encoding='utf-8').replace('seaside_swe_demo.gd','seaside_hybrid_ui.gd')
style=style.replace('surface_material.shader=load("res://art/fx/seaside_swe_style_v2/surface.gdshader")','surface_material.shader=load("res://art/fx/seaside_hybrid_v3/surface.gdshader")')
style=style.replace('2D 计算海水 · 园区画风预览','2D 海水 · FFT 海浪 + 近岸模拟')
style=style.replace('note.text="海水由浅水方程计算；草地与人物复用游戏素材。左键点击产生扰动，可查看水位 / 流速 / 泡沫。"','note.text="两层计算海浪 · 近岸 / 桥墩碰撞 · 随流泡沫与喷溅；左键点击水面可施加扰动。"\n\t_create_spray()')
style+='''
var spray: GPUParticles2D
func _create_spray() -> void:
\tspray=GPUParticles2D.new();spray.position=water.position;spray.amount=600;spray.lifetime=1.3
\tspray.visibility_rect=Rect2(-100,-100,1400,900);spray.local_coords=true;spray.randomness=0.8
\tvar process:=ShaderMaterial.new();process.shader=load("res://art/fx/seaside_hybrid_v3/spray.gdshader")
\tprocess.set_shader_parameter("canvas_size",water.size);spray.process_material=process
\tvar draw_material:=ShaderMaterial.new();draw_material.shader=load("res://art/fx/seaside_hybrid_v3/drop.gdshader")
\tspray.material=draw_material
\tvar img:=Image.create(6,6,false,Image.FORMAT_RGBA8);img.fill(Color.WHITE);spray.texture=ImageTexture.create_from_image(img)
\tadd_child(spray);move_child(spray,get_children().find(pier));spray.emitting=true

func _refresh() -> void:
\tsuper._refresh()
\tif not solver.initialized:return
\tsurface_material.set_shader_parameter("ocean_map",solver.ocean_texture)
\tsurface_material.set_shader_parameter("foam_map",solver.foam_textures[solver.front])
\tsurface_material.set_shader_parameter("world_size",Vector2(solver.grid_size)*solver.WIDTH_METRES/solver.grid_size.x)
\tif spray!=null:
\t\tvar mat:=spray.process_material as ShaderMaterial
\t\tmat.set_shader_parameter("sim_state",solver.state_textures[solver.front]);mat.set_shader_parameter("bed_map",solver.bed_texture)
\t\tmat.set_shader_parameter("foam_map",solver.foam_textures[solver.front]);mat.set_shader_parameter("enabled",not solver.paused and solver.foam_enabled and mode==0)
\t\tspray.speed_scale=0.0 if solver.paused else 1.0

func set_view(index: int) -> void:
\tsuper.set_view(index)
\tif spray!=null:spray.visible=index==0

func _process(_delta: float) -> void:
\tif spray!=null and is_instance_valid(solver):
\t\tspray.speed_scale=0.0 if solver.paused else 1.0
'''
(root/'scenes/prototypes/seaside_hybrid_demo.gd').write_text(style,encoding='utf-8')
(root/'scenes/prototypes/seaside_hybrid_demo.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scenes/prototypes/seaside_hybrid_demo.gd" id="1"]\n[node name="SeasideHybrid" type="Control"]\nlayout_mode = 3\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\ngrow_horizontal = 2\ngrow_vertical = 2\nscript = ExtResource("1")\n',encoding='utf-8')
license_bytes=(source/'LICENSE-upstream.txt').read_bytes()
(art/'SWE_UPSTREAM_LICENSE.txt').write_bytes(license_bytes)
if not (doc/'map-baseline.json').exists():
    (doc/'map-baseline.json').write_text(json.dumps({'sha256':hashlib.sha256((root/'data/rooms/r04.json').read_bytes()).hexdigest()}),encoding='utf-8')
print('Built isolated FFT/SWE hybrid source files.')
