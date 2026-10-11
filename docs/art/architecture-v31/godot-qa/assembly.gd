extends RefCounted

static func patch_uv(patch: Dictionary, texture_size: Vector2, phase_shift := Vector2.ZERO) -> PackedVector2Array:
	var s: Array = patch.source
	var lo := Vector2(s[0],s[1])/texture_size
	var hi := Vector2(s[0]+s[2],s[1]+s[3])/texture_size
	var uv := PackedVector2Array([lo,Vector2(hi.x,lo.y),hi,Vector2(lo.x,hi.y)])
	if patch.get("transpose",false):
		uv = PackedVector2Array([uv[0],uv[3],uv[2],uv[1]])
	if patch.get("mirror_x",false):
		uv = PackedVector2Array([uv[1],uv[0],uv[3],uv[2]])
	var shift := (phase_shift.y if patch.get("phase_axis","x") == "y" else phase_shift.x)/128.0
	for i in range(4): uv[i] += Vector2(shift,0)
	return uv

static func patch_color(patch: Dictionary) -> Color:
	var c: Array = patch.get("modulate",[1,1,1,1])
	return Color(c[0],c[1],c[2],c[3])

static func draw_component(canvas: CanvasItem, asset: Dictionary, texture: Texture2D, origin := Vector2.ZERO, phase := Vector2.ZERO, clip := Rect2(-10000,-10000,20000,20000)) -> void:
	for patch in asset.assembly_patches:
		var d: Array = patch.destination
		var box := Rect2(origin+Vector2(d[0],d[1]),Vector2(d[2],d[3]))
		var visible_area := box.intersection(clip)
		if not visible_area.has_area(): continue
		var uv := patch_uv(patch,texture.get_size(),phase)
		var a := (visible_area.position-box.position)/box.size
		var b := (visible_area.end-box.position)/box.size
		var cropped := PackedVector2Array()
		for point in [a,Vector2(b.x,a.y),b,Vector2(a.x,b.y)]:
			cropped.append(uv[0].lerp(uv[1],point.x).lerp(uv[3].lerp(uv[2],point.x),point.y))
		var p := visible_area.position
		var q := visible_area.end
		canvas.draw_polygon(PackedVector2Array([p,Vector2(q.x,p.y),q,Vector2(p.x,q.y)]),PackedColorArray([patch_color(patch)]),cropped,texture)

static func mesh_icon(asset: Dictionary, texture: Texture2D) -> MeshTexture:
	var size: Array = asset.render_size
	var dim := Vector2(size[0],size[1])
	var factor := 112.0/maxf(dim.x,dim.y)
	var margin := (Vector2(128,128)-dim*factor)/2.0
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for patch in asset.assembly_patches:
		var d: Array = patch.destination
		var p := margin+Vector2(d[0],d[1])*factor
		var q := p+Vector2(d[2],d[3])*factor
		var points := [p,Vector2(q.x,p.y),q,Vector2(p.x,q.y)]
		var uv := patch_uv(patch,texture.get_size())
		var start := vertices.size()
		for i in range(4):
			vertices.append(points[i])
			uvs.append(uv[i])
			colors.append(patch_color(patch))
		for i in [0,1,2,0,2,3]: indices.append(start+i)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	var icon := MeshTexture.new()
	icon.mesh=mesh
	icon.base_texture=texture
	icon.image_size=Vector2(128,128)
	return icon
