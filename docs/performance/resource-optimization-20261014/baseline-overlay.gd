extends SceneTree
func _initialize():
 var packer=PCKPacker.new()
 var dest="res://docs/performance/resource-optimization-20261014/baseline-overlay.pck"
 packer.pck_start(dest)
 for name in ["runtime_texture_store.gd","lighting_system.gd"]:
  packer.add_file("res://scripts/presentation/"+name,"res://docs/performance/resource-optimization-20261014/baseline/scripts/presentation/"+name)
 var folder="res://docs/performance/resource-optimization-20261014/baseline/runtime_textures/"
 for file in DirAccess.get_files_at(folder):
  packer.add_file("res://art/runtime_textures/"+file,folder+file)
 print("BASELINE_OVERLAY "+str(packer.flush()))
 quit()
