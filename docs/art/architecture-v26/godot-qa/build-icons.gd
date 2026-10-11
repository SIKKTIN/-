extends SceneTree
const Assembly=preload("res://assembly.gd")
func _initialize() -> void:
	call_deferred("build_icons")
func build_icons() -> void:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/architecture/v26/manifest.json"))
	var texture: Texture2D=load(manifest.master_texture)
	var checks: Array=[]
	var errors: Array=[]
	for asset in manifest.assets:
		var icon:=Assembly.mesh_icon(asset,texture)
		var saved:=ResourceSaver.save(icon,asset.editor_icon)
		var loaded: Texture2D=load(asset.editor_icon)
		var passed:=saved==OK and loaded!=null and loaded.get_size()==Vector2(128,128)
		if not passed: errors.append(asset.id)
		checks.append({"id":asset.id,"icon_type":"MeshTexture","passed":passed,"patch_count":asset.assembly_patches.size()})
	var result: Dictionary={"checked":checks.size(),"passed":errors.is_empty(),"checks":checks,"errors":errors,"pixel_policy":"mesh geometry/UV resource using unchanged single master PNG; no baked derivative production PNG"}
	FileAccess.open("res://icons-qa.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print(JSON.stringify({"checked":checks.size(),"passed":result.passed,"errors":errors}))
	quit(0 if errors.is_empty() else 1)
