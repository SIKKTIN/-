extends SceneTree
func _initialize() -> void:
	for name in ["initialize","velocity","height_foam","foam","spectrum","ifft","unpack"]:
		var file:=load("res://art/fx/seaside_hybrid_v3/"+name+".glsl") as RDShaderFile
		print(name,": ",file.get_base_error())
		var spirv:=file.get_spirv()
		if spirv!=null:print(spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE))
	quit()
