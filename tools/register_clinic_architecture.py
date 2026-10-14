"""Register unchanged generated PNGs and restyle only the compact clinic."""
from copy import deepcopy
import hashlib
import json
import math
from pathlib import Path
import shutil
from PIL import Image
from compact_clinic import contains_wall

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT/'docs/art/clinic-restoration'
ART = ROOT/'art/architecture/clinic_v1'
SHADER = 'res://art/architecture/v25/safe_edges_v25.gdshader'

def read(p): return json.loads(p.read_text(encoding='utf-8'))
def write(p,v):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(v,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def apply_to_room(room, manifest):
    definitions={a['id']:a for a in manifest['assets']}
    area=next(r['rect'] for r in room['visibility_rooms'] if r['id']=='clinic')
    for surface in room['architecture']['wall_surfaces']:
        rect=room['walls'][surface['wall_index']]
        if not contains_wall(area,rect): continue
        base=surface.get('clinic_base_asset',surface['grid_tile_asset'])
        if base=='prison_h_c': id=f'clinic_wall_h_{int((rect[0]-area[0]+20)%320/20):02d}'
        elif base=='prison_h_short_c': id='clinic_wall_h_short'
        else: id={'prison_l_se':'clinic_corner_nw','prison_l_sw':'clinic_corner_ne',
                  'prison_l_ne':'clinic_corner_sw','prison_l_nw':'clinic_corner_se',
                  'prison_v_long':'clinic_wall_v_long','prison_v_short':'clinic_wall_v_short',
                  'prison_lintel_80':'clinic_lintel_80','prison_lintel_20':'clinic_lintel_20'}[base]
        assert id in definitions
        surface.update(grid_tile_asset=id,clinic_base_asset=base)
    door=next(f for f in room['fixtures'] if f['id']=='campus-clinic')
    if door.get('access_id')!='clinic-entry':
        door['asset_id']='doorway_clinic_open_v1'
    sign=next(f for f in room['fixtures'] if f['id']=='campus-clinic-record-sign')
    sign.update(asset_id='clinic_medical_sign',rect=[area[0]+330,area[1]-85,*definitions['clinic_medical_sign']['footprint_world_size']],draw_depth=area[1]+30)
    room['fixtures']=[f for f in room['fixtures'] if f['id'] not in ['campus-clinic-window','campus-clinic-wall-light']]
    for id,asset,x,y in [('campus-clinic-window','clinic_frosted_window',area[0]+80,area[1]-90),('campus-clinic-wall-light','clinic_wall_light',area[0]+230,area[1]-85)]:
        room['fixtures'].append(dict(id=id,asset_id=asset,rect=[x,y,*definitions[asset]['footprint_world_size']],
                                     blocks_movement=False,blocks_sight=False,draw_depth=area[1]+30))
    room['clinic_architecture_version']=1

def door_parts(path,region,width):
    # Read alpha only, retaining the PNG unchanged. Thin row slabs follow the
    # angled leaf tips and exclude empty margins; this is prepared at authoring.
    x,y,w,h=region
    mask=Image.open(path).getchannel('A').crop((x,y,x+w,y+h)).point(lambda v:255 if v>=200 else 0)
    scale=width/w; step=max(1,int(1/scale)); result=[]
    for left,right in [(0,int(w*.3)),(int(w*.7),w)]:
        for top in range(0,h,step):
            bottom=min(h,top+step)
            box=mask.crop((left,top,right,bottom)).getbbox()
            if box is None: continue
            x0,_,x1,_=box
            # Half-unit outward quantization joins noisy source contours into
            # a few slabs without rebuilding or sampling alpha at runtime.
            x0=math.floor((left+x0)*scale*2)/2
            x1=math.ceil((left+x1)*scale*2)/2
            part=[x0,top*scale,x1-x0,(bottom-top)*scale]
            if result and abs(result[-1][0]-part[0])<.05 and abs(result[-1][2]-part[2])<.05 and abs(result[-1][1]+result[-1][3]-part[1])<.001:
                result[-1][3]+=part[3]
            else: result.append(part)
    return result

def main(update_room=True):
    source=read(DOC/'architecture-assets.json')
    originals={}
    for a in source['assets']:
        p=ROOT/a['path'];p.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(a['source'],p)
        assert sha(p)==sha(Path(a['source']))
        im=Image.open(p)
        assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
        box=im.getchannel('A').point(lambda v:255 if v>=128 else 0).getbbox()
        x,y,x1,y1=box
        originals[a['key']]=dict(texture='res://'+a['path'],texture_size=list(im.size),
             region=[max(0,x-3),max(0,y-3),x1-x+6,y1-y+6],sha256=sha(p),
             alpha_core_shader=SHADER,source_kind='built-in-imagegen-original-png')
    # Crop metadata only: matching rail bands are reused in every orientation.
    # There is no raster recoloring, rotation, resampling or edited PNG output.
    wall=deepcopy(originals['wall_profile']);wall['region']=[54,266,1340,580]
    wx,wy,ww,wh=wall['region']
    cap_h=98
    assets=[]
    originals['corner_post'].update(id='clinic_corner_post',name='医务室金属护角',render_mode='wall_attachment',
         world_size=[8,130],render_size=[8,130],ground_rect=[0,0,*originals['corner_post']['region'][2:]],
         footprint_world_size=[8,130],blocking=False,proportion_locked=True,shadow_baked=True,editor_subcategory='attachments')
    assets.append(originals['corner_post'])
    legacy={}
    for p in ['v36','v38']:
        legacy.update({a['id']:a for a in read(ROOT/f'art/architecture/{p}/manifest.json')['assets']})
    def patch(src,dest,**extra): return dict(source=src,destination=dest,role='complete_wall_body',**extra)
    def face(width,phase,y=0):
        result=[];cursor=0
        while cursor<width:
            current=(phase+cursor)%320
            length=min(width-cursor,320-current)
            result.append(patch([wx+current/320*ww,wy,length/320*ww,wh],[cursor,y,length,120]))
            cursor+=length
        return result
    def cap(width,height,x=0,y=0):
        return patch([wx+200,wy,height/320*ww,cap_h],[x,y,width,height],rotation_quarters=1)
    def register(id,name,base,patches,dims=None):
        old=legacy[base]
        a=deepcopy(wall)
        a.update(id=id,name=name,world_size=dims or old['render_size'],render_size=dims or old['render_size'],
                 render_mode=old['render_mode'],blocking=False,assembly_patches=patches,
                 collision_parts=deepcopy(old['collision_parts']),connections=old['connections'],
                 connection_tag='clinic/'+old['connection_tag'],authoring_set='clinic-v1',legacy_id=base,
                 grid_tile={'cell':20,'columns':(dims or old['render_size'])[0]/20,'rows':(dims or old['render_size'])[1]/20,'parameterized_shader':False})
        assets.append(a)
    for i in range(16): register(f'clinic_wall_h_{i:02d}',f'医务室横墙 {i+1:02d}','prison_h_c',face(40,i*20))
    register('clinic_wall_h_short','医务室短横墙','prison_h_short_c',face(20,180))
    register('clinic_wall_v_long','医务室纵墙','prison_v_long',[cap(20,120)])
    register('clinic_wall_v_short','医务室短纵墙','prison_v_short',[cap(20,20)])
    for side,base,phase,right,south in [('nw','prison_l_se',0,False,False),('ne','prison_l_sw',200,True,False),
                                      ('sw','prison_l_ne',0,False,True),('se','prison_l_nw',200,True,True)]:
        h=140 if south else 120
        patches=face(40,phase,20 if south else 0)
        x=20 if right else 0
        # The two rail edges turn together at a diagonal mitre. A rectangular
        # overlay leaves a T-shaped blue line; the old full-height post also
        # doubled the outside rail and stopped abruptly at the next wall tile.
        patches.append(cap(20,20 if south else 100,x,0 if south else 20))
        joint=cap(20,20,x,20 if south else 0)
        joint['clip_polygon'] = (
            [[0,0],[1,0],[1,1]] if south and right else
            [[0,0],[1,0],[0,1]] if south else
            [[1,0],[1,1],[0,1]] if right else
            [[0,0],[1,1],[0,1]])
        patches.append(joint)
        register('clinic_corner_'+side,'医务室转角 '+side.upper(),base,patches)
    for length in [80,20]:
        register(f'clinic_lintel_{length}',f'医务室门楣 {length}',f'prison_lintel_{length}',
                 [patch([wx+200,wy,length/320*ww,cap_h],[0,0,length,20])])
    for key,id,name,width in [('window','clinic_frosted_window','医务室磨砂窗',138),
                              ('sign','clinic_medical_sign','医务室搪瓷标牌',114),
                              ('light','clinic_wall_light','医务室壁灯',46),
                              ('open_door','doorway_clinic_open_v1','医务室双开玻璃门 · 开启',200)]:
        a=deepcopy(originals[key]);_,_,w,h=a['region'];height=h/w*width
        a.update(id=id,name=name,render_mode='wall_attachment',render_size=[width,height],world_size=[width,height],
                 ground_rect=[0,0,w,h],footprint_world_size=[width,height],blocking=False,
                 proportion_locked=True,shadow_baked=True,editor_subcategory='attachments')
        if key=='open_door':
            a.update(render_mode='embedded_door',footprint_world_size=[180,20],proportion_locked=False,editor_subcategory='doors',grid_door={'cell':20})
            a['door_presentation']={'door_art':id,'door_art_size':[width,height],
                'visual_jambs':[[0,0,44,height],[156,0,44,height]],
                'visual_solid_parts':door_parts(ART/'open_door.png',a['region'],width),
                'body_profile':'human_silhouette'}
        assets.append(a)
    manifest=dict(schema=2,version='clinic-v1',assets=assets)
    write(ART/'manifest.json',manifest)
    path=ROOT/'data/rooms/r04.json';original_hash=sha(path);room=read(path)
    if update_room:
        if not (DOC/'architecture-map-before.json').exists(): shutil.copyfile(path,DOC/'architecture-map-before.json')
        shutil.copyfile(path,DOC/'architecture-last-input-map.json')
        shutil.copyfile(path,DOC/'last-input-map.json')
        apply_to_room(room,manifest)
        assert sha(path)==original_hash,'Saved map changed during registration; rerun on latest saved data.'
        write(path,room)
    write(DOC/'architecture-registration.json',dict(mode=source['mode'],assets=[dict(key=a['key'],path=a['path'],sha256=sha(ROOT/a['path'])) for a in source['assets']],
          map_before_sha256=original_hash,map_after_sha256=sha(path),definition_ids=[a['id'] for a in assets]))
    print(f'Registered {len(assets)} clinic architecture definitions from 6 unchanged original PNGs.')

if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--definitions-only',action='store_true')
    main(not parser.parse_args().definitions_only)
