"""Register untouched generated PNGs and selectively furnish five existing dorms."""
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / 'docs/art/dorm-restoration'

def read(path):
    return json.loads(path.read_text(encoding='utf-8'))

def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent='\t')+'\n', encoding='utf-8')

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    sources = read(DOC/'generated-assets.json')
    specs = {
        'bunk': ('dorm_bunk_h_v1','寝室横向双层床',200,95),
        'locker': ('dorm_personal_locker_v1','寝室蓝灰私人储物柜',58,36),
        'toilet': ('dorm_toilet_v1','寝室独立马桶',40,48),
        'counter': ('dorm_wash_counter_ns_v1','寝室洗漱台与小灯',50,110),
        'stool': ('dorm_cushion_stool_v1','寝室布垫矮凳',55,30),
    }
    props=[]
    for item in sources['assets']:
        dest=ROOT/item['path']; dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(item['source'],dest)
        assert digest(dest)==digest(Path(item['source']))
        item['sha256']=digest(dest)
        im=Image.open(dest)
        assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
        # Metadata bounds only: original pixels and transparent alpha stay untouched.
        x0,y0,x1,y1=im.getchannel('A').point(lambda a:255 if a>=16 else 0).getbbox()
        x0=max(0,x0-3);y0=max(0,y0-3);x1=min(im.width,x1+3);y1=min(im.height,y1+3)
        w,h=x1-x0,y1-y0
        identifier,name,width,depth=specs[item['key']]; scale=width/w
        ground_h=depth/scale
        assert ground_h<=h
        props.append(dict(id=identifier,name=name,texture='res://'+item['path'],texture_size=list(im.size),
                          region=[x0,y0,w,h],ground_rect=[0,h-ground_h,w,ground_h],world_size=[width,h*scale],
                          render_size=[width,h*scale],footprint_world_size=[width,depth],elevation_world=h*scale-depth,
                          render_mode='projected_prop',proportion_locked=True,blocking=True,interactive=False,
                          shadow_baked=True,editor_subcategory='furnishings',
                          alpha_core_shader='res://art/architecture/v25/safe_edges_v25.gdshader',
                          source_kind='built-in-imagegen-original-png',sha256=item['sha256']))
    write(ROOT/'art/props/dorm_restoration/manifest.json',dict(schema=2,assets=props))
    map_path=ROOT/'data/rooms/r04.json'; before=digest(map_path); data=read(map_path)
    shutil.copyfile(map_path,DOC/'last-input-map.json')
    baseline=DOC/'baseline/r04.json'
    if not baseline.exists():
        baseline.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(map_path,baseline)
    rooms=[r for r in data['visibility_rooms'] if r['id'] in ['dorm-0','dorm-1','dorm-2','dorm-extra-0','dorm-extra-1']]
    assert len(rooms)==5
    replaced=[];added=[]
    for room in rooms:
        rid=room['id'];x,y,w,h=room['rect'];assert (w,h)==(560,300)
        extra=rid.startswith('dorm-extra-');index=int(rid.rsplit('-',1)[1])
        bed=f'campus-dorm-bed-{index}' if extra else f'bed_{index}'
        cabinet=f'campus-dorm-cabinet-{index}' if extra else f'detail44-dorm-personal-{index}'
        toilet=f'campus-dorm-wash-{index}' if extra else f'wash_{index}'
        removed={f'campus-dorm-basket-{index}'} if extra else {f'detail44-dorm-basket-{index}',f'detail44-dorm-linen-{index}'}
        new_ids={f'dorm-decor-{rid}-counter',f'dorm-decor-{rid}-stool'}
        changed={bed,cabinet,toilet}|removed|new_ids;replaced.extend(changed)
        old={f['id']:f for f in data['fixtures'] if f.get('id') in {bed,cabinet,toilet}}
        assert set(old)=={bed,cabinet,toilet}
        data['fixtures']=[f for f in data['fixtures'] if f.get('id') not in changed]
        def put(identifier,key,dx,dy,source=None):
            asset_id,_,width,depth=specs[key]
            f=dict(source or {})
            for stale in ['render_size','rotation_quarters','draw_depth','solid_parts','hidden','mirror_x']:f.pop(stale,None)
            f.update(id=identifier,asset_id=asset_id,rect=[x+dx,y+dy,width,depth],blocks_movement=True,blocks_sight=False)
            data['fixtures'].append(f);added.append(identifier)
        put(bed,'bunk',20,70,old[bed])
        put(cabinet,'locker',285,124,old[cabinet])
        data['fixtures'][-1].update(loot_profile='personal',loot_name='私人储物柜',loot_location=room.get('name','寝室'))
        put(toilet,'toilet',390,100,old[toilet])
        put(f'dorm-decor-{rid}-counter','counter',488,65)
        put(f'dorm-decor-{rid}-stool','stool',20,182)
        # Keep light coverage, but use the lamp drawn on the new wash counter.
        # The former hanging fixture would overlap the locker face.
        lamps=[l for l in data['lamps'] if l.get('dorm_decor_room_id')==rid or
               x<=l['position'][0]<=x+w and y<=l['position'][1]<y+h]
        assert len(lamps)<=1
        if lamps:
            lamp=lamps[0]
        else:
            lamp=dict(radius=280);data['lamps'].append(lamp)
        lamp.update(position=[x+513,y+28],draw_fixture=False,dorm_decor_room_id=rid)
    if digest(map_path)!=before:raise RuntimeError('Map changed during registration. Rerun against latest saved map.')
    write(map_path,data)
    write(DOC/'registration.json',dict(mode=sources['mode'],assets=sources['assets'],replaced_fixture_ids=sorted(set(replaced)),
          new_fixture_ids=added,room_ids=[r['id'] for r in rooms],map_before_sha256=before,map_after_sha256=digest(map_path)))
    print('Five dorms furnished; all walls, doors, starts, floors and other rooms preserved.')

if __name__=='__main__':main()
