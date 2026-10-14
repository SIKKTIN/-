"""Register original duty-room sprites; restore only the latest saved duty room."""
from copy import deepcopy
import argparse,hashlib,json,shutil
from pathlib import Path
from PIL import Image
from compact_clinic import contains_wall
from register_clinic_architecture import door_parts
ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs/art/duty-room-restoration'
SHADER='res://art/architecture/v25/safe_edges_v25.gdshader'
def read(p):return json.loads(p.read_bytes())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(v,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')

def definitions():
    originals={};records=[]
    for item in read(DOC/'generated-assets.json')['assets']:
        p=ROOT/item['path'];p.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(item['source'],p)
        assert sha(p)==sha(Path(item['source']))
        im=Image.open(p)
        if item['key']!='floor':
            assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0,item['key']
            x,y,r,b=im.getchannel('A').point(lambda a:255 if a>=180 else 0).getbbox()
            x=max(0,x-3);y=max(0,y-3);r=min(im.width,r+3);b=min(im.height,b+3)
        else:x,y,r,b=0,0,*im.size
        originals[item['key']]=dict(texture='res://'+item['path'],texture_size=list(im.size),region=[x,y,r-x,b-y],
            sha256=sha(p),source_kind='built-in-imagegen-original-png',alpha_core_shader=SHADER)
        records.append(dict(key=item['key'],path=item['path'],sha256=sha(p),region=[x,y,r-x,b-y]))
    props=[]
    specs=[('desk','L形登记台',180,.76),('communications','矮通讯柜',115,.58),('locker','个人物品柜',40,.23),
           ('shelf','纵向档案架',45,.85),('chair','登记台木椅',38,.52),('phone','黑色值班电话',27,1),
           ('ledger','登记簿与笔',48,1),('lamp','绿色值班台灯',24,1),('mug','搪瓷茶杯',12,1),
           ('radio','旧式无线电',33,1),('charger','对讲机充电座',28,1),('keybox','壁挂钥匙柜',60,1),
           ('clock','值班挂钟',25,1),('roster','壁挂值班表',38,1),('sign','值班室名称牌',90,1)]
    for key,name,width,ground_fraction in specs:
        a=deepcopy(originals[key]);_,_,w,h=a['region'];scale=width/w;gh=h*ground_fraction
        main=key in ['desk','communications','locker','shelf','chair']
        a.update(id='duty_'+key+'_v1',name='值班室 · '+name,render_mode='projected_prop',
            ground_rect=[0,h-gh,w,gh],world_size=[width,h*scale],render_size=[width,h*scale],
            footprint_world_size=[width,gh*scale],elevation_world=(h-gh)*scale,blocking=main,
            interactive=False,shadow_baked=not main,proportion_locked=True,
            editor_subcategory='furnishings' if main else 'attachments' if key in ['keybox','clock','roster','sign'] else 'misc')
        if key=='desk':a['solid_parts']=[[0,.56,1,.44],[.77,0,.23,.56]]
        if key=='keybox':
            # A virtual floor registration strip gives wall storage a reachable
            # interaction point, without putting it behind the north collider.
            a.update(render_mode='wall_attachment',ground_rect=[0,h+82/scale,w,1/scale],
                footprint_world_size=[width,1],elevation_world=h*scale+82)
        props.append(a)
    for file,source,identifier,name,width in [
        ('art/props/exercise_yard_v54/manifest.json','yard_bench_vertical_v54','duty_bench_v1','等候长凳',24),
        ('art/props/factory_v44/manifest.json','weed_planter_v44','duty_planter_v1','旧盆绿植',42)]:
        a=deepcopy(next(v for v in read(ROOT/file)['assets'] if v['id']==source));w,h=a['region'][2:];scale=width/w;g=a['ground_rect']
        a.update(id=identifier,name='值班室 · '+name,render_size=[width,h*scale],world_size=[width,h*scale],
            footprint_world_size=[g[2]*scale,g[3]*scale],elevation_world=(h-g[3])*scale,proportion_locked=True,editor_subcategory='furnishings')
        a.pop('editor_icon',None);props.append(a)
    write(ROOT/'art/props/duty_room_v1/manifest.json',dict(schema=2,version='duty-room-v1',assets=props))
    floor=deepcopy(originals['floor']);floor.update(id='duty_tiles_v1',name='值班室灰绿小方砖')
    write(ROOT/'art/environment/duty_room_v1/manifest.json',dict(schema=2,assets=[floor]))
    wall=deepcopy(originals['wall']);wx,wy,ww,wh=wall['region'];cap_h=wh*.22
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
        a.update(id=identifier,name='值班室墙体 · '+identifier.removeprefix('duty_'),render_mode=old['render_mode'],
            world_size=old['render_size'],render_size=old['render_size'],assembly_patches=patches,blocking=False,
            collision_parts=deepcopy(old['collision_parts']),connections=old['connections'],connection_tag='duty/'+old['connection_tag'],
            authoring_set='duty-room-v1',grid_tile={'cell':20,'columns':old['render_size'][0]/20,'rows':old['render_size'][1]/20,'parameterized_shader':False})
        architecture.append(a)
    for i in range(16):register(f'duty_wall_h_{i:02d}','prison_h_c',face(40,i*20))
    register('duty_wall_h_short','prison_h_short_c',face(20,40))
    register('duty_wall_v_long','prison_v_long',[cap(20,120)])
    register('duty_wall_v_short','prison_v_short',[cap(20,20)])
    for side,base,right,south in [('nw','prison_l_se',False,False),('ne','prison_l_sw',True,False),('sw','prison_l_ne',False,True),('se','prison_l_nw',True,True)]:
        x=20 if right else 0;patches=face(40,60 if right else 0,20 if south else 0)
        patches.append(cap(20,20 if south else 100,x,0 if south else 20))
        joint=cap(20,20,x,20 if south else 0)
        joint['clip_polygon']=([[0,0],[1,0],[1,1]] if south and right else [[0,0],[1,0],[0,1]] if south else [[1,0],[1,1],[0,1]] if right else [[0,0],[1,1],[0,1]])
        patches.append(joint);register('duty_corner_'+side,base,patches)
    for length in [80,20]:register(f'duty_lintel_{length}',f'prison_lintel_{length}',[patch([wx,wy,length/320*ww,cap_h],[0,0,length,20])])
    for state in ['open','closed']:
        key='door_'+state;a=deepcopy(originals[key]);x,y,w,h=a['region']
        a.update(id='doorway_duty_'+state+'_v1',name='值班室钢门 · '+('开启' if state=='open' else '关闭'),
            render_mode='embedded_door',world_size=[200,120],render_size=[200,120],footprint_world_size=[180,20],
            ground_rect=[0,0,w,h],blocking=False,grid_door={'cell':20},editor_subcategory='doors')
        parts=door_parts(ROOT/f'art/architecture/duty_room_v1/{key}.png',a['region'],200) if state=='open' else [[0,12,200,108]]
        if state=='open':
            # The source ratio is calibrated to the same 120-high frame in both states.
            ratio=120/(h/w*200)
            parts=[[p[0],p[1]*ratio,p[2],p[3]*ratio] for p in parts if p[1]*ratio>=12]
        a['door_presentation']={'door_art':a['id'],'door_art_size':[200,120],'visual_solid_parts':parts,'body_profile':'human_silhouette'}
        architecture.append(a)
    write(ROOT/'art/architecture/duty_room_v1/manifest.json',dict(schema=2,version='duty-room-v1',assets=architecture))
    write(DOC/'asset-registration.json',dict(mode='built-in image_gen',assets=records,definition_ids=[a['id'] for a in props+architecture]))
    return {a['id']:a for a in props+architecture}

def restore_map(assets):
    path=ROOT/'data/rooms/r04.json';before=path.read_bytes();digest=sha(path);r=json.loads(before)
    previous=next(v['rect'] for v in r['visibility_rooms'] if v['id']=='duty');x,y,w,h=previous
    target=[x,y+h-min(h,440),w,min(h,440)];dy=target[1]-y
    selected={i for i,rect in enumerate(r['walls']) if contains_wall(previous,rect)}
    profiles={int(v['wall_index']):v for v in r['architecture']['wall_surfaces']};remap={};walls=[];surfaces=[]
    for i,old in enumerate(r['walls']):
        rect=deepcopy(old);s=deepcopy(profiles.get(i,{}))
        if i in selected:
            base=s.get('duty_base_asset',s['grid_tile_asset'])
            if old[1]==y-120:rect[1]+=dy
            elif base.startswith('prison_v_'):
                start=max(rect[1],target[1]);end=rect[1]+rect[3]
                if end<=start:continue
                rect[1]=start;rect[3]=end-start;s['collision_parts']=[[0,0,rect[2],rect[3]]]
            if base.startswith('prison_h_short'):identifier='duty_wall_h_short'
            elif base.startswith('prison_h_'):identifier=f'duty_wall_h_{int((rect[0]-x+20)%320/20):02d}'
            elif base.startswith('prison_v_'):identifier='duty_wall_v_short' if rect[3]<=40 else 'duty_wall_v_long'
            else:identifier={'prison_l_se':'duty_corner_nw','prison_l_sw':'duty_corner_ne','prison_l_ne':'duty_corner_sw','prison_l_nw':'duty_corner_se','prison_lintel_80':'duty_lintel_80','prison_lintel_20':'duty_lintel_20'}[base]
            s.update(grid_tile_asset=identifier,duty_base_asset=base)
        remap[i]=len(walls);walls.append(rect)
        if s:s['wall_index']=remap[i];surfaces.append(s)
    r['walls']=walls;r['architecture']['wall_surfaces']=surfaces
    for group in ['zones','visibility_rooms']:
        a=next(v for v in r[group] if v['id']=='duty');a['rect']=target.copy()
        if group=='zones':a['hide_label']=True
    for a in r['concept_plan']['horizontal']:
        if a['id']=='duty-north':a['y']=target[1]-20
    for a in r['concept_plan']['vertical']:
        if a['id'].startswith('duty-'):a['y0']=target[1]-20
    for key in ['room_rects','rooms']:
        if isinstance(r['concept_plan'].get(key),dict) and 'duty' in r['concept_plan'][key]:r['concept_plan'][key]['duty']=target.copy()
    floor=next(v for v in r['floor_regions'] if v['id']=='campus-duty')
    floor.update(asset_id='duty_tiles_v1',manifest='res://art/environment/duty_room_v1/manifest.json',rect=[x-20,target[1]-20,w+40,target[3]+60],tile_size=[160,160])
    r['floor_regions']=[v for v in r['floor_regions'] if v['id']!='duty-north-grass']
    if dy>0:r['floor_regions'].insert(r['floor_regions'].index(floor),dict(id='duty-north-grass',asset_id='grass_base_v46',manifest='res://art/environment/factory_v46/manifest.json',rect=[x-20,y-120,w+40,dy],tile_size=[930,930],natural_ground=True))
    r['fixtures']=[v for v in r['fixtures'] if v['id'] not in ['campus-admin-desk-0','campus-admin-cabinet-0','campus-admin-board-0'] and not v.get('duty_generated',False)]
    door=next(v for v in r['fixtures'] if v['id']=='campus-duty');door['asset_id']='doorway_duty_open_v1';door['render_size']=[200,120]
    def prop(identifier,key,px,py,loot=None,depth=None):
        asset='duty_'+key+'_v1';dims=assets[asset]['footprint_world_size']
        a=dict(id=identifier,asset_id=asset,rect=[x+px,target[1]+py,*dims],blocks_movement=assets[asset].get('blocking',True),blocks_sight=False,duty_generated=True)
        if assets[asset].get('solid_parts'):a['solid_parts']=assets[asset]['solid_parts']
        if loot:a.update(loot_profile=loot,loot_location='值班室',loot_name=assets[asset]['name'].split(' · ')[-1])
        if depth is not None:a['draw_depth']=target[1]+depth
        r['fixtures'].append(a);return a
    desk=prop('campus-admin-desk-0','desk',180,205,'office');comm=prop('duty-communications','communications',85,40,'office')
    for identifier,key,px,py,loot in [('campus-admin-cabinet-0','locker',20,40,'office'),('duty-shelf','shelf',12,130,'office'),('duty-chair','chair',225,190,None),('duty-bench','bench',15,325,None),('duty-planter','planter',323,320,None)]:
        f=prop(identifier,key,px,py,loot)
        if key=='bench':f['rect'][2:]=reversed(f['rect'][2:]);f['rotation_quarters']=1
    for key,px,py,loot,depth in [('keybox',230,40,'duty_keys',70),('clock',132,-76,None,70),('roster',307,-75,None,70),('sign',145,355,None,480)]:prop('duty-'+key,key,px,py,loot,depth)
    dd=desk['rect'][1]+desk['rect'][3]-target[1]+1
    for key,px,py in [('ledger',198,218),('phone',267,209),('lamp',327,170),('mug',301,228)]:prop('duty-'+key,key,px,py,None,dd)
    cd=comm['rect'][1]+comm['rect'][3]-target[1]+1
    prop('duty-radio','radio',92,14,None,cd);prop('duty-charger','charger',156,4,None,cd)
    r['resident_staff']=[v for v in r.get('resident_staff',[]) if v['id']!='duty_guard']
    r['resident_staff'].append(dict(id='duty_guard',name='值班看守',appearance_id='patrol_guard',role='duty_guard',room_id='duty',position=[x+115,target[1]+260],patrol=[[x+115,target[1]+260],[x+135,target[1]+150],[x+140,target[1]+330]],speed=28,wait_seconds=10,work_start=0,work_end=1440))
    r['duty_restoration_version']=1
    assert sha(path)==digest,'Saved map changed; rerun with latest saved draft.'
    loot_path=ROOT/'data/items/loot_tables.json';loot=read(loot_path)
    loot['profiles']['duty_keys']=dict(label='值班钥匙柜',guaranteed=['door_key','duty_roster'],items=['door_key','duty_roster','temporary_pass','secret_note'])
    write(loot_path,loot)
    (DOC/'last-input-map.json').write_bytes(before);write(path,r);(DOC/'last-output-map.json').write_bytes(path.read_bytes())
    write(DOC/'map-registration.json',dict(map_before_sha256=digest,map_after_sha256=sha(path),before=previous,after=target,selected_walls=sorted(selected),wall_remap=remap))
    print(f'Restored duty room {previous} -> {target}; unrelated saved layout preserved.')
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--definitions-only',action='store_true');args=parser.parse_args()
    assets=definitions()
    if not args.definitions_only:restore_map(assets)
    print('Registered 19 unchanged original PNGs and reusable duty-room assets.')
