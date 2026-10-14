"""Register original clinic art, compact its room, and preserve the rest of the campus."""
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image
from compact_clinic import compact

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / 'docs/art/clinic-restoration'

def read(path):
    return json.loads(path.read_text(encoding='utf-8'))

def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent='\t')+'\n', encoding='utf-8')

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    sources = read(DOC/'generated-assets.json')
    by_key = {}
    for item in sources['assets']:
        destination = ROOT/item['path']
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(item['source'], destination)
        assert digest(destination) == digest(Path(item['source']))
        by_key[item['key']] = item | {'sha256':digest(destination)}
    props = []
    # Ground rectangles record occupied floor area, not the whole visible height.
    specs = [('bed','clinic_exam_bed_h','医务室横向诊疗床',190,.80),
             ('counter','clinic_wash_counter_ns','医务室洗手消毒长台',70,.92),
             ('drawers','clinic_medicine_drawers','医务室抽屉药柜',104,.36),
             ('short_counter','clinic_preparation_counter_h','医务室短操作台',140,.35),
             ('instruments','clinic_instrument_tray','医务室器械托盘',30,.90),
             ('supplies','clinic_medicine_supplies','医务室药瓶与消毒棉',22,.35),
             ('linen','clinic_linen_record','医务室白布与病历',32,.80),
             ('record_sign','clinic_record_sign','医务室诊疗记录牌',78,1.0)]
    for key, identifier, name, width, ground_fraction in specs:
        item = by_key[key]
        image = Image.open(ROOT/item['path'])
        assert image.mode == 'RGBA' and image.getchannel('A').getextrema()[0] == 0
        # Inspect bounds only. Keep source pixels and their alpha unchanged.
        bounds = image.getchannel('A').point(lambda a:255 if a>=16 else 0).getbbox()
        x0,y0,x1,y1 = bounds
        x0=max(0,x0-3); y0=max(0,y0-3); x1=min(image.width,x1+3); y1=min(image.height,y1+3)
        w,h=x1-x0,y1-y0
        scale=width/w
        ground_h=h*ground_fraction
        entry=dict(id=identifier,name=name,texture='res://'+item['path'],texture_size=list(image.size),
                   region=[x0,y0,w,h],ground_rect=[0,h-ground_h,w,ground_h],
                   world_size=[width,h*scale],render_size=[width,h*scale],
                   footprint_world_size=[width,ground_h*scale],elevation_world=(h-ground_h)*scale,
                   render_mode='projected_prop',blocking=True,interactive=False,shadow_baked=False,
                   proportion_locked=True,editor_subcategory='furnishings',
                   alpha_core_shader='res://art/architecture/v25/safe_edges_v25.gdshader',
                   source_kind='built-in-imagegen-original-png',sha256=item['sha256'])
        props.append(entry)
        if key in ['instruments','supplies','linen','record_sign']:
            entry.update(blocking=False,shadow_baked=True,editor_subcategory='attachments' if key=='record_sign' else 'misc')
    for source_id, identifier, name, width in [
        ('medical_cabinet_v47','clinic_glass_cabinet','医务室玻璃储物柜',80),
        ('medical_trolley_v47','clinic_instrument_trolley','医务室器械推车',55)]:
        base=next(a for a in read(ROOT/'art/props/campus_v47/manifest.json')['assets'] if a['id']==source_id).copy()
        scale=width/base['region'][2]
        base.update(id=identifier,name=name,world_size=[width,base['region'][3]*scale],
                    render_size=[width,base['region'][3]*scale],
                    footprint_world_size=[base['ground_rect'][2]*scale,base['ground_rect'][3]*scale],
                    elevation_world=(base['region'][3]-base['ground_rect'][3])*scale,proportion_locked=True)
        base.pop('editor_icon',None)
        props.append(base)
    write(ROOT/'art/props/clinic_restoration/manifest.json',dict(schema=2,assets=props))
    terrain=[]
    for key in ['floor_a','floor_b']:
        item=by_key[key]
        image=Image.open(ROOT/item['path'])
        terrain.append(dict(id='clinic_tiles_'+key[-1],name='医务室浅色地砖 '+key[-1].upper(),
                            texture='res://'+item['path'],texture_size=list(image.size),
                            source_kind='built-in-imagegen-original-png',sha256=item['sha256']))
    write(ROOT/'art/environment/clinic_restoration/manifest.json',dict(schema=2,assets=terrain))

    room_path=ROOT/'data/rooms/r04.json'
    original_hash=digest(room_path)
    room=read(room_path)
    # Record this invocation's input as well as the initial recoverable backup.
    # Other chats may legitimately update other rooms between invocations.
    shutil.copyfile(room_path,DOC/'last-input-map.json')
    baseline=DOC/'baseline/r04.json'
    if not baseline.exists():
        baseline.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(room_path,baseline)
    compact(room)
    old_ids={'campus-clinic-bed-0','campus-clinic-bed-1','campus-clinic-cabinet-0',
             'campus-clinic-cabinet-1','campus-clinic-basin','campus-clinic-linen',
             'campus-clinic-wash-counter','campus-clinic-preparation-counter',
             'campus-clinic-plant-left','campus-clinic-plant-right',
             'campus-clinic-instruments','campus-clinic-supplies','campus-clinic-record-linen','campus-clinic-record-sign'}
    untouched=[f for f in room['fixtures'] if f.get('id') not in old_ids]
    room['fixtures']=untouched.copy()
    assets={p['id']:p for p in props}
    def fixture(identifier,asset,x,y,loot=False,width=None,height=None):
        dims=assets[asset]['footprint_world_size'] if asset in assets else [width,height]
        spec=dict(id=identifier,asset_id=asset,rect=[x,y,*dims],blocks_movement=True,blocks_sight=False)
        if loot:spec.update(loot_location='医务室',loot_name='抽屉药柜' if 'drawers' in asset else '医务柜',loot_profile='medical')
        room['fixtures'].append(spec)
    fixture('campus-clinic-bed-0','clinic_exam_bed_h',1770,765)
    fixture('campus-clinic-cabinet-0','clinic_medicine_drawers',1720,510,True)
    fixture('campus-clinic-wash-counter','clinic_wash_counter_ns',1545,515)
    fixture('campus-clinic-preparation-counter','clinic_preparation_counter_h',1545,480)
    fixture('campus-clinic-cabinet-1','clinic_glass_cabinet',1935,540,True)
    fixture('campus-clinic-basin','clinic_instrument_trolley',1980,735)
    fixture('campus-clinic-plant-left','weed_planter_v44',1640,795,False,40,35)
    fixture('campus-clinic-plant-right','weed_planter_v44',1990,795,False,40,35)
    for identifier,asset,x,y,depth in [
        ('campus-clinic-instruments','clinic_instrument_tray',1595,442,535),
        ('campus-clinic-supplies','clinic_medicine_supplies',1733,470,555),
        ('campus-clinic-record-linen','clinic_linen_record',1965,467,582),
        ('campus-clinic-record-sign','clinic_record_sign',1850,345,630)]:
        fixture(identifier,asset,x,y)
        room['fixtures'][-1].update(blocks_movement=False,draw_depth=depth)
    floor=[f for f in room['floor_regions'] if not f.get('id','').startswith('clinic-wear-')]
    for region in floor:
        if region.get('id')=='campus-clinic':
            region.update(asset_id='clinic_tiles_a',manifest='res://art/environment/clinic_restoration/manifest.json',tile_size=[160,160],rect=[1500,400,560,560])
    for index,rect in enumerate([[1660,560,160,160],[1820,720,160,120]]):
        floor.append(dict(id='clinic-wear-'+str(index),asset_id='clinic_tiles_b',
                          manifest='res://art/environment/clinic_restoration/manifest.json',rect=rect,tile_size=[160,160]))
    room['floor_regions']=floor
    staff=[s for s in room.get('resident_staff',[]) if s.get('id')!='clinic_medic']
    staff.append(dict(id='clinic_medic',name='医务人员',appearance_id='clinic_medic',role='medic',
                      room_id='clinic',position=[1690,690],patrol=[[1690,610],[1690,745],[1750,665]],
                      speed=36,wait_seconds=7,work_start=480,work_end=1200))
    room['resident_staff']=staff
    room['clinic_restoration_version']=1
    if room.get('clinic_architecture_version'):
        from register_clinic_architecture import apply_to_room
        apply_to_room(room,read(ROOT/'art/architecture/clinic_v1/manifest.json'))
    assert [f for f in room['fixtures'] if f.get('id') not in old_ids]==untouched
    if digest(room_path)!=original_hash:raise RuntimeError('Map changed during registration; rerun against latest saved version.')
    write(room_path,room)
    write(DOC/'registration.json',dict(schema=1,assets=list(by_key.values()),map_before_sha256=original_hash,
          map_after_sha256=digest(room_path),new_prop_ids=list(assets),resident='clinic_medic',mode=sources['mode']))
    print('Registered 8 new clinic props, 2 reused props, 2 floor variants, 1 resident; original art unchanged.')

if __name__=='__main__':main()
