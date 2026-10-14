"""Register original bathroom sprites, replace only the bathroom, and retain latest campus edits."""
from copy import deepcopy
from pathlib import Path
import hashlib
import json
import shutil
from PIL import Image
from compact_clinic import contains_wall

ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs/art/bath-restoration'
ART=ROOT/'art/architecture/bath_v1'
MANIFEST='res://art/architecture/bath_v1/manifest.json'
SHADER='res://art/architecture/v25/safe_edges_v25.gdshader'

def read(p):return json.loads(p.read_text(encoding='utf-8'))
def write(p,v):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(v,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    source=read(DOC/'generated-assets.json'); originals={}; records=[]
    for entry in source['assets']:
        path=ROOT/entry['path'];path.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(entry['source'],path)
        assert sha(path)==sha(Path(entry['source']))
        im=Image.open(path)
        asset=dict(texture='res://'+entry['path'],texture_size=list(im.size),source_kind='built-in-imagegen-original-png',sha256=sha(path))
        if entry['transparent']:
            assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
            x,y,right,bottom=im.getchannel('A').point(lambda a:255 if a>=180 else 0).getbbox()
            asset['region']=[max(0,x-3),max(0,y-3),min(im.width,right+3)-max(0,x-3),min(im.height,bottom+3)-max(0,y-3)]
        else:asset['opaque']=True
        originals[entry['key']]=asset
        records.append(dict(key=entry['key'],path=entry['path'],sha256=sha(path)))
    # The same mitred component geometry as the clinic, sampled from the
    # bathroom's own wall material. Source PNGs are never edited or resaved.
    originals['wall']['region']=[50,89,1959,542]
    clinic={a['id']:a for a in read(ROOT/'art/architecture/clinic_v1/manifest.json')['assets']}
    old_region=clinic['clinic_wall_h_00']['region'];new_region=originals['wall']['region']
    assets=[]
    for id,template in clinic.items():
        if not template.get('grid_tile') or not id.startswith(('clinic_wall_','clinic_corner_','clinic_lintel_')):continue
        asset=deepcopy(template);asset.update(deepcopy(originals['wall']))
        asset.update(id=id.replace('clinic_','bath_',1),name=template['name'].replace('医务室','浴室'),authoring_set='bath-v1',connection_tag=template['connection_tag'].replace('clinic/','bath/'))
        for part in asset['assembly_patches']:
            s=part['source']
            part['source']=[new_region[0]+(s[0]-old_region[0])/old_region[2]*new_region[2],new_region[1]+(s[1]-old_region[1])/old_region[3]*new_region[3],s[2]/old_region[2]*new_region[2],s[3]/old_region[3]*new_region[3]]
        assets.append(asset)
    def prop(key,id,name,width,ground_height=None,ground_fraction=None):
        asset=deepcopy(originals[key]);_,_,w,h=asset['region'];scale=width/w
        depth=ground_height if ground_height is not None else h*scale*ground_fraction
        asset.update(id=id,name=name,render_mode='projected_prop',world_size=[width,h*scale],render_size=[width,h*scale],ground_rect=[0,h-depth/scale,w,depth/scale],footprint_world_size=[width,depth],elevation_world=h*scale-depth,proportion_locked=True,blocking=True,shadow_baked=True,alpha_core_shader=SHADER,editor_subcategory='furnishings')
        assets.append(asset);return asset
    prop('shower','bath_shower_single','浴室单人淋浴隔墙',132,ground_height=8)
    prop('lockers','bath_changing_lockers','浴室四门更衣柜',140,ground_height=46)
    sign=prop('sign','bath_sign','公共浴室搪瓷标牌',104,ground_fraction=1)
    sign.update(blocking=False,render_mode='wall_attachment',editor_subcategory='attachments')
    for old,new,name,width in [('clinic_frosted_window','bath_frosted_window','浴室高位磨砂窗',120),('clinic_wall_light','bath_wall_light','浴室壁灯',34)]:
        a=deepcopy(clinic[old]);ratio=width/a['world_size'][0]
        for field in ['world_size','render_size','footprint_world_size']:a[field]=[v*ratio for v in a[field]]
        a.update(id=new,name=name);assets.append(a)
    roof_originals={a['id']:a for a in read(ROOT/'art/architecture/clinic_roof_v1/manifest.json')['assets']}
    drain=deepcopy(roof_originals['clinic_roof_drain']);_,_,dw,dh=drain['region'];width=17
    drain.update(id='bath_floor_drain',name='浴室地漏',render_mode='wall_attachment',ground_rect=[0,0,dw,dh],world_size=[width,width*dh/dw],render_size=[width,width*dh/dw],footprint_world_size=[width,width*dh/dw],proportion_locked=True,editor_subcategory='attachments',blocking=False,shadow_baked=True,alpha_core_shader=SHADER)
    assets.append(drain)
    roof=deepcopy(originals['roof']);roof.update(id='bath_roof_surface',name='浴室灰蓝防水屋面',render_mode='architecture_material',world_size=[480,580],fit_roof=True,blocking=False);assets.append(roof)
    vent=deepcopy(originals['vent']);_,_,vw,vh=vent['region'];vent.update(id='bath_roof_vent',name='浴室百叶排风帽',world_size=[44,44*vh/vw],render_mode='architecture_roof_detail',blocking=False);assets.append(vent)
    for key,id,name in [('floor','bath_dry_tiles','浴室更衣区防滑砖'),('wet_floor','bath_wet_tiles','浴室淋浴小地砖')]:
        a=deepcopy(originals[key]);a.update(id=id,name=name,render_mode='architecture_material',world_size=[160,160],blocking=False);assets.append(a)
    write(ART/'manifest.json',dict(schema=2,version='bath-v1',assets=assets))
    defs={a['id']:a for a in assets}
    path=ROOT/'data/rooms/r04.json';before=path.read_bytes();before_hash=sha(path);room=read(path)
    prior=next(r['rect'] for r in room['visibility_rooms'] if r['id']=='bath')
    # Keep the building's centre and north line. Snapped 440x540 is the
    # approved compact layout; adjacent rooms retain all their authored data.
    x=round((prior[0]+prior[2]/2-220)/20)*20;y=prior[1];area=[x,y,440,540]
    selected={i for i,r in enumerate(room['walls']) if contains_wall(prior,r)}
    remap={};walls=[];surfaces=[]
    for i,r in enumerate(room['walls']):
        if i not in selected:remap[i]=len(walls);walls.append(r)
    for s in room['architecture']['wall_surfaces']:
        if int(s['wall_index']) in remap:
            a=deepcopy(s);a['wall_index']=remap[int(s['wall_index'])];surfaces.append(a)
    def tile(id,tx,ty,w,h):
        a=defs[id];surfaces.append(dict(wall_index=len(walls),grid_tile_asset=id,height=20,collision_parts=deepcopy(a['collision_parts'])))
        walls.append([tx,ty,w,h])
    outer=x-20;right=x+440;front=y+560;coping=front-100;door_x=x+120
    tile('bath_corner_nw',outer,y-120,40,120)
    for tx in range(int(x+20),int(right-20),40):tile(f'bath_wall_h_{int((tx-outer)%320/20):02d}',tx,y-120,40,120)
    tile('bath_corner_ne',right-20,y-120,40,120)
    tile('bath_corner_sw',outer,coping-20,40,140)
    tile('bath_corner_se',right-20,coping-20,40,140)
    for start,end in [(x+20,door_x),(door_x+180,right-20)]:
        cursor=start
        while cursor<end:
            width=min(40,end-cursor)
            id=f'bath_wall_h_{int((cursor-outer)%320/20):02d}' if width==40 else 'bath_wall_h_short'
            tile(id,cursor,coping,width,120);cursor+=width
    tile('bath_lintel_80',door_x,coping,80,20);tile('bath_lintel_80',door_x+80,coping,80,20);tile('bath_lintel_20',door_x+160,coping,20,20)
    for tx in [outer,right]:
        cursor=y
        while cursor<coping-20:
            length=min(120,coping-20-cursor)
            tile('bath_wall_v_long' if length==120 else 'bath_wall_v_short',tx,cursor,20,length)
            surfaces[-1]['collision_parts']=[[0,0,20,length]];cursor+=length
    room['walls']=walls;room['architecture']['wall_surfaces']=surfaces
    for group in ['visibility_rooms','zones']:
        r=next(r for r in room[group] if r['id']=='bath');r.update(rect=area.copy(),name='公共浴室')
        if group=='visibility_rooms':r['roof_style']='bath'
        else:r['hide_label']=True
    original_fixtures={f['id']:deepcopy(f) for f in room['fixtures'] if str(f.get('id','')).startswith('campus-bath')}
    room['fixtures']=[f for f in room['fixtures'] if not str(f.get('id','')).startswith('campus-bath')]
    door=original_fixtures['campus-bath'];door.update(rect=[door_x,front,180,20],asset_id='doorway_free_v48',rotation_quarters=0,frame_only=True);door.pop('rotation_door_visual_rect',None);room['fixtures'].append(door)
    def fixture(id,asset,fx,fy,size=None,**extra):
        dims=size or defs[asset]['footprint_world_size']
        f=dict(id=id,asset_id=asset,rect=[fx,fy,*dims],blocks_movement=False,blocks_sight=False);f.update(extra);room['fixtures'].append(f);return f
    floors=[f for f in room['floor_regions'] if not str(f.get('id','')).startswith('campus-bath') and not str(f.get('id','')).startswith('bath-')]
    floors.append(dict(id='campus-bath',asset_id='bath_dry_tiles',manifest=MANIFEST,rect=[outer,y-20,480,600],tile_size=[160,160]))
    for col,bx in enumerate([x+10,right-142]):
        for row in range(3):
            by=y+40+90*row;id=f'campus-bath-shower-{col}-{row}'
            fixture(id,'bath_shower_single',bx,by,blocks_movement=True,mirror_x=col==1)
            floors.append(dict(id=f'bath-wet-{col}-{row}',asset_id='bath_wet_tiles',manifest=MANIFEST,rect=[bx,by+8,132,82],tile_size=[160,160]))
            fixture(id+'-drain','bath_floor_drain',bx+(100 if col==0 else 15),by+30,draw_depth=y-1)
    fixture('campus-bath-locker-0','bath_changing_lockers',x+10,y+395,blocks_movement=True,blocks_sight=True,loot_location='公共浴室',loot_name='更衣柜',loot_profile='linen')
    fixture('campus-bath-locker-1','changing_bench_v47',right-170,y+375,size=[160,58.9474],blocks_movement=True,blocks_sight=False)
    fixture('campus-bath-basket','linen_basket_v44',right-60,y+420,size=[48,37.3333],blocks_movement=True)
    fixture('campus-bath-window','bath_frosted_window',x+40,y-85,draw_depth=y+25)
    fixture('campus-bath-light','bath_wall_light',x+220,y-85,draw_depth=y+25)
    fixture('campus-bath-sign','bath_sign',x+312,y-85,draw_depth=y+25)
    room['floor_regions']=floors
    for segment in room.get('concept_plan',{}).get('horizontal',[]):
        if segment['id']=='bath-north':segment.update(x0=outer,x1=right+20,y=y-20,gaps=[])
        if segment['id']=='bath-south':segment.update(x0=outer,x1=right+20,y=front,gaps=[[door_x,door_x+180]])
    for segment in room.get('concept_plan',{}).get('vertical',[]):
        if segment['id']=='bath-west':segment.update(x=outer,y0=y-20,y1=front)
        if segment['id']=='bath-east':segment.update(x=right,y0=y-20,y1=front)
    room['bath_restoration_version']=1
    assert sha(path)==before_hash,'Map changed during registration; rerun on latest saved map.'
    if not (DOC/'baseline/r04.json').exists():
        (DOC/'baseline').mkdir(parents=True,exist_ok=True);(DOC/'baseline/r04.json').write_bytes(before)
    (DOC/'last-input-map.json').write_bytes(before);write(path,room)
    write(DOC/'last-output-map.json',room)
    write(DOC/'registration.json',dict(mode=source['mode'],assets=records,definition_ids=list(defs),map_before_sha256=before_hash,map_after_sha256=sha(path),area=area,removed_wall_count=len(selected)))
    print(f'Registered {len(assets)} bath definitions and 8 original PNGs. Six accessible showers; room {area}; removed {len(selected)} old wall pieces.')

if __name__=='__main__':main()
