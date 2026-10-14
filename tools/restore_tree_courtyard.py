"""Restore the approved four-approach tree garden on the latest R04.

Original PNGs stay byte-identical. Native floors, flowerbed components and
independent foliage sprites remain selectable and editable in the map.
"""
from pathlib import Path
from copy import deepcopy
import json, shutil, argparse
from PIL import Image
from register_pipe_energy_court import read,write,sha,ROOT
from refine_pipe_energy_court import rounded
DOC=ROOT/'docs/art/tree-courtyard-restoration-v1'
ART=ROOT/'art/props/tree_courtyard_v1'
ENV=ROOT/'art/environment/tree_courtyard_v1'
PROP_MANIFEST='res://art/props/tree_courtyard_v1/manifest.json'
GROUND_MANIFEST='res://art/environment/tree_courtyard_v1/manifest.json'
PREFIX='tree-court-'
SHADER='res://art/props/exercise_yard_v54/clean_cutout.gdshader'

def register():
    ART.mkdir(parents=True,exist_ok=True);ENV.mkdir(parents=True,exist_ok=True)
    records=[];props=[];grounds=[]
    plants=read(DOC/'plant-inputs.json')['pngs'];tiles=read(DOC/'ground-inputs.json')['pngs']
    widths=[125,105,145,220,185]
    names=['东北角小草簇','东侧橙花长草簇','东南侧圆形草簇','东南角白花长草簇','西南角灌木草簇']
    for i,p in enumerate(plants+tiles):
        dst=ART/(p['key']+'.png')
        if not dst.exists():shutil.copyfile(p['source'],dst)
        assert sha(dst)==sha(Path(p['source']))
        im=Image.open(dst)
        records.append(dict(key=p['key'],path=dst.relative_to(ROOT).as_posix(),source=p['source'],sha256=sha(dst),size=list(im.size)))
        if i<5:
            assert im.mode=='RGBA' and im.getchannel('A').getextrema()==(0,255)
            box=im.getchannel('A').point(lambda a:255 if a>=140 else 0).getbbox()
            x,y,r,b=box;x=max(0,x-3);y=max(0,y-3);r=min(im.width,r+3);b=min(im.height,b+3)
            w,h=r-x,b-y;scale=widths[i]/w;display=h*scale;depth=display*.88
            props.append(dict(id='tree_court_grass_'+str(i+1)+'_v1',name='自强树庭 · '+names[i],
                texture='res://'+dst.relative_to(ROOT).as_posix(),texture_size=list(im.size),region=[x,y,w,h],
                world_size=[widths[i],display],render_size=[widths[i],display],footprint_world_size=[widths[i],depth],
                ground_rect=[0,h*.12,w,h*.88],elevation_world=display-depth,render_mode='projected_prop',proportion_locked=True,
                blocking=False,interactive=False,shadow_baked=True,runtime_size_limit=1024,alpha_core_shader=SHADER,
                editor_subcategory='furnishings',source_kind='built-in-imagegen-original-png',sha256=sha(dst)))
        else:
            grounds.append(dict(id='tree_court_'+('lawn' if i==5 else 'pavers')+'_v1',
                name='自强树庭 · '+('橄榄草皮' if i==5 else '浅灰绿小石砖'),texture='res://'+dst.relative_to(ROOT).as_posix(),
                texture_size=list(im.size),region=[0,0,*im.size],runtime_size_limit=1024,
                source_kind='built-in-imagegen-original-png',sha256=sha(dst)))
    defs={}
    for file in ['art/props/courtyard_v48/manifest.json','art/props/campus_v47/manifest.json','art/props/chess_room_v1/manifest.json']:
        defs.update({a['id']:a for a in read(ROOT/file)['assets']})
    # Small and long vertical planters preserve the painted cap/body proportions.
    # Source components are selected from the old native stone flowerbed PNG.
    for key,height in [('flower_short',120),('flower_long',285)]:
        a=deepcopy(defs['garden_bed_vertical_v48'])
        a.update(id='tree_court_'+key+'_v1',name='自强树庭 · '+('北侧短石边花坛' if height==120 else '南侧纵向石边花坛'),
            world_size=[75,height],render_size=[75,height],footprint_world_size=[75,height],ground_rect=[0,0,75,height],
            elevation_world=0,render_mode='architecture_garden_bed',editor_placeable=True,editor_subcategory='furnishings',
            alpha_core_shader=SHADER,runtime_size_limit=1024,shadow_baked=True,proportion_locked=False,
            assembly_patches=[dict(source=[363,63,300,60],destination=[0,0,75,15],role='original_north_cap'),
                              dict(source=[363,200,300,(height-30)*4],destination=[0,15,75,height-30],role='original_flower_and_side_rims'),
                              dict(source=[363,1416,300,60],destination=[0,height-15,75,15],role='original_south_cap')],
            reused_from='garden_bed_vertical_v48')
        a.pop('editor_icon',None);props.append(a)
    a=deepcopy(defs['garden_bed_horizontal_v48']);width=350;display=370*width/1901;depth=display-3
    a.update(id='tree_court_flower_horizontal_v1',name='自强树庭 · 横向石边花坛',world_size=[width,display],render_size=[width,display],
        footprint_world_size=[width,depth],ground_rect=[0,3/(width/1901),1901,depth/(width/1901)],elevation_world=3,
        proportion_locked=True,shadow_baked=True,runtime_size_limit=1024,alpha_core_shader=SHADER,reused_from='garden_bed_horizontal_v48')
    a.pop('editor_icon',None);props.append(a)
    for key,old,name,width in [('bench','park_bench_v47','南侧木长椅',160),('lamp','yard_lamp_v47','休息湾院灯',40),('bin','chess_bin_v1','长椅旁旧垃圾桶',28)]:
        a=deepcopy(defs[old]);w,h=a['region'][2:];scale=width/w
        ground=a.get('ground_rect',[0,0,w,h]);depth=ground[3]*scale
        a.update(id='tree_court_'+key+'_v1',name='自强树庭 · '+name,world_size=[width,h*scale],render_size=[width,h*scale],
            footprint_world_size=[ground[2]*scale,depth],ground_rect=ground,elevation_world=h*scale-depth,
            proportion_locked=True,shadow_baked=True,runtime_size_limit=512,alpha_core_shader=SHADER,reused_from=old)
        a.pop('editor_icon',None);props.append(a)
    write(ART/'manifest.json',dict(schema=2,version='tree-courtyard-v1',assets=props))
    write(ENV/'manifest.json',dict(schema=2,version='tree-courtyard-v1',assets=grounds))
    catalog=ROOT/'scripts/presentation/prop_catalog.gd';text=catalog.read_text(encoding='utf-8')
    line='\t"'+PROP_MANIFEST+'",\n'
    if line not in text:
        anchor='\t"res://art/props/pipe_energy_court_v1/manifest.json",\n'
        assert text.count(anchor)==1
        from tempfile import mkstemp
        import os
        fd,tmp=mkstemp(prefix='prop_catalog.',suffix='.writing',dir=catalog.parent)
        with os.fdopen(fd,'w',encoding='utf-8') as f:f.write(text.replace(anchor,anchor+line))
        os.replace(tmp,catalog)
    write(DOC/'production-assets.json',dict(mode='built-in imagegen',pngs=records,definition_ids=[a['id'] for a in props],
        ground_ids=[a['id'] for a in grounds],original_pngs_unchanged=True))
    return {a['id']:a for a in props}

def prepare():
    definitions=register();path=ROOT/'data/rooms/r04.json';digest=sha(path);before=read(path)
    assert not before.get('tree_courtyard_restoration_version'),'Already installed; refine owned records instead of replaying.'
    d=deepcopy(before);changed=[];new=[]
    targets={
        'courtyard-north-west':('tree_court_flower_horizontal_v1',3070,2000),
        'courtyard-north-east':('tree_court_flower_horizontal_v1',3760,2000),
        'courtyard-south-west':('tree_court_flower_horizontal_v1',3150,2780),
        'courtyard-south-east':('tree_court_flower_horizontal_v1',3700,2780),
        'courtyard-west-north':('tree_court_flower_short_v1',3150,2230),
        'courtyard-east-north':('tree_court_flower_short_v1',3975,2230),
        'courtyard-west-south':('tree_court_flower_long_v1',3150,2495),
        'courtyard-east-south':('tree_court_flower_long_v1',3975,2495),
        'courtyard-bench-west':('tree_court_bench_v1',3330,2690),
        'courtyard-bench-east':('tree_court_bench_v1',3730,2690),
        'energy-court-lamp-north-right':('tree_court_lamp_v1',3910,2720)}
    for f in d['fixtures']:
        if f['id'] in targets:
            asset,x,y=targets[f['id']];a=definitions[asset]
            f.update(asset_id=asset,rect=[x,y,*a['footprint_world_size']]);f.pop('render_size',None)
            if a.get('assembly_patches'):f['render_size']=a['render_size']
            changed.append(f['id'])
        elif f['id']=='courtyard-tree-island':
            f['rect'][1]=2215;changed.append(f['id'])
    assert len(changed)==12
    def prop(key,asset,x,y,**extra):
        a=definitions[asset]
        f=dict(id=PREFIX+key,asset_id=asset,rect=[x,y,*a['footprint_world_size']],blocks_movement=a.get('blocking',True),
               blocks_sight=False,tree_court_generated=True,exterior_shell=True)
        f.update(extra);d['fixtures'].append(f);new.append(f['id'])
    prop('west-lamp','tree_court_lamp_v1',3280,2720)
    prop('bench-bin','tree_court_bin_v1',3500,2740)
    # Each of the five user-marked clusters has its own PNG and placement.
    for key,i,x,y in [('northeast-corner',1,4095,1930),('east-orange',2,4120,2090),
                       ('southeast-middle',3,4070,2530),('south-right',4,3940,2735),('southwest-corner',5,2960,2730)]:
        prop(key,'tree_court_grass_'+str(i)+'_v1',x,y,concept_marked_cluster=True)
    for key,i,x,y in [('northwest-corner',1,2940,1930),('west-orange',2,2940,2110),('west-middle',3,2940,2520)]:
        prop(key,'tree_court_grass_'+str(i)+'_v1',x,y)
    old_floor_ids=['energy-court-tree-green-edge','energy-court-tree-west-walk','energy-court-tree-east-walk']
    removed_floor=[f['id'] for f in d['floor_regions'] if f['id'] in old_floor_ids]
    d['floor_regions']=[f for f in d['floor_regions'] if f['id'] not in removed_floor]
    def floor(key,rect,asset,world_points=None,**extra):
        f=dict(id=PREFIX+key,rect=rect,asset_id=asset,manifest=GROUND_MANIFEST,tree_court_generated=True,
               tile_origin=[0,0],tile_size=[240,240] if asset=='tree_court_pavers_v1' else [500,500])
        if world_points:
            x,y,w,h=rect;norm=[[(a-x)/w,(b-y)/h] for a,b in world_points]
            f['polygon']=rounded(rect,norm,85)
        f.update(extra);d['floor_regions'].append(f)
    floor('paved-loop-and-approaches',[2900,1900,1360,1040],'tree_court_pavers_v1')
    floor('north-approach',[3520,1800,140,100],'tree_court_pavers_v1')
    border=dict(natural_ground=True,edge_feather=14,outline_asset_id='drying_pebble_edge_1_v1',
                outline_manifest='res://art/environment/drying_yard_edges_v1/manifest.json',outline_width=14)
    floor('northwest-lawn',[2900,1900,620,450],'tree_court_lawn_v1',
          [[2900,1900],[3520,1900],[3520,2130],[3225,2130],[3225,2350],[2900,2350]],**border)
    floor('northeast-lawn',[3660,1900,600,450],'tree_court_lawn_v1',
          [[3660,1900],[4260,1900],[4260,2350],[3975,2350],[3975,2130],[3660,2130]],**border)
    floor('southwest-lawn',[2900,2500,620,380],'tree_court_lawn_v1',
          [[2900,2500],[3225,2500],[3225,2780],[3520,2780],[3520,2880],[2900,2880]],**border)
    floor('southeast-lawn',[3660,2500,600,380],'tree_court_lawn_v1',
          [[3975,2500],[4260,2500],[4260,2880],[3660,2880],[3660,2780],[3975,2780]],**border)
    floor('central-lawn-island',[3330,2170,540,450],'tree_court_lawn_v1',
          [[3330,2170],[3870,2170],[3870,2620],[3330,2620]],**border)
    for i,(x,y) in enumerate([(3540,1830),(3620,1830),(3290,2180),(3900,2180),(3535,2895),(3625,2895)]):
        d['ground_details'].append(dict(id=PREFIX+'drain-'+str(i),kind='drain',rect=[x,y,26,32],tree_court_generated=True))
    d['lamps']=[l for l in d.get('lamps',[]) if l.get('position') not in [[3650,1940],[4050,2630]]]
    for lamp in d.get('lamps',[]):
        if lamp.get('id')=='energy-court-east-light':lamp.update(position=[3930,2720],radius=240)
    d.setdefault('lamps',[]).append(dict(id=PREFIX+'west-light',position=[3300,2720],radius=240,
                                           energy=.5,color='#ffe2b7',draw_fixture=False,tree_court_generated=True))
    d['tree_courtyard_restoration_version']=1
    d.setdefault('concept_plan',{})['tree_courtyard_revision']=dict(version=1,reference='docs/art/tree-courtyard-concept-v1/concept.png',
        boundary=[2900,1900,1360,980],central_tree=[3400,2215,400,365],
        main_approaches=[[3590,1900],[2950,2425],[4210,2425],[3590,2895]],
        design='四向贯通环形步道、中央自强树岛、四片弧形草坪、南侧L形花坛与长椅休息湾，五组专用草丛')
    assert sha(path)==digest
    write(DOC/'before-map.json',before);write(DOC/'candidate-map.json',d)
    write(DOC/'registration.json',dict(input_map_sha256=digest,changed_fixture_ids=changed,new_fixture_ids=new,
        removed_floor_ids=removed_floor,new_floor_ids=[f['id'] for f in d['floor_regions'] if f.get('tree_court_generated')],
        boundary=[2900,1900,1360,980],original_wall_and_door_geometry_preserved=True))
    shutil.copyfile(ROOT/'docs/art/tree-courtyard-concept-v1/concept.png',DOC/'approved-concept.png')
    print('Prepared native tree courtyard candidate; project map not yet saved.')

def apply():
    path=ROOT/'data/rooms/r04.json';r=read(DOC/'registration.json')
    assert sha(path)==r['input_map_sha256'],'Map changed; prepare on latest saved state.'
    d=read(DOC/'candidate-map.json');write(path,d);write(DOC/'after-map.json',d)
    r['output_map_sha256']=sha(path);write(DOC/'registration.json',r)
    print('Saved four-approach tree courtyard with five unique generated plant clusters.')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('op',choices=['prepare','apply','register'])
    globals()[parser.parse_args().op]()
