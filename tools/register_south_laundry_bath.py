"""Rebase the approved north-entry layout on the latest saved R04.

Original PNGs remain unchanged. Atomic writes and a SHA guard protect saves.
"""
from copy import deepcopy
from pathlib import Path
import hashlib, json, os, shutil, tempfile
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / 'docs/art/south-laundry-bath-v01'
MANIFEST = 'art/props/south_laundry_bath_v1/manifest.json'
GENERATED = Path('C:/Users/gst20/.codex/generated_images/01a12de1-9940-7ee0-a361-bbf0f88d4681')
SHADER = 'res://art/architecture/v25/safe_edges_v25.gdshader'

def read(p): return json.loads(p.read_bytes())
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p, data):
    p.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=p.name+'.', suffix='.tmp', dir=p.parent)
    try:
        with os.fdopen(fd,'w',encoding='utf-8') as f:
            f.write(json.dumps(data,ensure_ascii=False,indent='\t')+'\n')
        os.replace(tmp,p)
    finally:
        if os.path.exists(tmp): os.unlink(tmp)

def definitions():
    defs = {}
    for p in ['art/props/laundry_v1/manifest.json','art/props/laundry_v2/manifest.json',
              'art/architecture/laundry_v1/manifest.json','art/architecture/bath_v1/manifest.json',
              'art/props/campus_v47/manifest.json']:
        defs.update({a['id']:a for a in read(ROOT/p)['assets']})
    assets=[]; records=[]
    for key, filename, width, depth in [
        ('east_basin','exec-4b9f1954-451c-45c8-a611-8126f984c917.png',66,250),
        ('privacy_screen','exec-b63cb331-4027-48ef-a3c5-9e473e3f5ed9.png',140,18),
        ('dirty_carts','exec-f67e525f-b029-4d80-a2e7-367ecda9c4e7.png',260,116)]:
        dst=ROOT/f'art/props/south_laundry_bath_v1/{key}.png'
        dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(GENERATED/filename,dst)
        assert sha(dst)==sha(GENERATED/filename)
        im=Image.open(dst); assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0 and im.getchannel('A').getextrema()[1]>=250
        x,y,r,b=im.getchannel('A').point(lambda a:255 if a>=180 else 0).getbbox()
        region=[max(0,x-2),max(0,y-2),min(im.width,r+2)-max(0,x-2),min(im.height,b+2)-max(0,y-2)]
        w,h=region[2:];scale=width/w;assert depth<h*scale
        name={'east_basin':'洗衣房 · 东墙三位水槽','privacy_screen':'浴室 · 靠墙直线矮隔屏','dirty_carts':'洗衣房 · 三辆脏布草车'}[key]
        a=dict(id='south_'+key+'_v1',name=name,texture='res://'+dst.relative_to(ROOT).as_posix(),texture_size=list(im.size),region=region,
               runtime_size_limit=512,sha256=sha(dst),source_kind='built-in-imagegen-original-png',alpha_core_shader=SHADER,
               render_mode='projected_prop',world_size=[width,h*scale],render_size=[width,h*scale],
               footprint_world_size=[width,depth],ground_rect=[0,h-depth/scale,w,depth/scale],
               elevation_world=h*scale-depth,blocking=True,interactive=False,shadow_baked=False,proportion_locked=True,editor_subcategory='furnishings')
        assets.append(a);records.append(dict(id=a['id'],path=str(dst),source=str(GENERATED/filename),sha256=a['sha256']))
    # Furniture variants retain the source perspective and upper-left light.
    for old,new,width,depth,name in [
        ('laundry_washer_v2','south_washer_v1',108,88,'洗衣房 · 双列工业滚筒机'),
        ('laundry_supply_pipe_v2','south_washer_pipe_v1',232,1,'洗衣房 · 双位供水管'),
        ('laundry_folding_table_v2','south_folding_table_v1',300,68,'洗衣房 · 中央布草叠衣台'),
        ('laundry_shelf_vertical_v1','south_linen_rack_v1',62,150,'洗衣房 · 东北布草用品架'),
        ('laundry_shelf_horizontal_v1','south_pickup_counter_v1',160,44,'洗衣房 · 北入口布草领取台'),
        ('bath_changing_lockers','south_bath_lockers_v1',160,46,'浴室 · 北侧更衣柜')]:
        a=deepcopy(defs[old]);w,h=a['region'][2:];s=width/w
        a.update(id=new,name=name,world_size=[width,h*s],render_size=[width,h*s],ground_rect=[0,h-depth/s,w,depth/s],
                 footprint_world_size=[width,depth],elevation_world=h*s-depth,proportion_locked=True,runtime_size_limit=512,reused_from=old)
        assets.append(a)
    # Open/closed northern doors use the established double-leaf originals.
    # Scale all visual-body patches together; do not rotate the painted camera.
    for room,scale in [('laundry',1.0),('bath',2/3)]:
        for state in ['open','closed']:
            old=f'doorway_laundry_{state}_v1';a=deepcopy(defs[old])
            a.update(id=f'doorway_south_{room}_north_{state}_v1',name=('洗衣房' if room=='laundry' else '浴室')+'北侧双扇钢门 · '+state,
                     world_size=[308*scale,150*scale],render_size=[308*scale,150*scale],footprint_world_size=[180*scale,20],reused_from=old)
            p=a['door_presentation'];p.update(door_art=f'doorway_south_{room}_north_open_v1',door_art_closed=f'doorway_south_{room}_north_closed_v1',
                                             door_art_size=[308*scale,150*scale],clear_wall_facade=True)
            for patch in p['door_closed_patches']:patch['destination']=[v*scale for v in patch['destination']]
            for k in ['visual_solid_parts','closed_visual_solid_parts']:p[k]=[[v*scale for v in r] for r in p[k]]
            assets.append(a)
    write(ROOT/MANIFEST,dict(schema=2,version='south-laundry-bath-v1',assets=assets))
    write(DOC/'implementation-assets.json',dict(mode='built-in imagegen',assets=records,definition_ids=[a['id'] for a in assets]))

def prepare():
    path=ROOT/'data/rooms/r04.json';before=read(path);data=deepcopy(before);initial=sha(path)
    assert not data.get('south_laundry_bath_version'), 'Already applied; rebase instead of replaying.'
    areas={v['id']:v['rect'] for v in data['visibility_rooms']}
    assert areas['laundry']==[900,3420,900,480] and areas['bath']==[1840,3420,440,540], 'Latest room geometry changed.'
    fixtures={f['id']:f for f in data['fixtures']};changed=[]
    def move(id,rect,asset=None,**extra):
        f=fixtures[id];f['rect']=rect
        if asset:f['asset_id']=asset
        f.update(extra);changed.append(id)
        return f
    def add(id,asset,rect,**extra):
        f=dict(id=id,asset_id=asset,rect=rect,blocks_movement=True,blocks_sight=False,south_life_generated=True);f.update(extra)
        data['fixtures'].append(f);changed.append(id);return f
    for i in range(4):move(f'laundry-washer-{i}',[940+118*(i%2),3490+120*(i//2),108,88],'south_washer_v1')
    move('laundry-supply-pipe',[940,3440,232,1],'south_washer_pipe_v1',draw_depth=3580)
    move('laundry-cleaning-rack',[1710,3450,62,150],'south_linen_rack_v1')
    move('laundry-clean-linen-shelf',[1490,3480,160,44],'south_pickup_counter_v1',loot_name='北入口布草领取台')
    move('laundry-dirty-sorting',[940,3780,260,116],'south_dirty_carts_v1',loot_name='脏布草分拣车')
    move('laundry-folding-table',[1300,3720,300,68],'south_folding_table_v1')
    move('laundry-wash-basin',[1710,3650,66,250],'south_east_basin_v1')
    move('laundry-cart',[1585,3840,65,45.8823529411765])
    move('laundry-sign',[1335,3350,95,1],draw_depth=3430)
    move('laundry-downpipe',[1740,4080,20,1],draw_depth=4130)
    move('laundry-wall-vent',[1190,3455,65,1],draw_depth=3590)
    move('laundry-work-lamp',[1660,3340,44,1],draw_depth=3440)
    north=move('cafeteria-rear-visual45',[1300,3400,180,20],'doorway_south_laundry_north_closed_v1',
               open_asset='doorway_south_laundry_north_open_v1',closed_asset='doorway_south_laundry_north_closed_v1',render_size=[308,150])
    north.pop('rotation_door_visual_rect',None)
    # The old equipment shortcut faced a solid bath wall after the user moved
    # the rooms. Keep its identity/lock linkage on the west service aperture.
    move('laundry-equipment-visual45',[880,3620,20,140])
    gates={g['id']:g for g in data['access_doors']}
    gates['cafeteria-rear'].update(rect=[1300,3400,180,20],evacuation=[1390,3230],room_rect=[900,3420,900,660],asset_id=north['asset_id'])
    gates['laundry-equipment'].update(rect=[880,3620,20,140],interaction_point=[940,3690],name='洗衣房西侧检修门')
    removed=['campus-laundry-west','campus-laundry-south']
    data['fixtures']=[f for f in data['fixtures'] if f['id'] not in removed]
    move('campus-bath',[1980,3400,120,20],'doorway_south_bath_north_open_v1',
         open_asset='doorway_south_bath_north_open_v1',closed_asset='doorway_south_bath_north_closed_v1',render_size=[308*2/3,100],frame_only=False)
    fixtures['campus-bath'].pop('rotation_door_visual_rect',None)
    move('campus-bath-locker-0',[2100,3480,160,46],'south_bath_lockers_v1')
    add('campus-bath-locker-1','changing_bench_v47',[2110,3580,130,47.8947625])
    move('campus-bath-basket',[2242,3588,30,23.3333125])
    move('campus-bath-recharge-counter',[1860,3500,116,36],recharge_offset=[140,18])
    add('campus-bath-privacy-screen','south_privacy_screen_v1',[1840,3630,140,18])
    for col,x in enumerate([1850,2138]):
        for row in range(3):
            id=f'campus-bath-shower-{col}-{row}';y=3720+90*row
            move(id,[x,y,132,8]);move(id+'-drain',[x+(100 if col==0 else 15),y+30,17,16.2654320987654],draw_depth=3419)
    move('campus-bath-window',[1860,3335,100,34.7277],draw_depth=3445)
    move('campus-bath-light',[1910,3370,34,5.96746575342466],draw_depth=3445)
    move('campus-bath-sign',[1988,3288,104,26.2408719346049],draw_depth=3445)
    for f in data['resident_staff']:
        if f['id']=='bath-cashier':f.update(position=[1918,3470],patrol=[])
    # Only replace wall rows owned by these rooms. Preserve the north-west
    # and north shared junctions, and remap all unrelated wall surfaces.
    selected=set()
    for s in data['architecture']['wall_surfaces']:
        i=int(s['wall_index']);x,y,w,h=data['walls'][i];id=s.get('grid_tile_asset','')
        if id.startswith('bath_') and 1820<=x<=2280 and 3300<=y<=3880:selected.add(i)
        if id.startswith('laundry_') and 880<=x<=1800 and 3300<=y<=3800:selected.add(i)
        if x==1780 and y==3800 and id=='prison_t_n':selected.add(i)
    remap={};walls=[];surfaces=[]
    for i,w in enumerate(data['walls']):
        if i not in selected:remap[i]=len(walls);walls.append(w)
    for s in data['architecture']['wall_surfaces']:
        if int(s['wall_index']) not in selected:
            s['wall_index']=remap[int(s['wall_index'])];surfaces.append(s)
    def tile(id,x,y,w,h,parts):
        surfaces.append(dict(wall_index=len(walls),height=20,grid_tile_asset=id,collision_parts=parts,south_life_generated=True));walls.append([x,y,w,h])
    def row(prefix,start,end,y,gap=None):
        x=start
        while x<end:
            lintel=gap and gap[0]<=x<gap[1];stop=(gap[1] if lintel else gap[0] if gap and x<gap[0] else end)
            w=min(80 if lintel else 40,stop-x)
            if lintel and w==40:w=20 # use existing calibrated 20/80 lintels
            id=prefix+'_lintel_'+str(w) if lintel else prefix+'_wall_h_short' if w==20 else prefix+f'_wall_h_{int((x-start)%320/20):02d}'
            tile(id,x,y,w,20 if lintel else 120,[] if lintel else [[0,100,w,20]]);x+=w
    # Existing shared north laundry junctions stay intact at x880 and x1780.
    row('laundry',920,1780,3300,[1300,1480])
    for prefix,x,right in [('laundry',900,1800),('bath',1840,2280)]:
        if prefix=='bath':
            tile('bath_corner_nw',x-20,3300,40,120,[[0,100,40,20]])
            tile('bath_corner_ne',right-20,3300,40,120,[[0,100,40,20]])
            row(prefix,x+20,right-20,3300,[1980,2100])
        tile(prefix+'_corner_sw',x-20,3960,40,140,[[0,120,40,20],[0,0,20,140]])
        tile(prefix+'_corner_se',right-20,3960,40,140,[[0,120,40,20],[20,0,20,140]])
        row(prefix,x+20,right-20,3980)
        for sx in [x-20,right]:
            cursor=3420
            while cursor<3960:
                if prefix=='laundry' and sx==880 and 3620<=cursor<3760:cursor=3760;continue
                end=3620 if prefix=='laundry' and sx==880 and cursor<3620 else 3960
                h=min(120,end-cursor)
                tile(prefix+('_wall_v_long' if h==120 else '_wall_v_short'),sx,cursor,20,h,[[0,0,20,h]]);cursor+=h
    data['walls']=walls;data['architecture']['wall_surfaces']=surfaces
    for k in ['visibility_rooms','zones']:
        for r in data[k]:
            if r['id'] in ['laundry','bath']:
                r['rect']=[900,3420,900,660] if r['id']=='laundry' else [1840,3420,440,660]
    for r in data['floor_regions']:
        if r['id']=='laundry':r['rect']=[880,3400,940,700]
        if r['id']=='campus-bath':r['rect']=[1820,3400,480,700]
        if r['id'].startswith('bath-wet-'):
            col,rownum=map(int,r['id'].split('-')[-2:]);r['rect']=[1850 if col==0 else 2138,3728+90*rownum,132,82]
        if r['id']=='laundry-north-link':r['rect']=[980,3180,1320,200]
        if r['id']=='laundry-north-approach':r['rect']=[1280,3380,220,40]
    data['floor_regions'].append(dict(id='bath-north-approach',asset_id='common_floor_v46',rect=[1960,3380,160,40],tile_size=[320,320]))
    for d in data['ground_details']:
        x,y,w,h=d.get('rect',[0,0,0,0])
        if 880<=x<=1800 and 3300<=y<3990:
            if x==1240:d['rect']=[965,3725,180,20]
            elif x==1600:d['rect']=[1665,3660,18,140]
    cp=data['concept_plan'];cp['south_laundry_bath_revision']=dict(reference='docs/art/south-laundry-bath-v01/concept-final-v02.png',
        north_foot_y=3400,south_foot_y=4080,laundry=[900,3420,900,660],bath=[1840,3420,440,660],privacy_screen='campus-bath-privacy-screen')
    cp['laundry_revision'].update(room_rect=[900,3420,900,660],north_gap=[1300,1480],south_gap=[],south_foot_y=4080,west_passage=[880,3620,20,140],east_passage=[])
    for s in cp['horizontal']:
        if s['id']=='bath-north':s.update(x0=1820,x1=2300,y=3400,gaps=[[1980,2100]])
        if s['id']=='bath-south':s.update(x0=1820,x1=2300,y=4080,gaps=[])
    for s in cp['vertical']:
        if s['id'] in ['bath-west','bath-east']:s.update(x=1820 if s['id']=='bath-west' else 2280,y0=3400,y1=4080,gaps=[])
        if s['id']=='laundry-equipment-divider':s.update(x=1800,y0=3400,y1=4080,gaps=[])
    data['south_laundry_bath_version']=1
    write(DOC/'implementation-input-map.json',before);write(DOC/'implementation-candidate-map.json',data)
    write(DOC/'implementation-registration.json',dict(input_sha256=initial,changed_fixture_ids=changed,removed_fixture_ids=removed,
          removed_wall_indices=sorted(selected),wall_index_remap=remap,changed_gate_ids=['cafeteria-rear','laundry-equipment']))
    return data,initial

def main():
    definitions();data,initial=prepare();path=ROOT/'data/rooms/r04.json'
    assert sha(path)==initial,'R04 changed during preparation; rebase on the saved version.'
    write(path,data);write(DOC/'implementation-output-map.json',data)
    record=read(DOC/'implementation-registration.json');record['output_sha256']=sha(path);write(DOC/'implementation-registration.json',record)
    print('Applied south laundry/bath on latest saved R04 with guarded snapshots.')

if __name__=='__main__':main()
