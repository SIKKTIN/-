"""Install the approved repair court with original PNGs and native editable parts."""
import argparse
import copy
import hashlib
import json
import os
import shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'art/props/repair_courtyard_v1'
DOC = ROOT / 'docs/art/repair-courtyard-v1'
GEN = Path('C:/Users/gst20/.codex/generated_images/01a12de1-9940-7ee0-a361-bbf0f88d4681')
SOURCES = {
    'shed': GEN / 'exec-ecbb5bbc-5f65-42f5-858d-97b1bf18a225.png',
    'equipment': GEN / 'exec-c94e27bf-826d-49f2-984f-570c8765799e.png',
    'ground': GEN / 'exec-b63ec2f1-4662-4c5f-aae0-6b79a5fe2386.png',
}
PREFIX = 'repair-court-'
MANIFEST = 'res://art/props/repair_courtyard_v1/manifest.json'
SHADER = 'res://art/props/exercise_yard_v54/clean_cutout.gdshader'

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads(path.read_bytes())
def write(path, value, expected=None):
    data = (json.dumps(value, ensure_ascii=False, indent='\t')+'\n').encode('utf-8')
    if expected is not None: assert path.read_bytes() == expected, 'Concurrent edit: '+str(path)
    tmp = path.with_suffix(path.suffix+'.repair-writing')
    tmp.write_bytes(data)
    if expected is not None: assert path.read_bytes() == expected, 'Concurrent edit: '+str(path)
    os.replace(tmp, path)

def region(key, box, threshold=160):
    image = Image.open(ART/(key+'.png'))
    area = image.getchannel('A').crop(box).point(lambda v: 255 if v >= threshold else 0).getbbox()
    assert area
    x,y,r,b=area
    return [max(box[0],box[0]+x-2),max(box[1],box[1]+y-2),min(box[2],box[0]+r+2)-max(box[0],box[0]+x-2),min(box[3],box[1]+b+2)-max(box[1],box[1]+y-2)]

def register():
    ART.mkdir(parents=True, exist_ok=True); DOC.mkdir(parents=True, exist_ok=True)
    records=[]
    for key, source in SOURCES.items():
        target=ART/(key+'.png')
        shutil.copyfile(source,target)
        assert sha(target)==sha(source)
        records.append(dict(key=key,source=str(source),path=target.relative_to(ROOT).as_posix(),sha256=sha(target),size=list(Image.open(target).size)))
    shutil.copyfile(Path('C:/Users/gst20/AppData/Local/Temp/codex-clipboard-348269e5-7cf1-4455-ac69-1886e6a71fc4.png'), DOC/'approved-concept.png')
    assets=[]
    def prop(key,name,file,w,d,h=None,box=None,blocking=True,flat=False,exact=False):
        image=Image.open(ART/(file+'.png'))
        crop=list(box[:2])+[box[2]-box[0],box[3]-box[1]] if exact else region(file,box or (0,0,*image.size),12 if flat else 160)
        sw,sh=crop[2:]; h=h or w*sh/sw
        a=dict(id='repair_'+key+'_v1',name='维修小院 · '+name,texture='res://art/props/repair_courtyard_v1/'+file+'.png',texture_size=list(image.size),region=crop,
               world_size=[w,h],render_size=[w,h],footprint_world_size=[w,d],ground_rect=[0,sh*(1-d/h),sw,sh*d/h],elevation_world=h-d,
               render_mode='projected_prop',proportion_locked=False,blocking=blocking,interactive=False,shadow_baked=True,
               runtime_size_limit=1024 if file=='shed' else 512,source_kind='built-in-imagegen-original-png',sha256=sha(ART/(file+'.png')),editor_subcategory='furnishings')
        if not flat: a['alpha_core_shader']=SHADER
        assets.append(a)
        return a
    # Three separately sorted pieces retain original pixels and exact joins.
    scale=360/816
    north=prop('shed_north','上棚与维修湾背板','shed',756*scale,546*scale-40,546*scale,(148,28,904,574),exact=True)
    north['solid_parts']=[[.01,0,.05,.80],[.34,.73,.55,.025],[.90,.74,.06,.15]]
    spine=prop('shed_spine','左侧窄铁皮棚','shed',264*scale,226*scale,226*scale,(148,574,412,800),exact=True)
    spine['solid_parts']=[[.015,0,.08,1]]
    south=prop('shed_south','南侧机件存放棚与牌子','shed',360,557*scale-45,557*scale,(148,800,964,1357),exact=True)
    south['solid_parts']=[[.03,.86,.055,.14],[.46,.86,.055,.14],[.93,.86,.055,.14]]
    image=Image.open(ART/'equipment.png'); cw,ch=image.width//3,image.height//2
    specs=[('bench','木制台钳维修台',176,62,100),('welder','红色移动焊机',88,52,120),('pipes','钢管堆放架',138,66,103),
           ('compressor','旧风机机件',78,53,86),('crates','叠放旧木箱',64,44,126),('toolboard','工具挂板与盘管',120,3,48)]
    for i,(key,name,w,d,h) in enumerate(specs):
        col,row=i%3,i//3
        prop(key,name,'equipment',w,d,h,(col*cw,row*ch,(col+1)*cw,(row+1)*ch),blocking=key!='toolboard')
    for key,name,w,d,h,box in [
        ('oil','维修地面油渍',260,190,190,(0,0,950,625)),
        ('drain','方形排水格栅',54,54,54,(980,110,1420,550)),
        ('corner','褪色黄色定位角',68,68,68,(150,620,580,995)),
        ('weeds','墙根杂草',125,42,42,(650,670,1514,1039))]:
        prop(key,name,'ground',w,d,h,box,blocking=False,flat=True)
    tree=copy.deepcopy(next(a for a in read(ROOT/'art/props/exercise_yard_v54/manifest.json')['assets'] if a['id']=='yard_tree_round_v54'))
    tree.update(id='repair_tree_v1',name='维修小院 · 棚边小树',proportion_locked=False,world_size=[180,180],render_size=[180,180],footprint_world_size=[35,28],reused_from='yard_tree_round_v54')
    assets.append(tree)
    write(ART/'manifest.json',dict(schema=2,version='repair-courtyard-v1',assets=assets))
    write(DOC/'production-assets.json',dict(generator='built-in-imagegen',pngs=records,definition_ids=[a['id'] for a in assets],source_pixels='original PNGs unchanged; atlas regions and native world dimensions only'))
    catalog=ROOT/'scripts/presentation/prop_catalog.gd'
    raw=catalog.read_bytes();text=raw.decode('utf-8');newline='\r\n' if '\r\n' in text else '\n';line='\t"'+MANIFEST+'",'+newline
    if line not in text:
        marker=newline+']'+newline
        assert text.count(marker)>=1
        text=text.replace(marker,newline+line+']'+newline,1)
        tmp=catalog.with_suffix('.repair-writing');tmp.write_bytes(text.encode('utf-8'))
        assert catalog.read_bytes()==raw,'Concurrent catalog edit'
        os.replace(tmp,catalog)
    (DOC/'production-prompts.txt').write_text('Built-in imagegen with approved concept as reference.\n1. Transparent C-shaped rusty blue-gray corrugated shed structure with empty repair bay and storage frame; 维修小院 enamel sign.\n2. Transparent 3 x 2 sheet: vise bench, red welding cart, rusty pipe rack, old compressor, stacked crates, toolboard and coiled hose.\n3. Transparent ground kit: worn oil stain, square drain, faded yellow corner marking, low weeds.\nExact orthographic game camera and muted painted industrial palette; no baked surrounding map.\n',encoding='utf-8')
    return {a['id']:a for a in assets}

def restore(defs):
    path=ROOT/'data/rooms/r04.json';raw=path.read_bytes();before=json.loads(raw);after=copy.deepcopy(before)
    assert not before.get('repair_courtyard_version'),'Already installed; update owned objects narrowly.'
    removed={'energy-court-exterior-pallet','energy-court-exterior-jack','energy-court-exterior-parts-table','energy-court-exterior-parts-cabinet',
             'energy-court-parts-canopy','energy-court-service-bench','energy-court-shrub-14','energy-court-shrub-16','energy-court-shrub-17','energy-court-shrub-18',
             'energy-court-shrub-19','energy-court-ivy-7','energy-court-ivy-8','energy-court-ivy-9'}
    assert removed.issubset({f['id'] for f in before['fixtures']})
    after['fixtures']=[f for f in after['fixtures'] if f['id'] not in removed]
    removed_floor='energy-court-east-service-green'
    after['floor_regions']=[f for f in after['floor_regions'] if f['id']!=removed_floor]
    apron=next(f for f in after['floor_regions'] if f['id']=='energy-court-warehouse-apron')
    apron.update(asset_id='loading_floor_v1',manifest='res://art/environment/loading_yard_v1/manifest.json',tile_size=[240,240],tile_origin=[0,0])
    added=[]
    def place(key,asset,x,y,**extra):
        a=defs[asset];f=dict(id=PREFIX+key,asset_id=asset,rect=[x,y,*a['footprint_world_size']],render_size=a['render_size'],
                          blocks_movement=a.get('blocking',False),blocks_sight=False,exterior_shell=True,repair_courtyard_generated=True)
        if a.get('solid_parts'): f['solid_parts']=copy.deepcopy(a['solid_parts'])
        f.update(extra);after['fixtures'].append(f);added.append(f['id']);return f
    scale=360/816
    place('shed-north','repair_shed_north_v1',4330,3365,canopy_cover=[110,-40,210,115])
    place('shed-spine','repair_shed_spine_v1',4330,3325+546*scale,canopy_cover=[20,0,75,226*scale])
    place('shed-south','repair_shed_south_v1',4330,3325+772*scale+45,canopy_cover=[20,0,320,557*scale-45])
    place('bench','repair_bench_v1',4455,3567)
    place('toolboard','repair_toolboard_v1',4530,3535,draw_depth=3570)
    place('pipes','repair_pipes_v1',4360,3839)
    place('compressor','repair_compressor_v1',4516,3854)
    place('storage-crates','repair_crates_v1',4600,3835)
    place('welder','repair_welder_v1',4890,3858)
    place('corner-crates','repair_crates_v1',5002,3844)
    place('tree','repair_tree_v1',4305,3780)
    for key,asset,x,y,extra in [
        ('oil-large','repair_oil_v1',4610,3550,{}),('drain-main','repair_drain_v1',4665,3670,{}),('drain-west','repair_drain_v1',4290,3890,{}),
        ('mark-bench','repair_corner_v1',4605,3610,{}),('mark-welder','repair_corner_v1',4850,3840,{}),
        ('weeds-north-left','repair_weeds_v1',4308,3280,{}),('weeds-north-right','repair_weeds_v1',4940,3280,{}),
        ('weeds-south-left','repair_weeds_v1',4310,3925,{}),('weeds-south-shed','repair_weeds_v1',4470,3926,{}),
        ('weeds-south-right','repair_weeds_v1',4955,3926,{})]:
        place(key,asset,x,y,draw_depth=0,**extra)
    # Changes are confined to the owned apron props and its ground treatment.
    modified_floor='energy-court-warehouse-apron'
    assert {k:v for k,v in before.items() if k not in ['fixtures','floor_regions']}=={k:v for k,v in after.items() if k not in ['fixtures','floor_regions']}
    assert [f for f in before['fixtures'] if f['id'] not in removed]==[f for f in after['fixtures'] if not f.get('repair_courtyard_generated')]
    assert [f for f in before['floor_regions'] if f['id'] not in [removed_floor,modified_floor]]==[f for f in after['floor_regions'] if f['id']!=modified_floor]
    (DOC/'before-map.json').write_bytes(raw)
    write(path,after,expected=raw)
    write(DOC/'registration.json',dict(removed_fixture_ids=sorted(removed),added_fixture_ids=added,removed_floor_ids=[removed_floor],changed_floor_ids=[modified_floor],courtyard_rect=[4280,3260,840,712],physical_changes='shelter posts and independent equipment only; access, walls, routes and south road preserved',saved_map_sha256=sha(path)))
    write(DOC/'after-map.json',after)
    print(json.dumps(dict(assets=len(defs),fixtures=len(added),map_sha256=sha(path))))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--assets-only',action='store_true');args=parser.parse_args()
    defs=register()
    if not args.assets_only: restore(defs)
