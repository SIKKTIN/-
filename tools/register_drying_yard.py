"""Register the approved drying-yard sprites and decorate the latest R04.

Imagegen PNGs remain byte-identical. Atlas cropping, world scale and ground
anchors are metadata; unrelated map objects and the user's backup are retained.
"""
from copy import deepcopy
from pathlib import Path
import argparse, hashlib, json, shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT/'docs/art/drying-yard-v1'
ART = ROOT/'art/props/drying_yard_v1'
GEN = Path('C:/Users/gst20/.codex/generated_images/01a12f0d-4fc4-7dd2-b6a0-d189a674ef6e')
SHADER = 'res://art/props/exercise_yard_v54/clean_cutout.gdshader'
SOURCES = {
    'clotheslines': 'exec-ed32cda4-089f-44c4-a641-b4d0bb271b6d.png',
    'linen-cart': 'exec-06262c07-aa9b-4772-9c45-4eb11566e7a8.png',
    'flowerbed': 'exec-bca8513b-d83f-44fb-9b74-1c89aefce25c.png',
    'yard-sign': 'exec-794c1556-3d44-4a72-b787-dc2ba7014583.png',
    'square-flowerbed': 'exec-8e59b960-0613-4935-aec0-ae6153ec9495.png',
}
def read(p): return json.loads(p.read_bytes())
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p, data):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, ensure_ascii=False, indent='\t')+'\n', encoding='utf-8')
def region(im, box=None):
    # Measure alpha bounds only; no source pixels are modified or re-exported.
    alpha = im.getchannel('A')
    if box: alpha = alpha.crop(box)
    x,y,right,bottom = alpha.point(lambda a: 255 if a >= 180 else 0).getbbox()
    ox,oy = (box[0],box[1]) if box else (0,0)
    x=max(0,x+ox-3); y=max(0,y+oy-3)
    return [x,y,min(im.width,right+ox+3)-x,min(im.height,bottom+oy+3)-y]
def definition(identifier, name, source, crop, width, depth, **extra):
    image = Image.open(ART/(source+'.png'))
    x,y,w,h = crop
    scale = width/w
    height = h*scale
    assert height>=depth
    return dict(id=identifier,name='晾晒区 · '+name,texture='res://art/props/drying_yard_v1/'+source+'.png',
        texture_size=list(image.size),region=crop,world_size=[width,height],render_size=[width,height],
        footprint_world_size=[width,depth],ground_rect=[0,h-depth/scale,w,depth/scale],
        elevation_world=height-depth,render_mode='projected_prop',blocking=True,interactive=False,
        shadow_baked=False,proportion_locked=True,editor_subcategory='furnishings',runtime_size_limit=512,
        alpha_core_shader=SHADER,source_kind='built-in-imagegen-original-png',sha256=sha(ART/(source+'.png')),**extra)
def reuse(source, identifier, name, width, blocking=True):
    # Search only registered production sets, keeping source regions intact.
    paths=['art/props/campus_v47/manifest.json','art/props/exercise_yard_v55/manifest.json']
    a=next(deepcopy(a) for p in paths for a in read(ROOT/p)['assets'] if a['id']==source)
    w,h=a['region'][2:];scale=width/w;ground=a['ground_rect'];depth=ground[3]*scale
    a.update(id=identifier,name='晾晒区 · '+name,world_size=[width,h*scale],render_size=[width,h*scale],
        footprint_world_size=[ground[2]*scale,depth],elevation_world=h*scale-depth,
        blocking=blocking,proportion_locked=True,editor_subcategory='furnishings',runtime_size_limit=512,reused_from=source)
    a.pop('editor_icon',None)
    return a
def assets():
    ART.mkdir(parents=True,exist_ok=True)
    records=[]
    for key,file in SOURCES.items():
        src=GEN/file;dst=ART/(key+'.png')
        shutil.copyfile(src,dst)
        assert sha(src)==sha(dst)
        im=Image.open(dst)
        assert im.mode=='RGBA' and im.getchannel('A').getextrema()==(0,255)
        records.append(dict(key=key,source=str(src),path=dst.relative_to(ROOT).as_posix(),sha256=sha(dst),size=list(im.size)))
    rack=Image.open(ART/'clotheslines.png');split=rack.height//2
    definitions=[
        definition('drying_clothesline_sheets_v1','床单晾衣架','clotheslines',region(rack,(0,0,rack.width,split)),330,16),
        definition('drying_clothesline_clothes_v1','衣物晾衣架','clotheslines',region(rack,(0,split,rack.width,rack.height)),330,16),
        definition('drying_linen_cart_v1','蓝色布草车','linen-cart',region(Image.open(ART/'linen-cart.png')),95,54),
        definition('drying_flowerbed_long_v1','横向低花坛','flowerbed',region(Image.open(ART/'flowerbed.png')),230,46),
        definition('drying_flowerbed_square_v1','入口方花坛','square-flowerbed',region(Image.open(ART/'square-flowerbed.png')),90,75),
        definition('drying_area_sign_v1','晾晒区搪瓷牌','yard-sign',region(Image.open(ART/'yard-sign.png')),165,14),
        reuse('park_bench_v47','drying_bench_v1','休息木长椅',220),
        reuse('yard_lamp_v47','drying_lamp_v1','园区矮路灯',46),
        reuse('yard_ground_shrubs_a_v55','drying_shrubs_a_v1','地栽灌木 A',160,False),
        reuse('yard_ground_shrubs_b_v55','drying_shrubs_b_v1','地栽灌木 B',140,False),
    ]
    for a in definitions:
        if 'clothesline' in a['id']:
            a['solid_parts']=[[0,0,.068,1],[.932,0,.068,1]]
            a['collision_note']='Only post bases block feet; fabric is raised above the ground.'
        elif a['id']=='drying_area_sign_v1': a['solid_parts']=[[.015,0,.13,1],[.86,0,.13,1]]
    write(ART/'manifest.json',dict(schema=2,version='drying-yard-v1',assets=definitions))
    write(DOC/'production-assets.json',dict(mode='built-in imagegen',pngs=records,definition_ids=[a['id'] for a in definitions],
        asset_plan=dict(new_png_count=5,new_sprite_definitions=6,reused_prop_definitions=4,
                        palette='米白布草、褪色蓝布、旧铁杆、奶油色石材、低矮绿植',
                        layout='食堂南侧左右草坪，左两排右一排；中央320单位道路连接下方横路',
                        gameplay='环境布置；沿用已有食堂和洗衣室门禁，晾晒区露天可见')))
    catalog=ROOT/'scripts/presentation/prop_catalog.gd';text=catalog.read_text(encoding='utf-8')
    line='\t"res://art/props/drying_yard_v1/manifest.json",\n'
    if line not in text:
        anchor='\t"res://art/props/south_laundry_bath_v1/manifest.json",\n'
        assert text.count(anchor)==1
        catalog.write_text(text.replace(anchor,anchor+line),encoding='utf-8')
    print('Registered 10 outdoor definitions from 5 original PNGs and 4 reused assets.')
def prepare():
    path=ROOT/'data/rooms/r04.json';raw=path.read_bytes();room=json.loads(raw)
    if any(str(v['id']).startswith('drying-yard-') for v in room['fixtures']):
        # Refine only our own layout on the latest map; never replay an older
        # whole-map snapshot over another editor's changes.
        if not (DOC/'initial-before-map.json').exists():
            shutil.copyfile(DOC/'before-map.json',DOC/'initial-before-map.json')
            shutil.copyfile(DOC/'after-map.json',DOC/'initial-after-map.json')
        (DOC/'refinement-input-map.json').write_bytes(raw)
        room['fixtures']=[v for v in room['fixtures'] if not str(v['id']).startswith('drying-yard-')]
        room['lamps']=[v for v in room['lamps'] if not str(v.get('id','')).startswith('drying-yard-')]
        room['floor_regions']=[v for v in room['floor_regions'] if not str(v['id']).startswith('drying-yard-')]
        next(v for v in room['floor_regions'] if v['id']=='canteen-laundry-connection')['rect']=[1300,2520,320,520]
        room['concept_plan'].pop('drying_yard_revision',None)
    before=deepcopy(room)
    assert next(v['rect'] for v in room['fixtures'] if v['id']=='canteen-south-door-visual')==[1460,2500,160,20]
    defs={a['id']:a for a in read(ART/'manifest.json')['assets']}
    fixtures=[]
    def put(key,asset,x,y,**extra):
        a=defs[asset];w,h=a['footprint_world_size']
        f=dict(id='drying-yard-'+key,asset_id=asset,rect=[x,y,w,h],blocks_movement=a['blocking'],blocks_sight=False,
               exterior_shell=True,drying_yard_generated=True,**extra)
        if a.get('solid_parts'):f['solid_parts']=deepcopy(a['solid_parts'])
        fixtures.append(f)
    put('west-rack-sheets','drying_clothesline_sheets_v1',940,2820)
    put('west-rack-clothes','drying_clothesline_clothes_v1',940,2990)
    put('east-rack-sheets','drying_clothesline_sheets_v1',1670,2820)
    put('linen-cart','drying_linen_cart_v1',1800,3045)
    put('west-bench','drying_bench_v1',950,2600)
    put('east-bench','drying_bench_v1',1800,2600)
    put('west-entry-bed','drying_flowerbed_square_v1',1200,2600)
    put('east-entry-bed','drying_flowerbed_square_v1',1650,2600)
    put('west-bottom-bed','drying_flowerbed_long_v1',1055,3125)
    put('east-bottom-bed','drying_flowerbed_long_v1',1660,3125)
    put('sign','drying_area_sign_v1',960,3080)
    put('west-lamp','drying_lamp_v1',910,2745)
    put('east-lamp','drying_lamp_v1',2060,2745)
    for key,asset,x,y in [
        ('nw-green','drying_shrubs_a_v1',905,2580),
        ('ne-green','drying_shrubs_b_v1',1980,2615),
        ('west-green-upper','drying_shrubs_b_v1',890,2760),
        ('west-green','drying_shrubs_b_v1',900,2900),
        ('west-green-lower','drying_shrubs_b_v1',890,3030),
        ('sw-green','drying_shrubs_a_v1',905,3150),
        ('east-green-upper','drying_shrubs_a_v1',1960,2760),
        ('east-green-1','drying_shrubs_a_v1',1960,2900),
        ('east-green-2','drying_shrubs_b_v1',1980,3020),
        ('se-green','drying_shrubs_a_v1',1950,3150),
    ]:put(key,asset,x,y)
    room['fixtures'].extend(fixtures)
    floor=next(v for v in room['floor_regions'] if v['id']=='canteen-laundry-connection')
    assert floor['rect']==[1300,2520,320,520], 'Re-evaluate changed courtyard paving.'
    floor['rect']=[1300,2520,320,660]
    room['floor_regions'].extend([
        dict(id='drying-yard-west-grass',asset_id='grass_base_v46',rect=[880,2520,420,660],tile_size=[470,470],tile_origin=[0,0],natural_ground=True),
        dict(id='drying-yard-east-grass',asset_id='grass_base_v46',rect=[1620,2520,500,660],tile_size=[470,470],tile_origin=[0,0],natural_ground=True)])
    # Explicit light props own the visual; existing light pools elsewhere stay.
    room['lamps'].extend([dict(id='drying-yard-west-light',position=[933,2750],radius=210,color='#ffe3b7',energy=.45,draw_fixture=False),
                         dict(id='drying-yard-east-light',position=[2083,2750],radius=210,color='#ffe3b7',energy=.45,draw_fixture=False)])
    room['concept_plan']['drying_yard_revision']=dict(version=1,reference='docs/art/drying-yard-v1/approved-concept.png',
        area_rect=[880,2520,1240,660],central_path=[1300,2520,320,660],clothesline_count=3,open_air=True)
    write(DOC/'before-map.json',before);write(DOC/'candidate-map.json',room)
    write(DOC/'map-registration.json',dict(input_sha256=hashlib.sha256(raw).hexdigest(),new_fixture_ids=[f['id'] for f in fixtures],
        changed_floor_ids=['canteen-laundry-connection','drying-yard-west-grass','drying-yard-east-grass'],new_lamp_ids=['drying-yard-west-light','drying-yard-east-light'],
        permissions_preserved=True,rooms_and_roofs_preserved=True,wall_geometry_preserved=True))
    print('Prepared drying yard candidate on latest map; saved map unchanged.')
def apply():
    path=ROOT/'data/rooms/r04.json';record=read(DOC/'map-registration.json')
    assert sha(path)==record['input_sha256'], 'Saved map changed; prepare again from latest instead of overwriting.'
    raw=path.read_bytes();candidate=(DOC/'candidate-map.json').read_bytes()
    (DOC/'map-before-save.json').write_bytes(raw)
    staged=path.with_name('r04.drying-yard-v1.writing')
    staged.write_bytes(candidate)
    assert path.read_bytes()==raw
    staged.replace(path)
    (DOC/'after-map.json').write_bytes(candidate)
    record.update(output_sha256=sha(path),saved_path=str(path))
    write(DOC/'map-registration.json',record)
    print('Applied drying yard to R04; all unrelated map data preserved.')
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('command',choices=['assets','prepare','apply']);args=parser.parse_args()
    globals()[args.command]()
