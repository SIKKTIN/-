"""Restore only R04's loading yard; keep latest authoring edits and container IDs."""
from copy import deepcopy
from pathlib import Path
import argparse, hashlib, json, shutil, os, tempfile
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs/art/loading-yard-v02'
SHADER='res://art/architecture/v25/safe_edges_v25.gdshader'
def read(p):return json.loads(p.read_bytes())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):
    p.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.NamedTemporaryFile(mode='w',encoding='utf-8',dir=p.parent,prefix=p.name+'.',suffix='.tmp',delete=False) as out:
        out.write(json.dumps(v,ensure_ascii=False,indent='\t')+'\n');temp=Path(out.name)
    os.replace(temp,p)

def definitions():
    assets=[];floors=[];records=[]
    for item in read(DOC/'generated-assets.json')['assets']:
        p=ROOT/item['path'];p.parent.mkdir(parents=True,exist_ok=True)
        if not p.exists() or sha(p)!=sha(Path(item['source'])):shutil.copyfile(item['source'],p)
        key=item['key']
        with Image.open(p) as im:
            size=list(im.size)
            if key=='floor':region=[0,0,*size]
            else:
                assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
                bounds=im.getchannel('A').point(lambda v:255 if v>=180 else 0).getbbox()
                assert bounds
                x,y,r,b=bounds;x=max(0,x-3);y=max(0,y-3);r=min(im.width,r+3);b=min(im.height,b+3)
                region=[x,y,r-x,b-y]
        a=dict(id='loading_'+key+'_v1',name='装卸场 · '+item['name'],texture='res://'+item['path'],texture_size=size,region=region,
               source_kind='built-in-imagegen-original-png',sha256=sha(p),runtime_size_limit=item['limit'])
        if key=='floor':
            floors.append(a)
        else:
            w,h=region[2:];width=item['width'];scale=width/w;visible=h*scale
            attachment=key.endswith('sign');ground=1 if attachment else min(item['ground'],visible-2)
            a.update(ground_rect=[0,h+(12/scale if attachment else -ground/scale),w,ground/scale],
                footprint_world_size=[width,ground],world_size=[width,visible],render_size=[width,visible],
                elevation_world=visible+12 if attachment else visible-ground,
                render_mode='wall_attachment' if attachment else 'projected_prop',blocking=not attachment,interactive=False,
                shadow_baked=False,proportion_locked=True,alpha_core_shader=SHADER,
                editor_subcategory='attachments' if attachment else 'furnishings')
            assets.append(a)
        records.append(dict(key=key,path=item['path'],sha256=sha(p),region=region))
    old={a['id']:a for m in ['art/props/warehouse_v1/manifest.json','art/props/factory_v44/manifest.json','art/props/duty_room_v1/manifest.json','art/architecture/v37/manifest.json']for a in read(ROOT/m)['assets']}
    for source,key,name,width,ground,attachment in [
        ('warehouse_packages_v1','sacks','袋装物资',90,70,False),
        ('warehouse_drums_v1','drums','旧油桶',80,50,False),
        ('warehouse_jack_v1','jack','手动托盘车',65,139,False),
        ('duty_clock_v1','clock','门岗时钟',40,1,True)]:
        a=deepcopy(old[source]);w,h=a['region'][2:];scale=width/w;visible=h*scale
        a.update(id='loading_'+key+'_v1',name='装卸场 · '+name,world_size=[width,visible],render_size=[width,visible],
            ground_rect=[0,h+(12/scale if attachment else -ground/scale),w,ground/scale],footprint_world_size=[width,ground],
            elevation_world=visible+12 if attachment else max(0,visible-ground),render_mode='wall_attachment' if attachment else 'projected_prop',
            blocking=not attachment,proportion_locked=True,runtime_size_limit=256 if attachment else 512,reused_from=source,
            editor_subcategory='attachments' if attachment else 'furnishings')
        a.pop('editor_icon',None);assets.append(a)
    # Reuse the existing ironwork, but render the whole closed/open gate at its
    # physical facade rather than the old shallow generic doorway strip.
    for state in ['open','closed']:
        a=deepcopy(old['prison_gate_'+state+'_v37'])
        a.update(id='doorway_loading_'+state+'_v1',name='装卸场 · 铁栅门'+('开启' if state=='open' else '关闭'),
            runtime_size_limit=512,editor_subcategory='doors',proportion_locked=True,reused_from='prison_gate_'+state+'_v37',
            door_presentation=dict(raised_door=True,clear_wall_facade=True,body_depth_limited=True,
                door_art_size=[200,120],door_art='doorway_loading_open_v1',door_art_closed='doorway_loading_closed_v1'))
        a.pop('editor_icon',None);assets.append(a)
    write(ROOT/'art/props/loading_yard_v1/manifest.json',dict(schema=2,version='loading-yard-v1',assets=assets))
    write(ROOT/'art/environment/loading_yard_v1/manifest.json',dict(schema=2,version='loading-yard-v1',assets=floors))
    write(DOC/'asset-registration.json',dict(mode='built-in imagegen',assets=records,definition_ids=[a['id']for a in assets],
        floors=[a['id']for a in floors],reused=[dict(id=a['id'],source=a['reused_from'],texture=a['texture'])for a in assets if a.get('reused_from')]))
    return {a['id']:a for a in assets}

def restore(assets):
    path=ROOT/'data/rooms/r04.json';before=path.read_bytes();digest=sha(path);d=json.loads(before);original=deepcopy(d)
    assert next(z for z in d['zones']if z['id']=='loading')['rect']==[5140,220,640,3420], 'Loading yard changed: recalibrate.'
    selected=[f for f in d['fixtures']if f['id'].startswith('cargo-pallet-') and f['rect'][0]>5120
        or f['id'].startswith('detail44-yard-') or f['id']in ['loading-truck','loading-booth','detail44-wall-lamp-4','detail44-extinguisher-3']]
    old={f['id']:f for f in selected};ids=list(old)
    d['fixtures']=[f for f in d['fixtures']if f['id']not in ids and not f.get('loading_generated')]
    def place(identifier,key,x,y,loot=None,depth=None,width=None):
        a=assets['loading_'+key+'_v1'];f=deepcopy(old.get(identifier,{}))
        f.update(id=identifier,asset_id=a['id'],rect=[x,y,*a['footprint_world_size']],blocks_movement=a['blocking'],blocks_sight=False,loading_generated=True)
        if width is not None:
            scale=width/f['rect'][2];f['rect'][2:]=[width,f['rect'][3]*scale]
        if loot and not f.get('loot_profile'):f.update(loot_profile=loot,loot_location='装卸场',loot_name=a['name'].split(' · ')[-1])
        if f.get('loot_profile'):f['loot_location']='装卸场'
        if depth is not None:f['draw_depth']=depth
        d['fixtures'].append(f);return f
    place('loading-truck','truck',5570,1100)
    place('loading-booth','booth',5300,220)
    # Preserve every old container ID while arranging compact cargo groups.
    positions=[
        ('cargo-pallet-2','crates',5160,840,95),('detail44-yard-crates-0','crates_low',5230,930,110),
        ('detail44-yard-crates-1','crates',5260,840,95),('detail44-yard-crates-2','sacks',5160,1005,90),
        ('cargo-pallet-4','crates',5160,1890,95),('detail44-yard-crates-6','crates_low',5210,1985,130),
        ('detail44-yard-crates-7','crates',5260,1890,95),('detail44-yard-crates-8','sacks',5160,2085,90),
        ('detail44-yard-crates-9','crates',5160,3110,115),
        ('cargo-pallet-3','crates_low',5600,2650,95),('detail44-yard-crates-3','crates',5700,2650,80),
        ('detail44-yard-crates-4','crates_low',5630,2730,130),('detail44-yard-crates-5','sacks',5685,2820,90),
        ('cargo-pallet-5','crates',5600,2810,80)]
    for identifier,key,x,y,width in positions:place(identifier,key,x,y,'warehouse',width=width)
    for identifier,x,y in [('detail44-yard-drums-0',5260,2085),('detail44-yard-drums-1',5630,2920),('detail44-yard-drums-2',5285,3110)]:place(identifier,'drums',x,y)
    place('detail44-yard-jack','jack',5295,1715)
    for identifier,x,y in [('loading-empty-pallets-0',5180,1700),('loading-empty-pallets-1',5190,3260),('loading-empty-pallets-2',5650,2460)]:place(identifier,'pallets',x,y)
    for identifier,x,y in [('detail44-yard-dispatch',5170,2310),('detail44-yard-spares-shelf',5170,2400),('detail44-yard-scrap',5685,3030),
                           ('detail44-yard-papers-tools',5200,2300),('detail44-wall-lamp-4',5144,2390),('detail44-extinguisher-3',5145,2960)]:
        f=deepcopy(old[identifier]);f['rect'][:2]=[x,y];f.update(loading_generated=True)
        if 'draw_depth'in f:f['draw_depth']=y+70 if identifier=='detail44-yard-papers-tools' else y+20
        d['fixtures'].append(f)
    place('loading-logistics-sign','logistics_sign',5500,124,None,225)
    place('loading-yard-sign','yard_sign',5143,2270,None,2285)
    place('loading-clock','clock',5720,233,None,240)
    for identifier,x,y in [('loading-bollard-north-left',5475,240),('loading-bollard-north-right',5705,240),
                           ('loading-bollard-service-left',5270,3675),('loading-bollard-service-right',5490,3675),
                           ('loading-bollard-rear-left',5525,4215),('loading-bollard-rear-right',5770,4215)]:place(identifier,'bollard',x,y)
    gates={'loading-exit':[5500,100,200,120],'service-barrier':[5300,3560,180,120],'rear-exit':[5560,4100,200,120]}
    for gate in d['access_doors']:
        if gate['id']not in gates:continue
        gate.update(asset_id='doorway_loading_closed_v1',rotation_door_visual_rect=gates[gate['id']],
                    door_art_size=gates[gate['id']][2:],label_offset=[-90,86])
    gatefixtures=[]
    for f in d['fixtures']:
        if f.get('access_id')not in gates:continue
        f.update(asset_id='doorway_loading_closed_v1',closed_asset='doorway_loading_closed_v1',open_asset='doorway_loading_open_v1',
                 render_size=gates[f['access_id']][2:],rotation_door_visual_rect=gates[f['access_id']])
        gatefixtures.append(f['id'])
    changed_floors=[]
    for f in d['floor_regions']:
        if f['id']in ['loading-yard','logistics-outlet','service-outlet']:
            f.update(asset_id='loading_floor_v1',manifest='res://art/environment/loading_yard_v1/manifest.json',tile_size=[320,320],tile_origin=[5120,200])
            changed_floors.append(f['id'])
    for z in d['zones']:
        if z['id']=='loading':z['hide_label']=True
    # Existing patrol used to cross the old central truck. Keep it in the clear
    # working aisle without changing guard count, schedules or game rules.
    for g in d.get('gate_guards',[]):
        if g['id']=='loading-watch':g['patrol']=[[5440,510],[5440,1220],[5440,2210],[5440,3360]]
    removed=[];kept=[]
    for index,v in enumerate(d.get('ground_details',[])):
        p=v.get('position',v.get('from',v.get('rect',[-1,-1])))
        if v.get('loading_generated') or 5140<=p[0]<5800 and 200<=p[1]<3560:removed.append(index)
        else:kept.append(v)
    d['ground_details']=kept
    def mark(kind,**values):d['ground_details'].append(dict(kind=kind,color='#baa052',opacity=.65,loading_generated=True,**values))
    mark('dash',**{'from':[5440,470],'to':[5440,3440]},width=5,segment=46,gap=44)
    def box(x,y,w,h):
        for a,b in [([x,y],[x+w,y]),([x+w,y],[x+w,y+h]),([x+w,y+h],[x,y+h]),([x,y+h],[x,y])]:mark('line',**{'from':a,'to':b},width=4)
    box(5545,1040,225,680)
    for x,y,w,h in [(5155,795,210,320),(5155,1845,210,360),(5590,2600,195,520),(5155,3065,215,310)]:box(x,y,w,h)
    for rect in [[5160,1580,22,120],[5545,1700,225,20],[5160,2630,120,20],[5760,3060,20,150]]:mark('hatch',rect=rect)
    mark('drain',rect=[5764,3390,20,78])
    d['loading_restoration_version']=1
    # Guard against concurrent editor saves; always start with newest disk map.
    assert sha(path)==digest,'Saved map changed; rerun against latest state.'
    if not(DOC/'initial-input-map.json').exists():(DOC/'initial-input-map.json').write_bytes(before)
    (DOC/'last-input-map.json').write_bytes(before)
    oldcontainers={f['id']:f['loot_profile']for f in selected if f.get('loot_profile')}
    newcontainers={f['id']:f.get('loot_profile')for f in d['fixtures']}
    assert all(newcontainers.get(k)==v for k,v in oldcontainers.items())
    assert d['walls']==original['walls'] and d['architecture']==original['architecture'] and d['visibility_rooms']==original['visibility_rooms']
    write(path,d);(DOC/'last-output-map.json').write_bytes(path.read_bytes())
    write(DOC/'map-registration.json',dict(input_sha256=digest,output_sha256=sha(path),fixture_ids=ids,gate_fixture_ids=gatefixtures,
        gate_ids=list(gates),floor_ids=changed_floors,removed_ground_details=removed,containers=oldcontainers))
    print('Loading yard restored: grouped cargo, east parked truck, north booth, closed-state gate art, clear center aisle.')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--definitions-only',action='store_true');args=p.parse_args()
    assets=definitions()
    if not args.definitions_only:restore(assets)

