extends SceneTree
func _initialize():
	seed(141014)
	var old=load("res://docs/dev/smoothness-optimization-2026-10-14/solid_spatial_index-before.gd").new()
	var current=load("res://scripts/core/solid_spatial_index.gd").new()
	var solids: Array[Rect2]=[]
	for i in range(400):solids.append(Rect2(randi_range(-500,6000),randi_range(-500,4500),randi_range(1,600),randi_range(1,300)))
	solids.append_array([Rect2(128,256,128,128),Rect2(128,256,128,128),Rect2(-128,-256,256,512)])
	old.rebuild(solids,1);current.rebuild(solids,1)
	var failed: Array=[]
	for i in range(500):
		var from:=Vector2(randf_range(-600,6000),randf_range(-600,4500))
		var to:=Vector2(randf_range(-600,6000),randf_range(-600,4500))
		var radius: float=[0.0,10.0,18.0,128.0,256.0][i%5]
		var a: Array=old.along_segment(from,to,radius)
		var b: Array=current.along_segment(from,to,radius)
		if a!=b:failed.append("segment_"+str(i))
	var held_buckets: Dictionary=current.buckets
	current.rebuild(solids.duplicate(),2)
	if current.revision!=2 or not is_same(held_buckets,current.buckets):failed.append("unchanged_revision")
	solids.append(Rect2(9000,9000,200,200))
	current.rebuild(solids,3)
	if not current.nearby(Vector2(9100,9100),0).has(solids.back()):failed.append("changed_geometry")
	# Removing/reordering inputs must not leave stable bucket IDs pointing
	# at another rectangle; duplicate obstacles retain their multiplicity.
	for step in range(80):
		if step%4==0:solids.reverse()
		elif step%4==1:solids.remove_at(randi_range(0,solids.size()-1))
		elif step%4==2:solids.append(solids[randi_range(0,solids.size()-1)])
		else:solids[randi_range(0,solids.size()-1)]=Rect2(randf_range(-500,6000),randf_range(-500,4500),130,130)
		old.rebuild(solids,step+4);current.rebuild(solids,step+4)
		for i in range(5):
			var from:=Vector2(randf_range(-600,6000),randf_range(-600,4500))
			var to:=Vector2(randf_range(-600,6000),randf_range(-600,4500))
			if counts(old.along_segment(from,to,18))!=counts(current.along_segment(from,to,18)):failed.append("changed_segment_"+str(step))
			if counts(old.nearby(from,200))!=counts(current.nearby(from,200)):failed.append("changed_nearby_"+str(step))
	solids.clear()
	current.rebuild(solids,4)
	if not current.buckets.is_empty() or not current.rects.is_empty():failed.append("clear")
	var result: Dictionary={"checks":1303,"failed":failed}
	FileAccess.open("res://docs/dev/smoothness-optimization-2026-10-14/spatial-checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("SPATIAL "+JSON.stringify(result));quit(0 if failed.is_empty() else 1)
func counts(a: Array) -> Dictionary:
	var result: Dictionary={}
	for rect in a:result[rect]=int(result.get(rect,0))+1
	return result
