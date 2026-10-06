from pathlib import Path
import json,hashlib,copy
from PIL import Image
root=Path(r'E:/Project/Godot/这次怎么逃');doc=root/'docs/art/architecture-v26'
tex='res://art/architecture/v26/wall_tiles_master_v26.png'
sha=hashlib.sha256((root/'art/architecture/v26/wall_tiles_master_v26.png').read_bytes()).hexdigest()
mat={'coping':[0,0,1536,196],'plaster':[0,208,1536,496],'plinth':[0,708,1536,312]}
period=128.0
def strip(key,dest,phase=0.0,vertical=False,tint=1.0):
    out=[];s=mat[key]; x,y,w,h=dest;length=h if vertical else w;cursor=0.0
    while cursor<length-0.000001:
        u=(phase+cursor)%period
        take=min(length-cursor,period-u)
        source=[s[0]+s[2]*u/period,s[1],s[2]*take/period,s[3]]
        target=[x,y+cursor,w,take] if vertical else [x+cursor,y,take,h]
        out.append({'source':source,'destination':target,'transpose':vertical,'rotation_quarters':0,'modulate':[tint,tint,tint,1.0],'material':key,'phase_start':phase+cursor,'phase_axis':'y' if vertical else 'x'})
        cursor+=take
    return out
def asset(id,name,size,patches,mode,icon):
    return {'id':id,'name':name,'texture':tex,'texture_size':[1536,1024],'region':[0,0,1536,1024],'world_size':size,'render_size':size,'render_mode':mode,'blocking':False,'interactive':False,'source_is_opaque':True,'shadow_baked':False,'self_shading_baked':False,'sha256':sha,'tile_unit':64,'tile_period':128,'assembly_patches':patches,'editor_icon':'res://art/editor/v06/icons/'+id+'.tres','icon_region_hint':icon,'source_coordinate_space':'absolute original PNG pixels','normal_lighting_only':'modulate on same coping source; side0.78/frontstone0.84, no separate side material'}
h=strip('coping',[0,0,128,20])+strip('coping',[0,20,128,4],tint=.78)+strip('plaster',[0,24,128,56])+strip('plinth',[0,80,128,34])
v=strip('coping',[0,0,20,128],vertical=True)+strip('coping',[20,0,4,128],vertical=True,tint=.78)
c=strip('coping',[0,0,80,20])+strip('coping',[24,20,56,4],phase=24,tint=.78)+strip('coping',[0,20,20,130],phase=20,vertical=True)+strip('coping',[20,20,4,130],phase=20,vertical=True,tint=.78)+strip('plaster',[24,24,56,56],phase=24)+strip('plinth',[24,80,56,34],phase=24)
def corner(thickness=24.0,right=False):
    side=thickness/6.0; pale=thickness-side
    leg_x=80-pale if right else 0
    shade_x=80-thickness if right else pale
    front_x=0 if right else thickness
    front_width=80-thickness
    patches=strip('coping',[0,0,80,20])+strip('coping',[front_x,20,front_width,4],phase=front_x,tint=.78)
    top=strip('coping',[leg_x,20,pale,130],phase=20,vertical=True)
    dark=strip('coping',[shade_x,20,side,130],phase=20,vertical=True,tint=.78)
    for patch in top+dark:
        patch['source'][3] *= thickness/24.0
    return patches+top+dark+strip('plaster',[front_x,24,front_width,56],phase=front_x)+strip('plinth',[front_x,80,front_width,34],phase=front_x)
c=corner()
cr=corner(right=True)
end=strip('plaster',[0,0,24,56])+strip('plinth',[0,56,24,34])
jamb=strip('coping',[0,0,32,31.5])+strip('coping',[0,31.5,32,90],vertical=True,tint=.84)
coping=strip('coping',[0,0,128,20])+strip('coping',[0,20,128,4],tint=.78)
lintel=strip('coping',[0,0,180,20])+strip('coping',[0,20,180,11.5],tint=.78)
rows=[asset('cafeteria_wall_h_v26','同源横墙·两格', [128,114],h,'architecture_tiled_wall',[0,0,1536,1020]),asset('cafeteria_wall_v_v26','同源纵墙顶',[24,128],v,'architecture_tiled_top',[0,0,1536,196]),asset('cafeteria_corner_l_v26','同源左L转角',[80,150],c,'architecture_corner_l',[0,0,1536,1020]),asset('cafeteria_corner_r_v26','同源右L转角',[80,150],cr,'architecture_corner_l',[0,0,1536,1020]),asset('cafeteria_end_v26','同源南向端面',[24,90],end,'architecture_end_face',[0,208,1536,812]),asset('cafeteria_jamb_v26','同源门柱',[32,121.5],jamb,'architecture_jamb',[0,0,1536,196]),asset('cafeteria_coping_v26','同源压顶·两格',[128,24],coping,'architecture_coping',[0,0,1536,196]),asset('cafeteria_lintel_v26','同源门楣',[180,31.5],lintel,'architecture_lintel',[0,0,1536,196])]
for thickness in [24.0,20.0]:
    side=thickness/6.0;pale=thickness-side
    suffix='_20' if thickness==20 else ''
    for right in [False,True]:
        if thickness==24 and not right: continue
        side_x=0 if right else pale;top_x=side if right else 0
        patches=strip('coping',[top_x,0,pale,128],vertical=True)+strip('coping',[side_x,0,side,128],vertical=True,tint=.78)
        for patch in patches: patch['source'][3]*=thickness/24.0
        row=asset('cafeteria_wall_v'+('_r' if right else '')+suffix+'_v26','同源纵顶'+('·右侧' if right else '')+('·20厚' if suffix else ''),[thickness,128],patches,'architecture_tiled_top',[0,0,1536,196]);row['cross_width_world']=thickness;rows.append(row)
    if thickness==20:
        for right in [False,True]:
            row=asset('cafeteria_corner_'+('r' if right else 'l')+'_20_v26','同源'+('右' if right else '左')+'L·20厚',[80,150],corner(thickness,right),'architecture_corner_l',[0,0,1536,1020]);row['cross_width_world']=20;rows.append(row)
        rows.append(asset('cafeteria_end_20_v26','同源南端面·20厚',[20,90],strip('plaster',[0,0,20,56])+strip('plinth',[0,56,20,34]),'architecture_end_face',[0,208,1536,812]))
for row in rows:
    row['phase_sensitive_axes']=['y'] if row['id']=='cafeteria_wall_v_v26' else ['x']
    if row['id'].startswith('cafeteria_corner'):
        row['phase_sensitive_axes']=['x','y']
manifest={'schema':2,'version':'architecture-v26-20261006','style':'FINAL-WARM-01','master_texture':tex,'master_sha256':sha,'edge_shader':'res://art/architecture/v25/safe_edges_v25.gdshader','tile_unit':64,'tile_period':128,'materials':mat,'physical_contract':{'exterior_width':24,'interior_width':20,'front_height':90,'door_width':180},'assets':rows}
(root/'art/architecture/v26/manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
editor={'schema':1,'assets':[{'id':r['id'],'name':r['name'],'category':'furniture','editor_icon':r['editor_icon']} for r in rows],'tools':[]}
(root/'art/editor/v06/manifest.json').write_text(json.dumps(editor,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
interface={'schema':2,'status':'candidate native preview pending','manifest':'res://art/architecture/v26/manifest.json','source_coordinate_space':'every patch.source is absolute1536x1024 original; every asset.region is full0,0,1536,1024','uv_order':'TL,TR,BR,BL; if transpose true reorder to TL,BL,BR,TR; then patch.mirror_x reorder TR,TL,BL,BR; then map-levelmirror if any; geometry alwayspositive','repeat_policy':{'unit':64,'period':128,'h_origin':'northmost L/H shared wall origin720','h_after80_corner_phase':80,'v_origin':'common north cap origin1147.5','v_after150_corner_phase':22,'partial_last':'intersect geometry, bilinear UV clip; no whole-end stretch','phase_offset_pixels':'offset along sourceU by phaseworld/128*1536; split if crossing128period'},'render_registration':{'north_baseline':1261.5,'north_h_cap_start':1147.5,'h_face_start':1171.5,'h_plinth_start':1227.5,'corner_bottom':1297.5,'jamb_top':1140,'jamb_front_start':1171.5},'width20_contract':'scale cross-section x24 to20 forV/L narrowarm; run period stays128, main20+side4 scales16.6667+3.3333','replacement_policy':'replace all oldHwing and v25corner/top painted surfaces; no switching source PNG alongrun; door metal fixture unchanged','texture_shading':'same coping sampler in all top/side/jamb/lintel, only face.modulate differs; no generated darkside bitmap','icons':'native MeshTexture geometry+UV derived from same assembly patches'}
(doc/'interface.json').write_text(json.dumps(interface,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
oldchecks={}
for version in ['v24','v25']:
    d=json.loads((root/('docs/art/architecture-'+version+'/delivery.json')).read_text(encoding='utf-8-sig'))
    oldchecks[version]=all(hashlib.sha256((root/f['path']).read_bytes()).hexdigest()==f['sha256'] for f in d['files'])
im=Image.open(root/'art/architecture/v26/wall_tiles_master_v26.png')
review={'mode':'built-in imagegen single master','prompt':'prompt.json','texture':tex,'size':im.size,'image_mode':im.mode,'alpha_range':[255,255],'master_sha256':sha,'source_copy_matches':Path("C:\\Users\\gst20\\.codex\\generated_images\\01a10697-9228-7c00-906b-43051bade1e0\\exec-df177858-d930-4ef8-95e1-48be9685affa.png").read_bytes()==(root/'art/architecture/v26/wall_tiles_master_v26.png').read_bytes(),'old_delivery_unchanged':oldchecks,'asset_count':len(rows),'all_assets_same_png':len(set(r['texture'] for r in rows))==1,'native_style_review':'pending long H/V/L assembly preview, resource load alone is insufficient'}
assert all(oldchecks.values()) and review['source_copy_matches']
(doc/'source-review.json').write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'asset_count':len(rows),'master_sha256':sha,'old_unchanged':oldchecks,'all_same_png':True,'patch_counts':{r['id']:len(r['assembly_patches']) for r in rows}}))
