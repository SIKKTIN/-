"""Register original art and restore the approved compact recreation room."""
from pathlib import Path
from copy import deepcopy
import json, hashlib, shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT/'docs/art/chess-activity-room-v1'
ART = ROOT/'art/props/chess_room_v1'
MANIFEST = 'res://art/props/chess_room_v1/manifest.json'
SHADER = 'res://art/architecture/v25/safe_edges_v25.gdshader'
AREA = [900,220,560,580]

def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,v):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(v,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def register():
    sources={}; records=[]
    for a in read(DOC/'production-assets.json')['assets']:
        path=ROOT/a['path']; path.parent.mkdir(parents=True,exist_ok=True)
        if not path.exists():shutil.copyfile(a['source'],path)
        assert sha(path)==sha(Path(a['source'])),a['key']
        im=Image.open(path)
        assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
        assert im.getchannel('A').getextrema()[1]>=250
        x,y,r,b=im.getchannel('A').point(lambda v:255 if v>=180 else 0).getbbox()
        sources[a['key']]=dict(texture='res://'+a['path'],texture_size=list(im.size),region=[x,y,r-x,b-y],
            sha256=sha(path),source_kind='built-in-imagegen-original-png',alpha_core_shader=SHADER)
        records.append(dict(key=a['key'],path=a['path'],sha256=sha(path),size=list(im.size)))
    assets=[]
    def prop(key,width,depth):
        a=deepcopy(sources[key]);w,h=a['region'][2:];scale=width/w
        assert h*scale>=depth,(key,h*scale,depth)
        a.update(id='chess_'+key+'_v1',name='棋牌室 · '+next(r['name'] for r in read(DOC/'production-assets.json')['assets'] if r['key']==key),
            world_size=[width,h*scale],render_size=[width,h*scale],footprint_world_size=[width,depth],
            ground_rect=[0,h-depth/scale,w,depth/scale],elevation_world=h*scale-depth,
            render_mode='projected_prop',blocking=True,interactive=False,proportion_locked=True,shadow_baked=False,
            editor_subcategory='furnishings',authoring_set='chess-room-v1')
        assets.append(a)
    for key,width,depth in [('chess_table',140,105),('card_table',140,105),('stool',40,30),
        ('bench',60,265),('cupboard',110,45),('tea',50,30),('bin',30,22)]:prop(key,width,depth)
    sign=deepcopy(sources['sign']);w,h=sign['region'][2:];size=[150,h*150/w]
    sign.update(id='chess_sign_v1',name='棋牌室 · 门牌',world_size=size,render_size=size,
        footprint_world_size=size,ground_rect=[0,0,w,h],elevation_world=0,render_mode='wall_attachment',
        blocking=False,editor_subcategory='attachments',authoring_set='chess-room-v1')
    assets.append(sign)
    templates=read(ROOT/'art/architecture/cafeteria_v1/manifest.json')['assets']
    base=next(a for a in templates if a['id']=='cafeteria_wall_h_00')['region']
    wall=deepcopy(sources['wall']);r=wall['region'];desired=round(r[3]*320/120)
    r[0]+=round((r[2]-desired)/2);r[2]=desired
    for template in templates:
        if not template.get('grid_tile'):continue
        a=deepcopy(template);a.update(deepcopy(wall),id=template['id'].replace('cafeteria_','chess_')+'_v1',
            name=template['name'].replace('食堂','棋牌室')+' · 灰蓝墙裙',authoring_set='chess-room-v1')
        a['connection_tag']=a['connection_tag'].replace('cafeteria/','chess-room/')
        a.pop('legacy_id',None)
        for p in a.get('assembly_patches',[]):
            x,y,w,h=p['source']
            p['source']=[r[0]+(x-base[0])/base[2]*r[2],r[1]+(y-base[1])/base[3]*r[3],w/base[2]*r[2],h/base[3]*r[3]]
        assets.append(a)
    def reuse(path,old_id,new_id,width,mode=None):
        a=deepcopy(next(a for a in read(ROOT/path)['assets'] if a['id']==old_id))
        ratio=width/a['world_size'][0]
        for key in ['world_size','render_size','footprint_world_size']:
            if key in a:a[key]=[n*ratio for n in a[key]]
        if 'elevation_world' in a:a['elevation_world']*=ratio
        a.update(id=new_id,name='棋牌室 · '+a.get('name',old_id),authoring_set='chess-room-v1')
        if mode:a['render_mode']=mode;a['blocking']=False;a['editor_subcategory']='attachments'
        assets.append(a);return a
    reuse('art/architecture/cafeteria_v1/manifest.json','cafeteria_window_v1','chess_window_v1',100,'wall_attachment')
    notice=reuse('art/props/reading_room_v1/manifest.json','reading_notice_v1','chess_notice_v1',80,'wall_attachment')
    # Only the lower noticeboard region is reused; its unrelated room sign/clock stay out.
    notice.update(region=[317,433,885,490],ground_rect=[0,0,885,490],world_size=[80,80*490/885],
        render_size=[80,80*490/885],footprint_world_size=[80,80*490/885])
    reuse('art/props/duty_room_v1/manifest.json','duty_clock_v1','chess_clock_v1',30,'wall_attachment')
    floor=deepcopy(read(ROOT/'art/environment/duty_room_v1/manifest.json')['assets'][0])
    floor.update(id='chess_tiles_v1',name='棋牌室灰绿小方砖',render_mode='architecture_material',editor_hidden=True)
    assets.append(floor)
    doors=read(ROOT/'art/architecture/cafeteria_v2/manifest.json')['assets']
    for state in ['open','closed']:
        a=deepcopy(next(a for a in doors if a['id']=='doorway_cafeteria_'+state+'_v2'))
        a.update(id='doorway_chess_'+state+'_v1',name='棋牌室灰蓝钢门 · '+('全开' if state=='open' else '关闭'),
            authoring_set='chess-room-v1',world_size=[180,120],render_size=[180,120])
        p=a['door_presentation'];p.update(door_art_size=[180,120],door_art='doorway_chess_open_v1',door_art_closed='doorway_chess_closed_v1')
        for key in ['door_open_patches','door_closed_patches']:
            for patch in p[key]:
                d=patch['destination'];d[1]*=1.2;d[3]*=1.2
        for key in ['visual_solid_parts','closed_visual_solid_parts']:
            for d in p[key]:d[1]*=1.2;d[3]*=1.2
        assets.append(a)
    write(ART/'manifest.json',dict(schema=2,version='chess-room-v1',assets=assets))
    write(DOC/'asset-registration.json',dict(mode='built-in image_gen',original_pngs=records,definition_ids=[a['id'] for a in assets],
        reused_sets=['cafeteria_v1','cafeteria_v2','reading_room_v1','duty_room_v1']))
    return {a['id']:a for a in assets}

def restore(defs):
    path=ROOT/'data/rooms/r04.json';start=sha(path);m=read(path)
    assert m.get('chess_restoration_version')!=1,'Already restored; do not replay over user edits.'
    assert next(r for r in m['visibility_rooms'] if r['id']=='clinic')['rect']==[1520,220,520,500]
    # Only the old perimeter strip in the vacant bathhouse site is replaced.
    removed={i for i,r in enumerate(m['walls']) if 880<=r[0]<1480 and r[1]==100}
    write(DOC/'restoration-input.json',m)
    oldwall=deepcopy(m['walls']);oldsurfaces=deepcopy(m['architecture']['wall_surfaces'])
    mapping={};walls=[]
    for i,r in enumerate(m['walls']):
        if i in removed:continue
        mapping[i]=len(walls);walls.append(r)
    surfaces=[]
    for s in m['architecture']['wall_surfaces']:
        i=int(s['wall_index'])
        if i in removed:continue
        s['wall_index']=mapping[i];surfaces.append(s)
    m['walls']=walls;m['architecture']['wall_surfaces']=surfaces
    added=[]
    def wall(id,x,y):
        a=defs[id];index=len(m['walls']);m['walls'].append([x,y,*a['world_size']])
        surfaces.append(dict(wall_index=index,grid_tile_asset=id,height=20,coping_elevation=100,collision_parts=deepcopy(a['collision_parts'])))
        added.append(index)
    for id,x,y in [('nw',880,100),('ne',1440,100),('sw',880,680),('se',1440,680)]:wall('chess_corner_'+id+'_v1',x,y)
    for y in [100,700]:
        for x in range(920,1440,40):
            if y==700 and 1120<=x<1280:continue
            wall('chess_wall_h_%02d_v1'%(((x-920)//20)%16),x,y)
    for x in [880,1460]:
        for y in range(220,680,20):wall('chess_wall_v_short_v1',x,y)
    fixture_ids=[]
    def place(id,asset,x,y,**extra):
        a=defs[asset];r=[x,y,*a['footprint_world_size']]
        f=dict(id=id,asset_id=asset,rect=r,blocks_movement=bool(a.get('blocking',False)),blocks_sight=False)
        f.update(extra);m['fixtures'].append(f);fixture_ids.append(id);return f
    place('chess-table','chess_chess_table_v1',1110,320)
    place('chess-card-table','chess_card_table_v1',1110,550)
    for i,(x,y) in enumerate([(1160,245),(1040,375),(1280,375),(1160,435),
        (1160,490),(1040,605),(1280,605),(1160,670)]):place('chess-stool-'+str(i),'chess_stool_v1',x,y)
    place('chess-bench','chess_bench_v1',925,330)
    place('chess-cupboard','chess_cupboard_v1',1320,260,loot_profile='personal',loot_location='棋牌活动室',loot_name='棋牌收纳柜')
    place('chess-tea','chess_tea_v1',1350,610)
    place('chess-bin','chess_bin_v1',1370,665)
    for i,x in enumerate([970,1130]):place('chess-window-'+str(i),'chess_window_v1',x,140,draw_depth=251)
    place('chess-notice','chess_notice_v1',1270,128,draw_depth=252)
    place('chess-clock','chess_clock_v1',1370,140,draw_depth=253)
    place('chess-sign','chess_sign_v1',945,733,draw_depth=822,exterior_shell=True)
    m['access_doors'].append(dict(id='chess-entry',name='棋牌活动室',kind='timed',hours=[480,1200],
        initial_closed=False,rect=[1120,800,160,20],room_rect=AREA.copy(),evacuation=[1200,910],
        asset_id='doorway_chess_closed_v1',blocks_sight=False))
    f=place('chess-door-visual','doorway_chess_closed_v1',1120,800,access_id='chess-entry',
        open_asset='doorway_chess_open_v1',closed_asset='doorway_chess_closed_v1',render_size=[180,120],blocks_movement=False)
    m['visibility_rooms'].append(dict(id='chess-room',name='棋牌活动室',kind='room',rect=AREA.copy(),
        door_ids=['chess-entry'],roof_style='concrete',retained_wall_edges=True))
    m['zones'].append(dict(id='chess-room',name='棋牌活动室',rect=AREA.copy(),hide_label=True,color='#9c9b89'))
    m['floor_regions'].append(dict(id='chess-room',room_id='chess-room',asset_id='chess_tiles_v1',manifest=MANIFEST,
        rect=[880,200,600,620],tile_size=[240,240]))
    free_points=[[1060,430],[1310,435],[1330,645]]
    m['routine_points']['free'].extend(deepcopy(free_points))
    relocated=[]
    for s in m.get('resident_staff',[]):
        if s['id']=='bath-cashier' and 900<=s['position'][0]<1460 and 220<=s['position'][1]<860:
            s['position']=[2020,3550];s['patrol']=[];relocated.append(s['id'])
    m['chess_restoration_version']=1
    assert sha(path)==start,'Map changed while preparing; re-read before applying.'
    write(path,m);write(DOC/'restoration-output.json',m)
    write(DOC/'layout-registration.json',dict(area=AREA,new_fixture_ids=fixture_ids,removed_wall_indices=sorted(removed),
        added_wall_indices=added,free_points=free_points,relocated_staff=relocated,input_sha256=start,output_sha256=sha(path),
        door_hours=[480,1200],roof_style='concrete'))
    print('Restored chess room:',len(fixture_ids),'fixtures,',len(added),'wall tiles.')

if __name__=='__main__':
    defs=register();restore(defs)
