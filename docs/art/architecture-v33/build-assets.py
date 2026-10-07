from pathlib import Path
import json, hashlib, shutil
from PIL import Image

ROOT = Path(r'E:/Project/Godot/这次怎么逃')
DOC = ROOT / 'docs/art/architecture-v33'
PNG = ROOT / 'art/architecture/v33/full_wall_master_v33.png'
SOURCE = Path(r'C:/Users/gst20/.codex/generated_images/01a10697-9228-7c00-906b-43051bade1e0/exec-087f85c0-0f69-4cf4-b30b-4f09c6df3b44.png')
PNG.parent.mkdir(parents=True, exist_ok=True)
shutil.copy2(SOURCE, PNG)
SHA = hashlib.sha256(PNG.read_bytes()).hexdigest()
TEX = 'res://art/architecture/v33/full_wall_master_v33.png'
SY = 121.5 / 370
PERIOD = 288 * SY
ROWS = []

def patch(s, d, role, mirror=False):
    return dict(source=s, destination=d, role=role, transpose=False, mirror_x=mirror,
                rotation_quarters=0, modulate=[1,1,1,1])

def asset(id, name, size, patches, mode, **extra):
    a = dict(id=id, name=name, texture=TEX, texture_size=[1536,1024], region=[0,0,1536,1024],
             world_size=size, render_size=size, render_mode=mode, assembly_patches=patches,
             blocking=False, interactive=False, shadow_baked=False, self_shading_baked=True,
             sha256=SHA, alpha_core_shader='res://art/architecture/v25/safe_edges_v25.gdshader',
             editor_icon='res://art/editor/v13/icons/'+id+'.tres')
    a.update(extra); ROWS.append(a); return a

# Short open joining arms, with the entire facade in each rectangle. No old facade underneath.
for cross in [20,24]:
    suffix = '_20' if cross == 20 else ''
    w = 48 + cross
    asset('cafeteria_t'+suffix+'_v33', '完整短臂圆弧T·'+str(cross)+'厚', [w,121.5],
          [patch([590,130,120,370],[0,0,24,121.5],'complete_wall_left'),
           patch([710,130,120,370],[24,0,cross,121.5],'complete_wall_root'),
           patch([830,130,120,370],[24+cross,0,24,121.5],'complete_wall_right')],
          'architecture_junction_t', stem_rect=[24,0,cross,121.5],
          return_start_world=121.5, full_body=True, open_left=True, open_right=True)
    for right in [False,True]:
        hand = 'r' if right else 'l'
        asset('cafeteria_wall_v_'+hand+suffix+'_v33', '同源'+hand+'纵墙·'+str(cross)+'厚',
              [cross,PERIOD*2],
              [patch([710,382,120,288],[0,k*PERIOD,cross,PERIOD], 'same_source_vertical_repeat',right) for k in range(2)],
              'architecture_tiled_top', cross_width_world=cross, tile_period_world=PERIOD,
              source_repeat_window=[710,382,120,288])
    asset('cafeteria_end'+suffix+'_v33', '同源完整端面·'+str(cross)+'厚', [cross,90],
          [patch([710,670,120,301],[0,0,cross,90],'complete_same_source_endface')],
          'architecture_endface', full_body=True)

# Reversed adjoining repeats share exactly the same boundary samples. Neither edge is capped.
asset('cafeteria_wall_mid_v33', '完整可续接横墙', [76,121.5],
      [patch([400,130,190,370],[0,0,38,121.5],'complete_horizontal_repeat'),
       patch([400,130,190,370],[38,0,38,121.5],'complete_horizontal_repeat',True)],
      'architecture_tiled_facade', full_body=True, open_left=True, open_right=True)
# Source extensions explicitly share the short T's two cut edges.
for hand, s, mirror in [('l',[400,130,190,370],False),('r',[950,130,186,370],False)]:
    asset('cafeteria_wall_join_'+hand+'_v33', 'T横墙续接·'+hand, [s[2]*.2,121.5],
          [patch(s,[0,0,s[2]*.2,121.5],'full_body_T_join',mirror)],
          'architecture_tiled_facade', full_body=True, open_left=True, open_right=True)

# Corners use the full corresponding half of the integrated junction, including its body and foot.
for hand, src in [('l',[710,130,240,370]),('r',[590,130,240,370])]:
    asset('cafeteria_turn_'+hand+'_v33', '完整同源L角·'+hand, [48,121.5],
          [patch(src,[0,0,48,121.5],'complete_L_wall')], 'architecture_junction_l',
          return_start_world=121.5, stem_x=0 if hand=='l' else 24, cross_width_world=24,
          full_body=True)
for hand in ['left','right']:
    asset('cafeteria_jamb_'+hand+'_v33', '同源完整门柱·'+hand, [32,121.5],
          [patch([710,670,120,301],[0,0,32,121.5],'complete_same_source_jamb',hand=='right')],
          'architecture_pillar', full_body=True)
asset('cafeteria_lintel_v33', '同源门楣', [180,31.5],
      [patch([400,130,234,87],[0,0,180,31.5],'same_source_lintel')], 'architecture_lintel')

interface = dict(schema=3, master=TEX, master_sha256=SHA, generation_mode='built-in imagegen',
    pixel_policy='raw copy only; native UV/mesh resources; no painted or resampled production PNG',
    user_shortening='左右各保留24world短臂，长横墙靠独立直墙块拼接',
    full_wall_source=[590,130,360,370], full_height=121.5, source_y_scale=SY,
    T_sizes={'20':[68,121.5],'24':[72,121.5]}, stem_x=24,
    original_source_stem=[710,130,120,370], horizontal_cap_visible_world=87*SY,
    source_repeat_window=[710,382,120,288], vertical_period_world=PERIOD,
    source_at_T_bottom_y=500, phase_source_pixels_at_T_bottom=118,
    phase_world_at_T_bottom=118*SY, V_origin_local_y=(382-130)*SY,
    V_origin_world_y=1140+(382-130)*SY, V_clip_world_y=1261.5,
    endface_source=[710,670,120,301], endface_size_y=90,
    kitchen={'T_offsets':[[146,0],[786,0]], 'T_full_replacement_rects':[[146,0,68,121.5],[786,0,68,121.5]],
             'physical_roots_x':[1270,1910], 'H_origin_y':1140, 'H_end_y':1261.5,
             'V_southface_y':1370, 'remove_old_body_and_foot':True,
             'outer_L_sizes':[48,121.5], 'outer_L_stem_x':{'l':0,'r':24}},
    mirror_policy='right T whole-asset mirror once; V_r has X mirror baked in its UV. Never flip longitudinal Y.',
    joining_policy='No terminal outlines on H edges; T is a short complete wall piece, not a thin overlay. Clip H all-height under complete T/L. Native actual review required.',
    sign_policy='V24 portal PNG has no sign. Existing map architecture.wall_sign may be drawn independently; do not retain any old facade to retain a sign.',
    complete_asset_ids=[a['id'] for a in ROWS])
manifest=dict(schema=2,version='architecture-v33-20261007',style='COMPLETE-OPEN-SHORT-ARM-WALL',
              master_texture=TEX,master_sha256=SHA,assets=ROWS,
              edge_shader='res://art/architecture/v25/safe_edges_v25.gdshader',
              physical_contract=dict(exterior_width=24,interior_width=20,front_height=90,door_width=180))
for rel, obj in [('art/architecture/v33/manifest.json',manifest),('art/editor/v13/manifest.json',dict(schema=1,assets=[dict(id=a['id'],name=a['name'],category='furniture',editor_icon=a['editor_icon']) for a in ROWS],tools=[])),('docs/art/architecture-v33/interface.json',interface)]:
    p=ROOT/rel;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
# Source validation only; no raster manipulation.
im=Image.open(PNG)
checks=[]
for a in ROWS:
    for p in a['assembly_patches']:
        x,y,w,h=p['source'];checks.append(0<=x<x+w<=im.width and 0<=y<y+h<=im.height)
assert all(checks)
assert im.mode=='RGBA' and im.getpixel((0,0))[3]==0
review=dict(source_sha256=SHA,raw_copy_verified=SHA==hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
            rgba_size=list(im.size),source_rectangles_in_bounds=len(checks),source_core='wall silhouette alpha; transparent exterior',
            T_full_height_source=[130,500],horizontal_body_and_foot_source=[217,500],
            T_V_source_y_continuity=500,short_arms_world=24,visual_review_pending=True)
(DOC/'source-review.json').write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(assets=len(ROWS),source_sha256=SHA,period=PERIOD,source_rectangles=len(checks))))
