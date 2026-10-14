"""Register original monitor-room sprites and prepare a guarded MCP map edit."""
from copy import deepcopy
import hashlib,json,shutil
from pathlib import Path
from PIL import Image
from compact_clinic import contains_wall
from register_clinic_architecture import door_parts

ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs/art/monitor-room-v01'
SHADER='res://art/architecture/v25/safe_edges_v25.gdshader'
PREFIX='monitor-v1-'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(v,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')

def definitions():
    originals={};records=[]
    for item in read(DOC/'generated-assets.json')['assets']:
        p=ROOT/item['path'];p.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(item['source'],p)
        assert sha(p)==sha(Path(item['source']))
        im=Image.open(p)
        if item['transparent']:
            assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
            x,y,r,b=im.getchannel('A').point(lambda a:255 if a>=180 else 0).getbbox()
            x=max(0,x-3);y=max(0,y-3);r=min(im.width,r+3);b=min(im.height,b+3)
        else:x,y,r,b=0,0,*im.size
        originals[item['key']]=dict(texture='res://'+item['path'],texture_size=list(im.size),region=[x,y,r-x,b-y],
            sha256=sha(p),source_kind='built-in-imagegen-original-png',alpha_core_shader=SHADER,runtime_size_limit=512)
        records.append(dict(key=item['key'],path=item['path'],sha256=sha(p),region=[x,y,r-x,b-y]))
    props=[]
    for key,name,width,depth in [('screen_wall','八屏监视屏墙',260,1),('console','金属操作台',260,36),('rack','录像设备柜',56,40),('chair','操作椅',44,40),('desk','日志记录桌',65,None),('sign','名称牌',90,None)]:
        a=deepcopy(originals[key]);_,_,w,h=a['region'];scale=width/w;paint_h=h*scale
        if depth is None:depth=paint_h*(.82 if key=='desk' else 1)
        assert paint_h>=depth,(key,paint_h,depth)
        main=key in ['console','rack','chair','desk']
        a.update(id='monitor_'+key+'_v1',name='监控室 · '+name,render_mode='projected_prop',
            ground_rect=[0,h-depth/scale,w,depth/scale],world_size=[width,paint_h],render_size=[width,paint_h],
            footprint_world_size=[width,depth],elevation_world=paint_h-depth,blocking=main,
            interactive=False,shadow_baked=True,proportion_locked=True,editor_subcategory='furnishings' if main else 'attachments')
        if key=='screen_wall':a.update(render_mode='wall_attachment')
        if key=='sign':
            # The plaque is on the exterior door header. A virtual foot strip
            # below the threshold keeps it visible when the interior is roofed.
            a.update(render_mode='wall_attachment',ground_rect=[0,120/scale,w,1/scale],
                footprint_world_size=[width,1],elevation_world=120)
        props.append(a)
    # Reuse the existing paper roster as a small wall clipboard, keeping its PNG.
    clipboard=deepcopy(next(a for a in read(ROOT/'art/props/duty_room_v1/manifest.json')['assets'] if a['id']=='duty_roster_v1'))
    _,_,cw,ch=clipboard['region'];cs=32/cw
    clipboard.update(id='monitor_clipboard_v1',name='监控室 · 值守夹板',world_size=[32,ch*cs],render_size=[32,ch*cs],
        ground_rect=[0,0,cw,ch],footprint_world_size=[32,ch*cs],elevation_world=0,editor_subcategory='attachments',runtime_size_limit=512)
    props.append(clipboard)
    write(ROOT/'art/props/monitor_room_v1/manifest.json',dict(schema=2,version='monitor-room-v1',assets=props))
    floor=deepcopy(originals['floor']);floor.update(id='monitor_tiles_v1',name='监控室灰绿地砖',runtime_size_limit=1024)
    write(ROOT/'art/environment/monitor_room_v1/manifest.json',dict(schema=2,assets=[floor]))
    roof=deepcopy(originals['roof']);roof.pop('region');roof.update(id='monitor_roof_surface',name='监控室灰蓝机房屋顶',render_mode='architecture_material',world_size=[420,540],opaque=True,runtime_size_limit=1024)
    write(ROOT/'art/architecture/monitor_room_v1/roof-manifest.json',dict(schema=2,assets=[roof]))
    wall=deepcopy(originals['wall']);wx,wy,ww,wh=wall['region'];cap_h=wh*.085
    legacy={a['id']:a for v in ['v36','v38'] for a in read(ROOT/f'art/architecture/{v}/manifest.json')['assets']}
    architecture=[]
    def patch(src,dest,**extra):return dict(source=src,destination=dest,role='complete_wall_body',**extra)
    def face(width,phase,y=0):
        result=[];cursor=0
        while cursor<width:
            current=(phase+cursor)%320;length=min(width-cursor,320-current)
            result.append(patch([wx+current/320*ww,wy,length/320*ww,wh],[cursor,y,length,120]));cursor+=length
        return result
    def cap(width,height,x=0,y=0):return patch([wx+ww*.2,wy,height/320*ww,cap_h],[x,y,width,height],rotation_quarters=1)
    def register(identifier,base,patches):
        old=legacy[base];a=deepcopy(wall)
        a.update(id=identifier,name='监控室墙体 · '+identifier.removeprefix('monitor_'),render_mode=old['render_mode'],
            world_size=old['render_size'],render_size=old['render_size'],assembly_patches=patches,blocking=False,
            collision_parts=deepcopy(old['collision_parts']),connections=old['connections'],connection_tag='monitor/'+old['connection_tag'],
            authoring_set='monitor-room-v1',grid_tile={'cell':20,'columns':old['render_size'][0]/20,'rows':old['render_size'][1]/20,'parameterized_shader':False})
        architecture.append(a)
    for i in range(16):register(f'monitor_wall_h_{i:02d}','prison_h_c',face(40,i*20))
    register('monitor_wall_h_short','prison_h_short_c',face(20,40))
    register('monitor_wall_v_long','prison_v_long',[cap(20,120)])
    register('monitor_wall_v_short','prison_v_short',[cap(20,20)])
    for side,base,right,south in [('nw','prison_l_se',False,False),('ne','prison_l_sw',True,False),('sw','prison_l_ne',False,True),('se','prison_l_nw',True,True)]:
        x=20 if right else 0;patches=face(40,60 if right else 0,20 if south else 0)
        patches.append(cap(20,20 if south else 100,x,0 if south else 20))
        joint=cap(20,20,x,20 if south else 0)
        joint['clip_polygon']=([[0,0],[1,0],[1,1]] if south and right else [[0,0],[1,0],[0,1]] if south else [[1,0],[1,1],[0,1]] if right else [[0,0],[1,1],[0,1]])
        patches.append(joint);register('monitor_corner_'+side,base,patches)
    for length in [80,20]:register(f'monitor_lintel_{length}',f'prison_lintel_{length}',[patch([wx,wy,length/320*ww,cap_h],[0,0,length,20])])
    for state in ['open','closed']:
        key='door_'+state;a=deepcopy(originals[key]);x,y,w,h=a['region']
        a.update(id='doorway_monitor_'+state+'_v1',name='监控室钢门 · '+('开启' if state=='open' else '关闭'),render_mode='embedded_door',
            world_size=[200,120],render_size=[200,120],footprint_world_size=[180,20],ground_rect=[0,0,w,h],blocking=False,grid_door={'cell':20},editor_subcategory='doors')
        parts=door_parts(ROOT/read(DOC/'generated-assets.json')['assets'][next(i for i,v in enumerate(read(DOC/'generated-assets.json')['assets']) if v['key']==key)]['path'],a['region'],200) if state=='open' else [[20,12,160,108]]
        if state=='open':
            ratio=120/(h/w*200);parts=[[p[0],p[1]*ratio,p[2],p[3]*ratio] for p in parts if p[1]*ratio>=12]
        a['door_presentation']={'door_art':'doorway_monitor_open_v1','door_art_closed':'doorway_monitor_closed_v1','door_art_size':[200,120],
            'visual_solid_parts':parts if state=='open' else [[0,12,20,108],[180,12,20,108]],'closed_visual_solid_parts':[[0,12,200,108]],'body_profile':'human_silhouette'}
        architecture.append(a)
    write(ROOT/'art/architecture/monitor_room_v1/manifest.json',dict(schema=2,version='monitor-room-v1',assets=architecture))
    write(DOC/'asset-registration.json',dict(mode='built-in-imagegen',assets=records,definition_ids=[a['id'] for a in props+architecture]))
    return {a['id']:a for a in props+architecture}

def prepare_map(assets):
    path=ROOT/'data/rooms/r04.json';digest=sha(path);before=path.read_bytes();r=json.loads(before)
    previous=next(v['rect'] for v in r['visibility_rooms'] if v['id']=='monitor');x,y,w,h=previous
    target=[x,y,w,500];dy=target[3]-h
    selected={i for i,rect in enumerate(r['walls']) if contains_wall(previous,rect)}
    profiles={int(v['wall_index']):v for v in r['architecture']['wall_surfaces']};remap={};walls=[];surfaces=[]
    for i,old in enumerate(r['walls']):
        rect=deepcopy(old);s=deepcopy(profiles.get(i,{}))
        if i in selected:
            base=s.get('monitor_base_asset',s['grid_tile_asset'])
            if old[1]>=y+h-100:rect[1]+=dy
            elif base.startswith('prison_v_'):
                end=min(rect[1]+rect[3],target[1]+target[3]-100)
                if end<=rect[1]:continue
                rect[3]=end-rect[1];s['collision_parts']=[[0,0,rect[2],rect[3]]]
            if base.startswith('prison_h_short'):identifier='monitor_wall_h_short'
            elif base.startswith('prison_h_'):identifier=f'monitor_wall_h_{int((rect[0]-x+20)%320/20):02d}'
            elif base.startswith('prison_v_'):identifier='monitor_wall_v_short' if rect[3]<=40 else 'monitor_wall_v_long'
            else:identifier={'prison_l_se':'monitor_corner_nw','prison_l_sw':'monitor_corner_ne','prison_l_ne':'monitor_corner_sw','prison_l_nw':'monitor_corner_se','prison_lintel_80':'monitor_lintel_80','prison_lintel_20':'monitor_lintel_20'}[base]
            s.update(grid_tile_asset=identifier,monitor_base_asset=base)
        remap[i]=len(walls);walls.append(rect)
        if s:s['wall_index']=remap[i];surfaces.append(s)
    r['walls']=walls;r['architecture']['wall_surfaces']=surfaces
    for group in ['zones','visibility_rooms']:
        a=next(v for v in r[group] if v['id']=='monitor');a['rect']=target.copy()
        if group=='zones':a['hide_label']=True
        else:a['roof_style']='monitor'
    floor=next(v for v in r['floor_regions'] if v['id']=='campus-monitor')
    floor.update(asset_id='monitor_tiles_v1',manifest='res://art/environment/monitor_room_v1/manifest.json',rect=[x-20,y-20,w+40,560],tile_size=[160,160])
    for a in r['concept_plan'].get('horizontal',[]):
        if a['id']=='monitor-south':a['y']+=dy
    for a in r['concept_plan'].get('vertical',[]):
        if a['id'].startswith('monitor-'):a['y1']+=dy
    for key in ['room_rects','rooms']:
        if isinstance(r['concept_plan'].get(key),dict) and 'monitor' in r['concept_plan'][key]:r['concept_plan'][key]['monitor']=target.copy()
    r['fixtures']=[v for v in r['fixtures'] if v['id'] not in ['campus-admin-desk-2','campus-admin-board-2'] and not v.get('monitor_generated',False)]
    door=next(v for v in r['fixtures'] if v['id']=='campus-monitor-entry-visual')
    # Apply the same delta only to the retained authored gate, then keep it fixed on reruns.
    door['rect'][1]+=dy;door.update(asset_id='doorway_monitor_open_v1',open_asset='doorway_monitor_open_v1',closed_asset='doorway_monitor_closed_v1',render_size=[200,120])
    gate=next(v for v in r['access_doors'] if v['id']=='monitor-entry');gate['rect'][1]+=dy;gate['asset_id']='doorway_monitor_open_v1'
    cabinet=next(v for v in r['fixtures'] if v['id']=='campus-admin-cabinet-2');cabinet.update(rect=[x+15,y+270,70,32.5],blocks_sight=False)
    def prop(key,px,py,depth=None):
        a=assets['monitor_'+key+'_v1'];f=dict(id=PREFIX+key,asset_id=a['id'],rect=[x+px,y+py,*a['footprint_world_size']],blocks_movement=a['blocking'],blocks_sight=False,monitor_generated=True)
        if depth is not None:f['draw_depth']=depth
        r['fixtures'].append(f);return f
    screen=assets['monitor_screen_wall_v1'];screen_h=screen['render_size'][1]
    prop('screen_wall',20,40-1,y+41)
    console=assets['monitor_console_v1'];prop('console',20,100-console['footprint_world_size'][1])
    rack=assets['monitor_rack_v1'];rack_top=y+40-screen_h
    prop('rack',w-72,rack_top+rack['render_size'][1]-rack['footprint_world_size'][1]-y)
    prop('chair',128,160-assets['monitor_chair_v1']['footprint_world_size'][1])
    desk=assets['monitor_desk_v1'];prop('desk',w-80,400-desk['footprint_world_size'][1])
    prop('sign',145,540,y+560)
    prop('clipboard',6,125,y+271)
    r['resident_staff']=[v for v in r.get('resident_staff',[]) if v['id']!='monitor_guard']
    r['resident_staff'].append(dict(id='monitor_guard',name='监控值守',appearance_id='patrol_guard',role='monitor_guard',room_id='monitor',position=[x+105,y+300],patrol=[[x+105,y+300],[x+90,y+170],[x+225,y+320]],speed=26,wait_seconds=10,work_start=0,work_end=1440))
    r['monitor_restoration_version']=1
    assert sha(path)==digest,'Saved map changed while preparing; rerun on latest disk.'
    (DOC/'last-input-map.json').write_bytes(before)
    if not (DOC/'before-first-commit.json').exists():(DOC/'before-first-commit.json').write_bytes(before)
    write(DOC/'prepared-map.json',r)
    write(DOC/'map-registration.json',dict(before_sha256=digest,prepared_sha256=sha(DOC/'prepared-map.json'),before=previous,after=target,
        visible_interior=[x,y,w,420],selected_walls=sorted(selected),wall_remap=remap,commit_mode='MCP MapDocument transaction'))
    print('Prepared monitor room; main map untouched until guarded MCP commit.')
if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('--definitions-only',action='store_true');args=parser.parse_args()
    assets=definitions()
    if not args.definitions_only:prepare_map(assets)
