from pathlib import Path
import json, hashlib

root = Path(r'E:/Project/Godot/这次怎么逃')
doc = root/'docs/art/architecture-v27'
tex = 'res://art/architecture/v24/cafeteria_portal_v24.png'
sha = hashlib.sha256((root/'art/architecture/v24/cafeteria_portal_v24.png').read_bytes()).hexdigest()
old = json.loads((root/'art/architecture/v24/manifest.json').read_text(encoding='utf-8-sig'))
original = {a['id']: a for a in old['assets']}
yscale = 121.5/375
run_scale = 144/573
window = [232, 192, 245, 24/yscale]
period = window[2]*run_scale
tile_height = period*2
front_bottom = (537-192)*yscale
rows = []

def patch(source, dest, transpose=False, mirror=False, role='original painted region'):
    return dict(source=source, destination=dest, transpose=transpose, mirror_x=mirror, rotation_quarters=0, modulate=[1,1,1,1], role=role)

def strip(x,y,width,length,phase=0,right=False):
    result=[]; cursor=0
    while cursor < length-1e-7:
        u=(phase+cursor)%period
        take=min(length-cursor, period-u)
        result.append(patch([window[0]+u/run_scale,window[1],take/run_scale,window[3]], [x,y+cursor,width,take],True,right,'coping source-window repeat; no whole-PNG wrap'))
        cursor+=take
    return result

def asset(id,name,size,patches,mode,width):
    row=dict(id=id,name=name,texture=tex,texture_size=[2170,725],region=[0,0,2170,725],world_size=size,render_size=size,render_mode=mode,blocking=False,interactive=False,shadow_baked=False,self_shading_baked=True,sha256=sha,assembly_patches=patches,source_coordinate_space='absolute original PNG pixels',cross_width_world=width,map_level_mirror_x=False,editor_icon='res://art/editor/v07/icons/'+id+'.tres',alpha_core_shader='res://art/architecture/v25/safe_edges_v25.gdshader')
    rows.append(row);return row

for width in [24,20]:
    suffix='_20' if width==20 else ''
    for right in [False,True]:
        hand='r' if right else 'l'
        leg_x=80-width if right else 0
        # Copy the adjacent wing exactly: no new wall-front texture or grading.
        wing=original['cafeteria_wing_'+('right' if right else 'left')+'_v24']
        wx,wy,sw,sh=wing['region']; world_w=wing['render_size'][0]
        dest_x=0 if right else width
        dest_w=80-width
        wing_offset=world_w-80 if right else 0
        source_x=wx+(wing_offset+dest_x)*sw/world_w
        face=patch([source_x,192,dest_w*sw/world_w,345],[dest_x,0,dest_w,front_bottom],role='unaltered original wing fragment; source scale and Y registration identical')
        # Elbow north square keeps the actual coping bevel, not a flat swatch.
        elbow=patch([window[0],192,24/run_scale,window[3]],[leg_x,0,width,24],False,right,'north elbow stone with baked bevel and outline')
        corner=asset('cafeteria_corner_'+hand+suffix+'_v27','原图'+('右' if right else '左')+'转角'+('·20厚' if suffix else ''),[80,150],[face,elbow]+strip(leg_x,24,width,126,right=right),'architecture_corner_l',width)
        corner['front_bottom_offset']=115.02
        corner['visible_front_bottom_offset']=front_bottom
        corner['trim_north_wing_world']=80
        corner['top_origin_from_north_baseline']=-115.02
        corner['return_continuation_from_north_baseline']=34.98
        corner['horizontal_registration']={'wing_id':wing['id'],'wing_width':world_w,'wing_local_offset':wing_offset,'copy_source_scale_x':sw/world_w,'copy_source_scale_y':1/yscale}
        v=asset('cafeteria_wall_v_'+hand+suffix+'_v27','原图'+('右' if right else '左')+'纵墙顶'+('·20厚' if suffix else ''),[width,tile_height],strip(0,0,width,tile_height,right=right),'architecture_tiled_top',width)
        v['tile_period_world']=period
        v['source_repeat_window']=window
        v['tile_origin_offset_from_corner']=24
    asset('cafeteria_end'+suffix+'_v27','原图纵墙端面'+('·20厚' if suffix else ''),[width,90],[patch([200,259,74,288],[0,0,width,90])],'architecture_end_face',width)

manifest=dict(schema=2,version='architecture-v27-20261006',style='FIRST-VERSION-RESTORED',master_texture=tex,master_sha256=sha,edge_shader='res://art/architecture/v25/safe_edges_v25.gdshader',physical_contract={'exterior_width':24,'interior_width':20,'front_height':90,'door_width':180},preserve_original_assets=['cafeteria_wing_left_v24','cafeteria_wing_right_v24','cafeteria_wall_mid_v24','cafeteria_jamb_left_v24','cafeteria_jamb_right_v24','cafeteria_lintel_v24'],assets=rows)
interface=dict(schema=2,manifest='res://art/architecture/v27/manifest.json',source_png=tex,source_sha256=sha,source_repeat_window=window,tile_period_world=period,tile_size_y=tile_height,top_origin_from_north_baseline=-115.02,corner_size=[80,150],corner_to_original_wing_y_offset=6.48,return_tile_origin_from_corner=24,return_render_start_from_corner=150,return_continuation_phase=(150-24)%period,patch_phase_policy='No phase_axis fields. All periods are explicitly split within source window; do not shift full-texture U. Align V tile_origin_y at corner origin+24. Clip first run below corner+150.',width20_policy='Only cross section becomes20; vertical run scale and period unchanged. Original adjacent wing fragment sampled at its original scale.',right_policy='separate right fragment from original right wing; V flips cross-section only after transpose, not run direction',preserve_original='Restore original complete V24 H/columns/lintel; trim80 only where these local corner components are installed. No A26 mother on those surfaces.',editor='10 2D MeshTexture icons from identical source PNG and patch geometry',native_preview='docs/art/architecture-v27/native-preview.png')
for rel,data in [('art/architecture/v27/manifest.json',manifest),('art/editor/v07/manifest.json',dict(schema=1,assets=[dict(id=r['id'],name=r['name'],category='furniture',editor_icon=r['editor_icon']) for r in rows],tools=[])),('docs/art/architecture-v27/interface.json',interface)]:
    p=root/rel;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
checks={}
for version in ['v24','v25','v26']:
    d=json.loads((root/('docs/art/architecture-'+version+'/delivery.json')).read_text(encoding='utf-8-sig'))
    checks[version]=all(hashlib.sha256((root/f['path']).read_bytes()).hexdigest()==f['sha256'] for f in d['files'])
assert all(checks.values())
(doc/'source-review.json').write_text(json.dumps(dict(source=tex,sha256=sha,new_production_png_count=0,asset_count=len(rows),old_deliveries_unchanged=checks,source_dimensions=[2170,725],original_cap_joint_x=[232,476],cap_window=window,world_stone_pitch=period,original_y_scale=yscale,corner_face_exact_wing_sampling=True),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'assets':len(rows),'period':period,'tile_y':tile_height,'old_unchanged':checks}))
