"""Prepare original yard art and a guarded map patch for MCP MapDocument commit."""
import hashlib
import json
import math
import shutil
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs/art/exercise-yard-v02'
PREFIX='exercise-yard-v55-'
TERRAIN='res://art/environment/exercise_yard_v55/manifest.json'
AREA=[2140,220,1120,600]

def read(path):return json.loads(path.read_text(encoding='utf-8'))
def write(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(data,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def originals():
    source=read(DOC/'generated-assets.json');items={};assets=[]
    # Keep the previous corner PNG; reference the approved original refinement.
    refined=read(DOC/'corner-refinement-generation.json')
    for entry in source['assets']:
        if entry['key']=='curb_corner':
            entry.update(source=refined['source'],path=refined['path'],prompt=refined['prompt'])
    for entry in source['assets']:
        dest=ROOT/entry['path'];dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(entry['source'],dest)
        assert digest(dest)==digest(Path(entry['source']))
        im=Image.open(dest)
        entry['sha256']=digest(dest);entry['texture_size']=list(im.size)
        if entry['transparent']:
            assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
            # Inspect alpha only; preserve the PNG pixels and alpha as generated.
            x0,y0,x1,y1=im.getchannel('A').point(lambda a:255 if a>=128 else 0).getbbox()
            entry['region']=[max(0,x0-3),max(0,y0-3),min(im.width,x1+3)-max(0,x0-3),min(im.height,y1+3)-max(0,y0-3)]
        items[entry['key']]=entry
    def prop(key,identifier,name,width,depth=None,blocking=True,region=None):
        e=items[key];r=region or e['region'];scale=width/r[2];height=r[3]*scale
        depth=depth if depth is not None else height-20
        a=dict(id=identifier,name=name,texture='res://'+e['path'],texture_size=e['texture_size'],region=r,
               world_size=[width,height],render_size=[width,height],ground_rect=[0,r[3]-depth/scale,r[2],depth/scale],
               footprint_world_size=[width,depth],elevation_world=height-depth,proportion_locked=True,
               render_mode='projected_prop',blocking=blocking,interactive=False,shadow_baked=True,
               editor_subcategory='furnishings',runtime_size_limit=512,source_kind='built-in-imagegen-original-png',
               sha256=e['sha256'],alpha_core_shader='res://art/props/exercise_yard_v54/clean_cutout.gdshader')
        assert depth>0 and depth<=height
        assets.append(a);return a
    v=items['curb_v']['region']
    prop('curb_v','yard_curb_v_v55','放风院水泥矮栏 纵向',v[2]*220/v[3],200)
    prop('curb_h','yard_curb_h_v55','放风院水泥矮栏 横向',200,12)
    corner=prop('curb_corner','yard_curb_corner_sw_v55','放风院水泥矮栏 西南转角',96)
    corner['solid_parts']=[[0,0,.18,1],[0,.80,1,.20]]
    prop('bucket','yard_metal_bucket_v55','放风院金属水桶',30,18)
    prop('shrub_a','yard_ground_shrubs_a_v55','放风院地栽灌木组 A',170,30,False)
    prop('shrub_b','yard_ground_shrubs_b_v55','放风院地栽灌木组 B',140,26,False)
    def short_v(depth):
        width=assets[0]['world_size'][0];r=v.copy();scale=width/r[2]
        pixels=round((depth+20)/scale);r[1]+=r[3]-pixels;r[3]=pixels
        return prop('curb_v','yard_curb_v_short_v55','放风院水泥矮栏 纵向短段',width,depth,region=r)
    short_v(AREA[3]-corner['footprint_world_size'][1]-400)
    for width in [164,60]:
        r=items['curb_h']['region'].copy();r[2]=round(r[2]*width/200)
        prop('curb_h',f'yard_curb_h_{width}_v55',f'放风院水泥矮栏 横向{width}',width,12,region=r)
    write(ROOT/'art/props/exercise_yard_v55/manifest.json',dict(schema=2,version='exercise-yard-v55',assets=assets))
    terrain=read(ROOT/'art/environment/exercise_yard_v54/manifest.json')
    terrain['version']='exercise-yard-v55'
    for key in ['floor_a','floor_b']:
        e=items[key]
        terrain['assets'].append(dict(id='yard_concrete_'+key[-1]+'_v55',name='放风院旧水泥 '+key[-1].upper(),
                                     texture='res://'+e['path'],texture_size=e['texture_size'],runtime_size_limit=1024,
                                     sha256=e['sha256'],source_kind='built-in-imagegen-original-png'))
    write(ROOT/'art/environment/exercise_yard_v55/manifest.json',terrain)
    write(DOC/'asset-registration.json',dict(mode=source['mode'],assets=list(items.values())))
    return {a['id']:a for a in assets}

def apply(data,assets):
    inherited={}
    for file in ['art/props/exercise_yard_v54/manifest.json','art/props/campus_v47/manifest.json','art/props/factory_v44/manifest.json','art/props/manifest-v03.json']:
        for a in read(ROOT/file)['assets']:inherited[a['id']]=a
    # New art touches only known yard authored IDs, not every object in this rectangle.
    def yard_id(identifier):return identifier.startswith(('exercise-yard-v54-',PREFIX,'campus-yard-seat-','campus-yard-planter-')) or identifier in ['campus-yard-hoop','campus-yard-lamp-0']
    data['fixtures']=[f for f in data['fixtures'] if not yard_id(f.get('id',''))]
    data['ground_details']=[f for f in data['ground_details'] if not f.get('id','').startswith(('exercise-yard-v54-',PREFIX))]
    data['terrain_patches']=[f for f in data['terrain_patches'] if not f.get('id','').startswith(('exercise-yard-v54-',PREFIX))]
    data['floor_regions']=[f for f in data['floor_regions'] if f.get('id')!='campus-yard' and not f.get('id','').startswith(PREFIX)]
    data['floor_regions'].append(dict(id=PREFIX+'west-paving',asset_id='loading_floor_v46',manifest=TERRAIN,rect=[2060,220,80,600],tile_size=[320,320]))
    data['floor_regions'].append(dict(id='campus-yard',asset_id='yard_concrete_a_v55',manifest=TERRAIN,rect=AREA.copy(),tile_size=[640,640],edge_feather=0))
    data['floor_regions'].append(dict(id=PREFIX+'wear-0',asset_id='yard_concrete_b_v55',manifest=TERRAIN,rect=[2260,480,150,120],tile_size=[640,640],edge_feather=25))
    def fixture(id,asset_id,x,y,size=None,**extra):
        a=assets.get(asset_id,inherited.get(asset_id,{}));dims=size or a['footprint_world_size']
        f=dict(id=PREFIX+id,asset_id=asset_id,rect=[x,y,*dims],blocks_movement=a.get('blocking',True),blocks_sight=False)
        for k in ['solid_parts','canopy_cover']:
            if k in a:f[k]=a[k]
        f.update(extra);data['fixtures'].append(f);return f
    fixture('bars','pullup_bars_v54',2310,540)
    fixture('hoop','basketball_hoop_v47',2770,400,[120,45])
    fixture('shelter-back','yard_shelter_back_v54',2930,410)
    fixture('shelter-front','yard_shelter_front_v54',2930,485)
    fixture('shelter-roof','yard_shelter_roof_v54',2920,280,draw_depth=500)
    for i,(x,y) in enumerate([(2420,320),(2600,320),(2510,740),(2770,740),(2980,440)]):
        fixture('bench-'+str(i),'park_bench_v47',x,y,[160,54.7367])
    fixture('bench-5','yard_bench_vertical_v54',3160,520)
    fixture('shelter-box','heavy_crate_handpaint_v03',2940,444,[40,34.5])
    fixture('drums','oil_drums_v44',2330,734,[80,50])
    fixture('bucket','yard_metal_bucket_v55',2418,765)
    for i,(asset,x,y) in enumerate([('yard_tree_round_v54',2260,350),('yard_tree_square_v54',2350,305),('yard_tree_round_v54',3200,340)]):
        w,h=inherited[asset]['footprint_world_size'];fixture('tree-'+str(i),asset,x-w/2,y-h)
    for i,(asset,x,y) in enumerate([
        ('yard_ground_shrubs_b_v55',2170,340),('yard_ground_shrubs_a_v55',2290,775),
        ('yard_ground_shrubs_a_v55',3070,784),('yard_ground_shrubs_b_v55',3100,396),
        ('yard_ground_shrubs_b_v55',2400,268),('yard_ground_shrubs_b_v55',2820,268)]):
        fixture('shrubs-'+str(i),asset,x,y,blocks_movement=False)
    for i,y in enumerate([220,420]):fixture('west-curb-'+str(i),'yard_curb_v_v55',2140,y)
    short=assets['yard_curb_v_short_v55']['footprint_world_size'][1]
    fixture('west-curb-2','yard_curb_v_short_v55',2140,620)
    fixture('west-corner','yard_curb_corner_sw_v55',2140,620+short)
    for id,asset,x in [('south-0','yard_curb_h_v55',2236),('south-1','yard_curb_h_164_v55',2436),
                       ('south-2','yard_curb_h_v55',2800),('south-3','yard_curb_h_v55',3000),
                       ('south-4','yard_curb_h_60_v55',3200)]:
        fixture(id,asset,x,808)
    # Main-road entry stays wide between upper and lower low borders.
    fixture('east-curb-0','yard_curb_v_v55',3243,220)
    fixture('east-curb-1','yard_curb_v_short_v55',3243,820-short)
    def line(a,b,index,width=3,opacity=.65):
        data['ground_details'].append(dict(id=PREFIX+'court-'+str(index),kind='line',color='#f3ead4',opacity=opacity,width=width,**{'from':a,'to':b}))
    paths=[[[2630,450],[3030,450],[3030,730],[2630,730],[2630,450]],[[2770,450],[2770,570],[2890,570],[2890,450]]]
    for radius,cy in [(60,570),(184,450)]:
        paths.append([[2830+radius*math.cos(math.pi*j/24),cy+radius*math.sin(math.pi*j/24)] for j in range(25)])
    n=0
    for path in paths:
        for a,b in zip(path,path[1:]):
            distance=math.dist(a,b);steps=max(1,math.ceil(distance/32))
            for j in range(steps):
                # Sparse short wear breaks; do not replace the line with many update nodes.
                t=j/steps;u=(j+1)/steps
                if n%11==7:u=max(t,u-.06)
                line([a[k]+(b[k]-a[k])*t for k in [0,1]],[a[k]+(b[k]-a[k])*u for k in [0,1]],n,opacity=.58 if n%7==0 else .72);n+=1
    data['ground_details'].append(dict(id=PREFIX+'shelter-shadow',kind='surface',rect=[2930,400,260,100],color='#414d42',opacity=.12))
    for i,rect in enumerate([[2180,260,220,100],[2240,705,240,90],[3070,735,170,70],[3070,325,150,80]]):
        data['terrain_patches'].append(dict(id=PREFIX+'dust-'+str(i),asset_id='soil_island_v46',rect=rect,opacity=.18,clip_rect=AREA.copy(),tint='#baa587'))
    for zone in data['zones']:
        if zone['id']=='yard':zone.update(rect=AREA.copy(),hide_label=True)
    for point in data['routine_points']['free']:
        if point==[2500,970]:point[:]=[2460,620]
        elif point==[2920,950]:point[:]=[2860,655]
    for lamp in data['lamps']:
        if lamp['position']==[2730,860]:lamp.update(position=[2800,550],draw_fixture=False)
    data['concept_plan']['exercise_yard_revision']=dict(version='v55',reference='docs/art/exercise-yard-v02/concept-v3.png',
          yard_rect=AREA.copy(),court_rect=[2630,450,400,280],open_boundary=True,west_paving=[2060,220,80,600],
          east_opening=[420,820-short],south_opening=[2600,2800])

def main():
    assets=originals();path=ROOT/'data/rooms/r04.json';before=digest(path);data=read(path)
    shutil.copyfile(path,DOC/'last-input-map.json')
    initial=DOC/'baseline/r04.json'
    if not initial.exists():initial.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(path,initial)
    apply(data,assets)
    if digest(path)!=before:raise RuntimeError('Map changed while preparing; rerun using latest disk version.')
    write(DOC/'prepared-map.json',data)
    write(DOC/'assembly.json',dict(before_sha256=before,prepared_sha256=digest(DOC/'prepared-map.json'),
          area=AREA,fixture_prefix=PREFIX,commit_mode='MCP MapDocument transaction',new_prop_ids=list(assets)))
    print('Prepared eight original PNGs and compact yard; main map is unchanged until guarded MCP commit.')

if __name__=='__main__':main()
