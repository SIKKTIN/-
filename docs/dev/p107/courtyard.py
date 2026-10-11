"""Apply the approved landscaped courtyard to a native room document."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

def apply_courtyard(d):
    assets = {a['id']: a for a in json.loads((ROOT/'art/props/courtyard_v48/manifest.json').read_text(encoding='utf-8'))['assets']}
    bench = next(a for a in json.loads((ROOT/'art/props/campus_v47/manifest.json').read_text(encoding='utf-8'))['assets'] if a['id']=='park_bench_v47')
    assets[bench['id']] = bench
    d['fixtures'] = [f for f in d['fixtures'] if not f['id'].startswith(('campus-garden-', 'courtyard-'))]
    d['terrain_patches'] = [p for p in d.get('terrain_patches', []) if p.get('clip_rect') != [2800,2800,700,480]]
    def prop(id, asset, rect):
        a=assets[asset]
        width=rect[2] * a['render_size'][0] / a['footprint_world_size'][0]
        height=width * a['render_size'][1] / a['render_size'][0] if 'tree' in asset else rect[3]+12 if 'bed_' in asset else width*a['render_size'][1]/a['render_size'][0]
        d['fixtures'].append(dict(id='courtyard-'+id,asset_id=asset,rect=rect,render_size=[round(width,3),round(height,3)],blocks_movement=True,blocks_sight=False))
    for id, rect in [
        ('north-west',[2760,2670,380,90]), ('north-east',[3400,2670,300,90]),
        ('south-west',[2760,3300,380,90]), ('south-east',[3400,3300,380,90])]:
        prop(id,'garden_bed_horizontal_v48',rect)
    for id, rect in [
        ('west-north',[2760,2800,90,200]), ('west-south',[2760,3100,90,200]),
        ('east-north',[3690,2800,90,200]), ('east-south',[3690,3100,90,200])]:
        prop(id,'garden_bed_vertical_v48',rect)
    prop('tree-island','garden_tree_island_v48',[3070,2855,400,365])
    prop('bench-west','park_bench_v47',[2860,3410,190,65])
    prop('bench-east','park_bench_v47',[3490,3410,190,65])
    for region in d['floor_regions']:
        if region['id']=='garden-paving':
            region.update(asset_id='common_floor_v46',rect=[2700,2620,1140,920],tile_size=[640,640])
    d['expansion']['courtyard_revision']='concept-restoration-v48'
    d['expansion']['review_points']['garden']=[3260,3300]
    return d

def rebuild_corridor(d):
    H=[s for s in d['concept_plan']['horizontal'] if s['id']!='north-life-connection']
    V=d['concept_plan']['vertical']
    builder=(ROOT/'docs/art/factory-terrain-v45/rebuild-plan.py').read_text(encoding='utf-8')
    builder=builder[builder.index('walls=[];surfaces=[];joints=[];occupied=[]'):builder.index("d['bounds']=[0,0,4240,3040]")]
    scope=dict(H=H,V=V)
    exec(builder,scope)
    d['walls']=scope['walls']
    d['architecture']['wall_surfaces']=scope['surfaces']
    d['concept_plan']['horizontal']=H
    return d

if __name__=='__main__':
    file=ROOT/'data/rooms/r04.json'
    d=json.loads(file.read_text(encoding='utf-8-sig'))
    rebuild_corridor(d)
    apply_courtyard(d)
    file.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Removed stale corridor wall; rebuilt native junctions; landscaped courtyard applied.')
