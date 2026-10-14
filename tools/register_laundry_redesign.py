"""Apply the approved laundry layout to the latest saved map with a hash guard.

Original imagegen PNGs are copied byte-for-byte. Regions/patches are native
asset metadata; other rooms, shared junctions and access permissions survive.
"""
from copy import deepcopy
from pathlib import Path
import argparse, hashlib, json, shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / 'docs/art/laundry-redesign-v01'
GENERATED = Path('C:/Users/gst20/.codex/generated_images/01a12f0d-4fc4-7dd2-b6a0-d189a674ef6e')
SHADER = 'res://art/architecture/v25/safe_edges_v25.gdshader'

def read(p): return json.loads(p.read_bytes())
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p, data):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, ensure_ascii=False, indent='\t')+'\n', encoding='utf-8')

def original(key, source, destination, region=None):
    src = GENERATED/source; dst = ROOT/destination
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)
    assert sha(src)==sha(dst)
    im = Image.open(dst)
    assert im.mode=='RGBA' and im.getchannel('A').getextrema()==(0,255)
    if region is None:
        x,y,r,b=im.getchannel('A').point(lambda a:255 if a>=180 else 0).getbbox()
        region=[max(0,x-3),max(0,y-3),min(im.width,r+3)-max(0,x-3),min(im.height,b+3)-max(0,y-3)]
    return dict(texture='res://'+destination,texture_size=list(im.size),region=region,runtime_size_limit=512,
                sha256=sha(dst),source_kind='built-in-imagegen-original-png',alpha_core_shader=SHADER)

def definitions():
    records=[]; props=[]
    sources=[('folding_table','exec-19d41b74-9c4d-4b93-8df1-046f4f772da7.png',285,65,'金属布草叠衣台'),
             ('dirty_station','exec-cce1e5f7-79ba-4f56-8cb4-6f1c96b3b462.png',210,75,'脏衣收集与蓝桶分拣组合')]
    for key,source,width,depth,name in sources:
        path=f'art/props/laundry_v2/{key}.png';a=original(key,source,path)
        _,_,w,h=a['region']; scale=width/w; height=h*scale
        a.update(id=f'laundry_{key}_v2',name='洗衣房 · '+name,render_mode='projected_prop',
                 world_size=[width,height],render_size=[width,height],footprint_world_size=[width,depth],
                 ground_rect=[0,h-depth/scale,w,depth/scale],elevation_world=height-depth,
                 blocking=True,interactive=False,shadow_baked=False,proportion_locked=True,editor_subcategory='furnishings')
        props.append(a);records.append(dict(key=key,path=path,sha256=a['sha256'],source=str(GENERATED/source)))
    legacy={a['id']:a for a in read(ROOT/'art/props/laundry_v1/manifest.json')['assets']}
    for old,new,width,depth,name in [('laundry_washer_v1','laundry_washer_v2',80,66,'工业滚筒洗衣机'),
                                   ('laundry_supply_pipe_v1','laundry_supply_pipe_v2',344,1,'四位供水管')]:
        a=deepcopy(legacy[old]);_,_,w,h=a['region'];scale=width/w;height=h*scale
        a.update(id=new,name='洗衣房 · '+name,world_size=[width,height],render_size=[width,height],
                 footprint_world_size=[width,depth],ground_rect=[0,h-depth/scale,w,depth/scale],elevation_world=height-depth)
        props.append(a)
    attachments={a['id']:a for a in read(ROOT/'art/props/prison_v17/manifest.json')['assets']}
    for old,key,width,name in [('wall_vent','vent',65,'墙面排风格栅'),('caged_wall_lamp','wall_lamp',44,'笼罩工作壁灯')]:
        a=deepcopy(attachments[old]);_,_,w,h=a['region'];scale=width/w;height=h*scale
        a.update(id=f'laundry_{key}_v2',name='洗衣房 · '+name,world_size=[width,height],render_size=[width,height],
                 footprint_world_size=[width,1],ground_rect=[0,h-1/scale,w,1/scale],elevation_world=height-1,
                 runtime_size_limit=256,proportion_locked=True,editor_subcategory='attachments',alpha_core_shader=SHADER,reused_from=old)
        props.append(a)
    write(ROOT/'art/props/laundry_v2/manifest.json',dict(schema=2,version='laundry-v2',assets=props))
    source='exec-9a996695-4e59-4713-b981-fb887bd1f23a.png'
    path='art/architecture/laundry_v2/north_door_states.png'
    # Atlas regions only. Shared frame patches use the open-state pixels.
    architecture=[]
    for state,region in [('open',[1086,150,449,577]),('closed',[241,150,447,577])]:
        a=original('north_door',source,path,region)
        a.update(id=f'doorway_laundry_north_{state}_v2',name='洗衣房北侧单扇钢门 · '+('敞开' if state=='open' else '关闭'),
                 render_mode='embedded_door',world_size=[140,120],render_size=[140,120],footprint_world_size=[120,20],
                 ground_rect=[0,0,region[2],region[3]],blocking=state=='closed',grid_door={'cell':20},editor_subcategory='doors')
        architecture.append(a)
    def patch(asset,source,destination): return dict(asset=asset,source=source,destination=destination)
    # Native shallow wall projection: always wider than high so horizontal
    # wall doors cannot be mistaken for a vertical doorway by Geometry.
    leaf=patch('doorway_laundry_north_closed_v2',[(300-241)/447,(209-150)/577,334/447,496/577],[27.4,12.3,96.4,105.8])
    frame=[patch('doorway_laundry_north_open_v2',[0,0,1,59/577],[0,0,140,12.3]),
           patch('doorway_laundry_north_open_v2',[0,59/577,88/449,518/577],[0,12.3,27.4,107.7]),
           patch('doorway_laundry_north_open_v2',[398/449,59/577,51/449,518/577],[124.1,12.3,15.9,107.7])]
    for a in architecture:
        a['door_presentation']=dict(door_art='doorway_laundry_north_open_v2',door_art_closed='doorway_laundry_north_closed_v2',
            door_art_size=[140,120],door_closed_patches=[leaf]+frame,
            visual_solid_parts=[[0,12.3,27.4,107.7],[124.1,12.3,15.9,107.7]],
            closed_visual_solid_parts=[leaf['destination']],body_profile='human_silhouette',raised_door=True,clear_wall_facade=True)
    write(ROOT/'art/architecture/laundry_v2/manifest.json',dict(schema=2,version='laundry-v2',assets=architecture))
    records.append(dict(key='north_door',path=path,sha256=sha(ROOT/path),source=str(GENERATED/source)))
    write(DOC/'production-assets.json',dict(mode='built-in imagegen',assets=records,definition_ids=[a['id'] for a in props+architecture]))

def prepare():
    path=ROOT/'data/rooms/r04.json'; raw=path.read_bytes();room=json.loads(raw);before=deepcopy(room)
    assert next(v['rect'] for v in room['visibility_rooms'] if v['id']=='laundry')==[900,3420,900,480]
    assert room.get('laundry_redesign_version',0)==0, 'Already applied; edit latest map explicitly instead of replaying.'
    fixtures={v['id']:v for v in room['fixtures']}
    gates={v['id']:v for v in room['access_doors']}
    assert gates['cafeteria-rear']['rect']==[1300,3400,180,20]
    assert fixtures['campus-laundry-south']['rect']==[1120,3900,180,20]
    changed=[]
    def move(identifier,rect,asset=None,**extra):
        f=fixtures[identifier];f['rect']=rect
        if asset:f['asset_id']=asset
        f.update(extra);changed.append(identifier)
    for i in range(4):move(f'laundry-washer-{i}',[1170+i*88,3455,80,66],'laundry_washer_v2')
    move('laundry-cleaning-rack',[915,3440,60,150],loot_location='洗衣房',loot_name='窄布草用品架')
    move('laundry-clean-linen-shelf',[1580,3440,190,44],loot_location='洗衣房',loot_name='净衣补给架')
    move('laundry-wash-basin',[1600,3560,150,63])
    move('laundry-dirty-sorting',[1020,3580,210,75],'laundry_dirty_station_v2',loot_location='洗衣房',loot_name='脏衣分拣组合')
    move('laundry-folding-table',[1170,3670,285,65],'laundry_folding_table_v2',loot_location='洗衣房',loot_name='金属布草叠衣台')
    move('laundry-cart',[1480,3700,65,45.8823529411765],loot_location='洗衣房',loot_name='净衣帆布车')
    # The existing double leaf swings past the short right-hand facade.
    # Place the readable plaque on the unobstructed left facade instead.
    move('laundry-sign',[1340,3902,95,1])
    move('laundry-supply-pipe',[1170,3384,344,1],'laundry_supply_pipe_v2')
    move('campus-laundry-south',[1520,3900,180,20])
    move('cafeteria-rear-visual45',[1000,3400,120,20],'doorway_laundry_north_closed_v2',
         closed_asset='doorway_laundry_north_closed_v2',open_asset='doorway_laundry_north_open_v2',render_size=[140,120])
    for identifier,asset,rect in [('laundry-wall-vent','laundry_vent_v2',[1530,3360,65,1]),
                                  ('laundry-work-lamp','laundry_wall_lamp_v2',[1650,3360,44,1])]:
        room['fixtures'].append(dict(id=identifier,asset_id=asset,rect=rect,blocks_movement=False,blocks_sight=False,
                                     draw_depth=3516,laundry_generated=True))
        changed.append(identifier)
    gates['cafeteria-rear'].update(rect=[1000,3400,120,20],evacuation=[1060,3260],
                                  asset_id='doorway_laundry_north_closed_v2',name='洗衣房北侧时段门')
    selected=[]
    for s in room['architecture']['wall_surfaces']:
        x,y,w,h=room['walls'][int(s['wall_index'])]
        if 920<=x<1780 and y in [3300,3800]: selected.append(int(s['wall_index']))
    # Remove only these two interior facade rows; remap untouched indices.
    kept=[];remap={}
    for i,wall in enumerate(room['walls']):
        if i not in selected:remap[i]=len(kept);kept.append(wall)
    surfaces=[]
    for s in room['architecture']['wall_surfaces']:
        if int(s['wall_index']) not in selected:
            s['wall_index']=remap[int(s['wall_index'])];surfaces.append(s)
    room['walls']=kept;room['architecture']['wall_surfaces']=surfaces
    def segment(x,y,w,lintel=False):
        identifier=f'laundry_lintel_{w}' if lintel else 'laundry_wall_h_short' if w==20 else f'laundry_wall_h_{int(((x-900+20)%320)/20):02d}'
        index=len(room['walls']);room['walls'].append([x,y,w,20 if lintel else 120])
        surfaces.append(dict(wall_index=index,height=20,grid_tile_asset=identifier,
                             collision_parts=[] if lintel else [[0,100,w,20]],laundry_redesign=True))
    for y,gap in [(3300,[1000,1120]),(3800,[1520,1700])]:
        cursor=920
        while cursor<1780:
            if cursor==gap[0]:
                remain=gap[1]-cursor
                while remain:
                    size=min(80,remain);segment(cursor,y,size,True);cursor+=size;remain-=size
            else:
                limit=gap[0] if cursor<gap[0] else 1780
                size=min(40,limit-cursor);segment(cursor,y,size);cursor+=size
    # North gap 120 needs a 40-unit lintel, sourced from the existing 80.
    arch_path=ROOT/'art/architecture/laundry_v2/manifest.json';arch=read(arch_path)
    a=deepcopy(next(v for v in read(ROOT/'art/architecture/laundry_v1/manifest.json')['assets'] if v['id']=='laundry_lintel_80'))
    a.update(id='laundry_lintel_40',name='洗衣房门上收口 · 40',world_size=[40,20],render_size=[40,20])
    a['assembly_patches'][0]['source'][2]/=2;a['assembly_patches'][0]['destination'][2]=40
    a['grid_tile']['columns']=2;arch['assets'].append(a);write(arch_path,arch)
    for d in room['ground_details']:
        if d.get('rect')==[1074,3540,142,20]:d['rect']=[1240,3550,150,20]
        elif d.get('rect')==[1595,3642,142,20]:d['rect']=[1600,3640,130,20]
    # A continuous paved link across the grass without disturbing the
    # cafeteria's existing connection, whose door and paving remain owned there.
    room['floor_regions'].extend([
        dict(id='laundry-north-approach',asset_id='common_floor_v46',rect=[980,3180,160,220],tile_size=[320,320]),
        dict(id='laundry-north-link',asset_id='common_floor_v46',rect=[980,3020,640,160],tile_size=[320,320])])
    room['concept_plan']['laundry_revision']=dict(reference='docs/art/laundry-redesign-v01/concept-final.png',
        room_rect=[900,3420,900,480],north_gap=[1000,1120],north_foot_y=3400,south_gap=[1520,1700],south_foot_y=3900,
        west_passage=[880,3620,20,140],east_passage=[1800,3700,20,140])
    room['laundry_redesign_version']=1
    write(DOC/'last-input-map.json',before);write(DOC/'candidate-map.json',room)
    write(DOC/'map-registration.json',dict(input_sha256=hashlib.sha256(raw).hexdigest(),changed_fixture_ids=changed,
        selected_walls=selected,index_remap=remap,north_gate_id='cafeteria-rear',new_floor_ids=['laundry-north-approach','laundry-north-link']))
    print('Prepared guarded laundry candidate; original map unchanged.')

def apply():
    path=ROOT/'data/rooms/r04.json';record=read(DOC/'map-registration.json')
    assert sha(path)==record['input_sha256'],'Map changed since preparation; rebase on latest instead of overwriting.'
    candidate=(DOC/'candidate-map.json').read_bytes()
    # Keep both snapshots independent of any existing user .bak file.
    shutil.copyfile(path,DOC/'map-before-save.json')
    path.write_bytes(candidate)
    shutil.copyfile(path,DOC/'last-output-map.json')
    record['output_sha256']=sha(path);write(DOC/'map-registration.json',record)
    print('Applied laundry candidate to r04; guarded input/output snapshots saved.')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('op',choices=['prepare','apply']);args=p.parse_args()
    if args.op=='prepare':definitions();prepare()
    else:apply()
