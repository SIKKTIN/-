extends SceneTree
func _initialize():
 var image=Image.load_from_file("res://art/architecture/cafeteria_v1/roof.png").get_region(Rect2i(0,0,443,511))
 var size=image.get_size()
 image.resize(444,512,Image.INTERPOLATE_LANCZOS)
 image.generate_mipmaps()
 var before=image.get_data_size()
 var error=image.compress(Image.COMPRESS_BPTC)
 var texture=ImageTexture.create_from_image(image)
 texture.set_size_override(size)
 var output="res://docs/performance/resource-optimization-20261014/compression-probe.res"
 ResourceSaver.save(texture,output,ResourceSaver.FLAG_COMPRESS)
 var restored=ResourceLoader.load(output,"",ResourceLoader.CACHE_MODE_IGNORE)
 print(JSON.stringify({"error":error,"before":before,"after":image.get_data_size(),"logical":str(texture.get_size()),"restored":str(restored.get_size()),"data":str(restored.get_image().get_size()),"format":image.get_format()}))
 quit()
