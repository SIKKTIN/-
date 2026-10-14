"""Register untouched imagegen sources and assemble the approved exercise yard.

Only this yard's authored objects are replaced; all other map data is retained.
Run from the project root. PNG pixels are never edited by this tool.
"""
import hashlib
import json
import math
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PREFIX = 'exercise-yard-v54-'


def read(path):
    return json.loads((ROOT / path).read_text(encoding='utf-8'))


def write(path, data):
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(data, ensure_ascii=False, indent='\t')+'\n', encoding='utf-8')


def asset(id, name, file, region, ground, width, **extra):
    path = ROOT / 'art/props/exercise_yard_v54' / file
    with Image.open(path) as image:
        dimensions = list(image.size)
    scale = width / region[2]
    spec = dict(id=id, name=name, texture='res://'+path.relative_to(ROOT).as_posix(),
                texture_size=dimensions, region=region, ground_rect=ground,
                world_size=[width, round(region[3]*scale, 4)],
                render_size=[width, round(region[3]*scale, 4)],
                footprint_world_size=[round(ground[2]*scale, 4), round(ground[3]*scale, 4)],
                elevation_world=round((region[3]-ground[3])*scale, 4),
                render_mode='projected_prop', proportion_locked=True,
                blocking=True, interactive=False, shadow_baked=False,
                authoring_set='exercise-yard-v54', editor_subcategory='furnishings',
                runtime_size_limit=512, source_kind='built-in-imagegen-original-png',
                sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                alpha_core_shader='res://art/props/exercise_yard_v54/clean_cutout.gdshader')
    spec.update(extra)
    return spec


def main():
    assets = [
        asset('pullup_bars_v54','放风院双单杠','bars.png',[200,287,1085,469],[0,401,1085,64],210,
              solid_parts=[[0,0,.13,1],[.435,0,.13,1],[.87,0,.13,1]]),
        asset('yard_shelter_roof_v54','遮雨棚 · 棚顶','shelter-layers.png',[228,73,1081,374],[0,0,1081,374],280,
              blocking=False,shadow_baked=True,canopy_cover=[10,120,260,90]),
        asset('yard_shelter_back_v54','遮雨棚 · 后框','shelter-layers.png',[55,536,700,397],[0,368,700,25],260,
              solid_parts=[[0,0,.09,1],[.91,0,.09,1]]),
        asset('yard_shelter_front_v54','遮雨棚 · 前柱','shelter-layers.png',[813,639,670,294],[0,266,670,24],260,
              solid_parts=[[0,0,.09,1],[.91,0,.09,1]]),
        asset('yard_tree_round_v54','放风院水泥圆盆树','tree-round.png',[142,57,1024,1016],[366,820,292,180],140),
        asset('yard_tree_square_v54','放风院水泥方盆树','tree-square.png',[308,191,677,817],[219,633,239,168],100),
        asset('yard_bench_vertical_v54','放风院纵向长椅','bench-vertical.png',[363,210,281,1157],[12,100,257,1040],160*281/1157),
    ]
    write('art/props/exercise_yard_v54/manifest.json',dict(schema=2,version='exercise-yard-v54',assets=assets))
    by_id = {x['id']:x for x in assets}
    terrain = read('art/environment/southwest_v52/manifest.json')
    path = ROOT/'art/environment/exercise_yard_v54/concrete.png'
    with Image.open(path) as image: dimensions=list(image.size)
    terrain['version']='exercise-yard-v54'
    terrain['inherited_from']='res://art/environment/southwest_v52/manifest.json'
    terrain['assets'].append(dict(id='yard_concrete_v54',name='放风院旧水泥地面',texture='res://art/environment/exercise_yard_v54/concrete.png',texture_size=dimensions,runtime_size_limit=1024,source_kind='built-in-imagegen-original-png',sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    write('art/environment/exercise_yard_v54/manifest.json',terrain)
    data=read('data/rooms/r04.json')
    removed=[]
    remap={}
    walls=[]
    for index, rect in enumerate(data['walls']):
        x,y,w,h=rect
        if x>=2300 and y>=240 and x+w<=3200 and y+h<=1140:
            removed.append(index)
        else:
            remap[index]=len(walls)
            walls.append(rect)
    assert len(removed) in (0,58), f'Unexpected yard wall selection: {len(removed)}'
    if removed:
        data['walls']=walls
        surfaces=[]
        for surface in data['architecture']['wall_surfaces']:
            old=int(surface['wall_index'])
            if old in remap:
                surface['wall_index']=remap[old]
                surfaces.append(surface)
        data['architecture']['wall_surfaces']=surfaces
    for orientation in ['horizontal','vertical']:
        data['concept_plan'][orientation]=[x for x in data['concept_plan'][orientation] if x['id'] not in ['yard-north','yard-south','yard-west','yard-east']]
    data['fixtures']=[f for f in data['fixtures'] if not f['id'].startswith((PREFIX,'campus-yard-seat-','campus-yard-planter-')) and f['id'] not in ['campus-yard-south','campus-yard-west','campus-yard-east']]
    for floor in data['floor_regions']:
        if floor['id']=='campus-yard':
            floor.update(asset_id='yard_concrete_v54',rect=[2300,220,900,960],tile_size=[960,960],edge_feather=56)
    # A local manifest override avoids replacing another region's floor definitions.
    for floor in data['floor_regions']:
        if floor['id']=='campus-yard':floor['manifest']='res://art/environment/exercise_yard_v54/manifest.json'
    details=[]
    old_court=0
    for mark in data['ground_details']:
        if str(mark.get('id','')).startswith(PREFIX):continue
        points=[mark.get('from',[]),mark.get('to',[])]
        if mark.get('color')=='#dad7b7' and all(len(p)==2 and 2300<=p[0]<=3200 and 300<=p[1]<=1140 for p in points):
            old_court+=1
        else:details.append(mark)
    data['ground_details']=details
    data['terrain_patches']=[x for x in data['terrain_patches'] if not str(x.get('id','')).startswith(PREFIX)]

    def fixture(id, asset_id, x, y, size=None, **extra):
        spec=by_id.get(asset_id,{})
        size=size or spec['footprint_world_size']
        item=dict(id=PREFIX+id,asset_id=asset_id,rect=[x,y,*size],blocks_movement=spec.get('blocking',True),blocks_sight=False)
        for key in ['solid_parts','canopy_cover']:
            if key in spec:item[key]=spec[key]
        item.update(extra)
        data['fixtures'].append(item)
        return item

    fixture('bars','pullup_bars_v54',2395,640)
    fixture('shelter-back','yard_shelter_back_v54',2948,465)
    fixture('shelter-front','yard_shelter_front_v54',2948,515)
    fixture('shelter-roof','yard_shelter_roof_v54',2938,325,draw_depth=525)
    for index,(x,y) in enumerate([(2600,385),(2790,385),(2640,1060),(2860,1060)]):
        fixture('bench-'+str(index),'park_bench_v47',x,y,[160,54.7367])
    fixture('bench-4','yard_bench_vertical_v54',3130,735)
    for index,(id,x,y) in enumerate([
        ('yard_tree_round_v54',2390,380),('yard_tree_square_v54',2490,365),
        ('yard_tree_round_v54',2910,360),('yard_tree_round_v54',2420,1050),
        ('yard_tree_square_v54',2580,1100),('yard_tree_round_v54',3170,1100),
        ('yard_tree_square_v54',3220,585)]):
        w,h=by_id[id]['footprint_world_size']
        fixture('tree-'+str(index),id,x-w/2,y-h,[w,h])
    fixture('drums','oil_drums_v44',2340,885,[95,59.375])
    fixture('shelter-box','heavy_crate_handpaint_v03',2990,475,[59.1,50.98])
    fixture('pail','folded_linen_v44',2360,805,[50,25],blocks_movement=False)
    # Planting pockets bridge the yard and the main road. Their middle gap
    # stays open; only tree pots collide, the low foliage is decorative.
    for index,(id,x,y) in enumerate([
        ('yard_tree_round_v54',3240,415),
        ('yard_tree_square_v54',3210,935),
        ('yard_tree_round_v54',3250,1060)]):
        w,h=by_id[id]['footprint_world_size']
        fixture('edge-tree-'+str(index),id,x-w/2,y-h,[w,h])
    for index,(x,y,width) in enumerate([
        (3165,382,105),(3200,558,90),(3180,918,110),
        (3170,1045,100),(3110,1110,95),
        (2460,275,100),(2860,250,110),(3160,325,80)]):
        fixture('edge-shrub-'+str(index),'hedge_v44',x,y,[width,width*237.346153846/561],blocks_movement=False)
    for f in data['fixtures']:
        if f['id']=='campus-yard-hoop':f['rect']=[2800,560,120,45]
    def line(a,b,width=3):
        data['ground_details'].append(dict(id=PREFIX+'court-'+str(len(data['ground_details'])),kind='line',color='#f5ecd2',opacity=.72,width=width,**{'from':a,'to':b}))
    for a,b in [([2630,605],[3070,605]),([3070,605],[3070,955]),([3070,955],[2630,955]),([2630,955],[2630,605]),([2790,605],[2790,725]),([2790,725],[2930,725]),([2930,725],[2930,605])]:line(a,b)
    for i in range(20):
        a=math.pi*i/20
        b=math.pi*(i+1)/20
        line([2860+70*math.cos(a),725+70*math.sin(a)],[2860+70*math.cos(b),725+70*math.sin(b)])
    data['ground_details'].append(dict(id=PREFIX+'canopy-shadow',kind='surface',rect=[2948,445,260,90],color='#414d42',opacity=.14))
    # Low shrubs and dusty soft patches soften the concrete boundary without blocking paths.
    for index,(x,y,w,h) in enumerate([(2290,245,120,95),(2420,225,170,80),(2860,235,120,80),(3110,300,120,100),(2290,1040,140,100),(3040,1080,180,90)]):
        data['terrain_patches'].append(dict(id=PREFIX+'shrub-'+str(index),asset_id='shrub_single_'+str(index%3)+'_v46',rect=[x,y,w,h],opacity=.9))
    for index,rect in enumerate([[2290,360,140,450],[3050,1000,160,150],[2290,1010,180,150],[2380,215,420,95]]):
        data['terrain_patches'].append(dict(id=PREFIX+'dust-'+str(index),asset_id='soil_island_v46',rect=rect,opacity=.22))
    # Short overlapping soil patches break the straight material seam without
    # stretching a horizontal decal into an artificial vertical stripe.
    for index,rect in enumerate([
        [3140,335,145,90],[3170,430,145,90],[3145,510,150,95],
        [3140,885,160,100],[3160,965,160,100],[3180,1040,145,90],
        [3060,1095,170,100],[2970,1130,175,105],
        [2400,230,160,100],[2820,225,170,105]]):
        data['terrain_patches'].append(dict(id=PREFIX+'edge-soil-'+str(index),asset_id='soil_island_v46',rect=rect,opacity=.24,tint='#b4a083'))
    for index,rect in enumerate([[3110,380,180,75],[3150,940,180,75],[3120,1060,200,80]]):
        data['terrain_patches'].append(dict(id=PREFIX+'edge-grass-'+str(index),asset_id='grass_band_v46',rect=rect,opacity=.4,tint='#bdc4a3'))
    data['concept_plan']['exercise_yard_revision']={'version':'v54','open_boundary':True,'court_rect':[2630,605,440,350],'reference':'docs/art/exercise-yard-v01/reference-closeup.png','edge_transition':'planting-pockets-v140','main_road_open_gap':[620,730]}
    # The outdoor lamp already has a painted post. Retain its light coverage
    # while hiding the legacy fixture glyph previously floating on the court.
    for lamp in data.get('lamps',[]):
        if lamp['position']==[2730,860]:lamp['draw_fixture']=False
    write('data/rooms/r04.json',data)
    baseline=read('docs/dev/p139/r04-before.json')
    original_indices=[i for i,(x,y,w,h) in enumerate(baseline['walls']) if x>=2300 and y>=240 and x+w<=3200 and y+h<=1140]
    write('docs/dev/p139/assembly.json',dict(removed_wall_indices=original_indices,removed_wall_count=len(original_indices),new_fixture_count=sum(f['id'].startswith(PREFIX) for f in data['fixtures']),asset_ids=list(by_id),court_area_fraction=440*350/(900*800),floor_manifest='res://art/environment/exercise_yard_v54/manifest.json'))
    print('Exercise yard assembled:',len(removed),'wall tiles removed;',old_court,'old court marks removed.')


if __name__=='__main__':main()
