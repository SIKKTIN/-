from pathlib import Path
import json,hashlib
root=Path(r'E:/Project/Godot/这次怎么逃');doc=root/'docs/art/architecture-v28'
tex='res://art/architecture/v28/cafeteria_turn_master_v28.png'
sha=hashlib.sha256((root/'art/architecture/v28/cafeteria_turn_master_v28.png').read_bytes()).hexdigest()
x=[142,458,1110];y=[161,477,1093]
rows=[]
for cross in [24,20]:
    width=cross+56
    for right in [False,True]:
        suffix='_20' if cross==20 else ''
        id='cafeteria_turn_'+('r' if right else 'l')+suffix+'_v28'
        dests=[[0,0,cross,24],[cross,0,56,24],[0,24,cross,56]]
        sources=[[x[0],y[0],x[1]-x[0],y[1]-y[0]],[x[1],y[0],x[2]-x[1],y[1]-y[0]],[x[0],y[1],x[1]-x[0],y[2]-y[1]]]
        patches=[]
        for s,d in zip(sources,dests):
            if right:d=[width-d[0]-d[2],d[1],d[2],d[3]]
            patches.append(dict(source=s,destination=d,mirror_x=right,transpose=False,rotation_quarters=0,modulate=[1,1,1,1],role='complete continuous L coping stone'))
        rows.append(dict(id=id,name='完整'+('右' if right else '左')+'L转角积木'+('·20厚' if suffix else ''),texture=tex,texture_size=[1254,1254],region=[0,0,1254,1254],world_size=[width,80],render_size=[width,80],render_mode='architecture_corner_l',blocking=False,interactive=False,shadow_baked=False,self_shading_baked=True,map_level_mirror_x=False,cross_width_world=cross,horizontal_cap_depth_world=24,return_start_world=80,transparent_notch=[0 if right else cross,24,56,56],assembly_patches=patches,sha256=sha,alpha_core_shader='res://art/architecture/v25/safe_edges_v25.gdshader',editor_icon='res://art/editor/v08/icons/'+id+'.tres'))
m=dict(schema=2,version='architecture-v28-20261006',style='FIRST-VERSION-COMPLETE-CORNER',master_texture=tex,master_sha256=sha,edge_shader='res://art/architecture/v25/safe_edges_v25.gdshader',source_grid={'x':x,'y':y},physical_contract={'exterior_width':24,'interior_width':20,'front_height':90,'door_width':180},assets=rows)
interface=dict(schema=2,manifest='res://art/architecture/v28/manifest.json',source_png=tex,source_size=[1254,1254],source_grid_x=x,source_grid_y=y,source_coordinates='absolute original PNG; all asset.region full PNG',layout={'cross24':{'size':[80,80],'north_arm':[0,0,80,24],'south_arm':[0,24,24,56]},'cross20':{'size':[76,80],'north_arm':[0,0,76,24],'south_arm':[0,24,20,56]}},anchor={'existing_junction_rect':[80,150],'left_tile_offset':[0,0],'right_24_tile_offset':[0,0],'right_20_tile_offset':[4,0],'y_from_original_wing_top':6.48,'y_from_baseline':-115.02},integration={'retain':'Original facade body below tile north arm; original H beyond80/76; original V27 straight V source; original columns/lintel unchanged','replace':'Remove old elbow and all old junction V patches. Dedicated tile replaces full north cap span80/76 and first80 of longitudinal coping; preserve underlying original H facade below northcap24. Do not draw old rectangular cap below new outer chamfer.','continued_V':'tile_origin_y=corner_origin_y+80; render_start same80; period123.1413612565 from V27 unchanged; reset at new block end so stone joint is deliberate','face_clip':'Old wing face role stays but subtract dedicated tile north-arm rectangle (y0..24); left20 retains old face cap x76..80, right20 retains x0..4. Extended uses original middle, no original-wing face.','mirror':'all map mirrors false; right reflection is explicit in patch UV and geometry','multi_source':'V28 L is separate new texture. Runtime needs dedicated turn asset alongside preserved old facade/straight-run source; do not sample old facade from new PNG.'},editor='4 MeshTexture icons/standalone complete L',notch='lower inner quadrant remains truly transparent, never bbox-shadow fill',review='single continuous stone top and chamfered inner shadow bend; no square pad/transverse assembly seam')
for rel,data in [('art/architecture/v28/manifest.json',m),('art/editor/v08/manifest.json',dict(schema=1,assets=[dict(id=a['id'],name=a['name'],category='furniture',editor_icon=a['editor_icon']) for a in rows],tools=[])),('docs/art/architecture-v28/interface.json',interface)]:
    p=root/rel;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'components':4,'source_sha':sha,'size24':[80,80],'size20':[76,80]}))
