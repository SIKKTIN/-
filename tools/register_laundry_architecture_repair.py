"""Repair the latest saved laundry facade without moving its authored contents."""
from pathlib import Path
from copy import deepcopy
import hashlib, json, os, tempfile

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / 'docs/art/laundry-architecture-repair-v3'
MANIFEST = ROOT / 'art/architecture/laundry_repair_v3/manifest.json'

def read(p): return json.loads(p.read_bytes())
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p, value):
    p.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=p.name+'.', suffix='.tmp', dir=p.parent)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as f:
            f.write(json.dumps(value, ensure_ascii=False, indent='\t')+'\n')
        os.replace(tmp, p)
    finally:
        if os.path.exists(tmp): os.unlink(tmp)

def main():
    path = ROOT/'data/rooms/r04.json'
    initial = sha(path); before = read(path); data = deepcopy(before)
    fixture = next(f for f in data['fixtures'] if f['id']=='cafeteria-rear-visual45')
    x,y,w,h = fixture['rect']
    assert (w,h)==(180,20), 'Recalibrate against the latest opening.'
    left = x-420; top = y-100
    surfaces = data['architecture']['wall_surfaces']; walls = data['walls']
    owned = [s for s in surfaces if s.get('grid_tile_asset','').startswith('laundry_')]
    assert owned and min(walls[s['wall_index']][1] for s in owned)==top
    bath = {a['id']:a for a in read(ROOT/'art/architecture/bath_v1/manifest.json')['assets']}
    definitions = {}
    def clone(source, target):
        if target in definitions: return definitions[target]
        a=deepcopy(bath[source]);a.update(id=target,name='洗衣室新版 · '+source.removeprefix('bath_'),authoring_set='laundry-repair-v3',runtime_size_limit=512)
        if 'wall_h_' in target:a.update(name='洗衣室新版 · 横墙 '+target.rsplit('_',1)[1],editor_subcategory='tiles_h')
        elif 'lintel' in target:a.update(name='洗衣室新版 · 门楣 '+target.rsplit('_',1)[1],editor_subcategory='tiles_frame')
        elif 'corner' in target or 'shared_ne' in target:a.update(name='洗衣室新版 · 墙角 '+target.rsplit('_',1)[1].upper(),editor_subcategory='tiles_corner')
        else:a.update(name='洗衣室新版 · 竖墙 '+str(a['render_size'][1]),editor_subcategory='tiles_v')
        a.pop('legacy_id',None)
        definitions[target]=a
        return a
    changed=[]
    for s in owned:
        old=s['grid_tile_asset'];r=walls[s['wall_index']]
        if old=='laundry_wall_v_short':
            length=r[3];target='laundry_repair_v_'+str(int(length))
            a=clone('bath_wall_v_long',target)
            a['world_size']=a['render_size']=[20,length]
            a['name']='洗衣室新版 · 竖墙 '+str(int(length))
            a['collision_parts']=[[0,0,20,length]];a['grid_tile']['rows']=length/20
            a['assembly_patches'][0]['source'][2] = bath['bath_wall_v_long']['assembly_patches'][0]['source'][2]*length/120
            a['assembly_patches'][0]['destination'][3]=length
        else:
            target=old.replace('laundry_','laundry_repair_',1)
            clone(old.replace('laundry_','bath_',1),target)
        s['grid_tile_asset']=target;changed.append(s['wall_index'])
    # Replace the two legacy T faces, retaining their authored collision parts.
    for s in surfaces:
        r=walls[s['wall_index']]
        if r==[left,top,40,120]:
            s['grid_tile_asset']=clone('bath_corner_nw','laundry_repair_corner_nw')['id'];changed.append(s['wall_index'])
        elif r==[left+900,top,60,120]:
            a=clone('bath_corner_ne','laundry_repair_shared_ne')
            a['world_size']=a['render_size']=[60,120]
            for p in a['assembly_patches']:p['destination'][0]+=20
            patch=deepcopy(bath['bath_wall_h_00']['assembly_patches'][0])
            patch['source'][2]/=2;patch['destination']=[0,0,20,120]
            a['assembly_patches'].insert(0,patch)
            a['grid_tile']['columns']=3;a['collision_parts']=[[0,100,60,20]]
            s['grid_tile_asset']=a['id'];changed.append(s['wall_index'])
    # The old perimeter facade overlaps the laundry's relocated south facade.
    # Suppress only its covered paint; its physical boundary remains authored.
    south=max(walls[s['wall_index']][1]+walls[s['wall_index']][3] for s in owned)
    suppressed=[]
    for s in surfaces:
        r=walls[s['wall_index']]
        if s.get('grid_tile_asset','').startswith('prison_h_') and r[1]==south-100 and r[0]>=left+20 and r[0]+r[2]<=left+940:
            s['render_enabled']=False;suppressed.append(s['wall_index'])
    open_id='doorway_laundry_pocket_open_v3';closed_id='doorway_laundry_pocket_closed_v3'
    door_templates=read(ROOT/'art/architecture/bath_pocket_v1/manifest.json')['assets']
    for state in ['open','closed']:
        a=deepcopy(next(d for d in door_templates if d['id']==f'doorway_bath_pocket_{state}_v1'))
        a.update(id=open_id if state=='open' else closed_id,name='洗衣室北入口 · 双扇推拉门 · '+('打开' if state=='open' else '关闭'),world_size=[200,120],render_size=[200,120],footprint_world_size=[180,20])
        dp=a['door_presentation'];dp.update(door_art=open_id,door_art_closed=closed_id,door_art_size=[200,120],visual_solid_parts=[[0,10.48,12,109.52],[188,10.48,12,109.52]],closed_visual_solid_parts=[[12,10.48,176,109.52]])
        frame=deepcopy(dp['door_open_patches'])
        for p,dst in zip(frame,[[0,0,200,10.48],[0,10.48,12,109.52],[188,10.48,12,109.52]]):p.update(asset=open_id,destination=dst)
        leaf=deepcopy(dp['door_closed_patches'][0]);leaf.update(asset=closed_id,destination=[12,10.48,176,109.52])
        dp['door_open_patches']=frame;dp['door_closed_patches']=[leaf]+frame
        definitions[a['id']]=a
    visual=[x-10,top,200,120]
    fixture.update(asset_id=closed_id,open_asset=open_id,closed_asset=closed_id,render_size=[200,120],rotation_door_visual_rect=visual,frame_only=False)
    gate=next(g for g in data['access_doors'] if g['id']=='cafeteria-rear');gate['asset_id']=closed_id
    side=next(g for g in data['access_doors'] if g['id']=='laundry-equipment')
    sx,sy,sw,sh=side['rect'];side['interaction_point']=[sx+45,sy+sh-30]
    # Keep the exterior pipe in front of both the front facade and its coping.
    pipe=next((f for f in data['fixtures'] if f.get('asset_id')=='laundry_downpipe_v1'),None)
    if pipe:pipe['exterior_shell']=True;pipe['in_front_of_wall_trim']=True
    write(MANIFEST,dict(schema=2,version='laundry-architecture-repair-v3',assets=list(definitions.values())))
    catalog=ROOT/'scripts/presentation/prop_catalog.gd';text=catalog.read_text(encoding='utf-8');entry='\t"res://art/architecture/laundry_repair_v3/manifest.json",'
    if entry not in text:
        anchor='\t"res://art/architecture/bath_pocket_v1/manifest.json",'
        assert anchor in text
        catalog.write_text(text.replace(anchor,anchor+'\n'+entry,1),encoding='utf-8')
    assert sha(path)==initial, 'R04 changed: retry on the latest map.'
    write(DOC/'input-map.json',before);write(DOC/'candidate-map.json',data)
    write(path,data);write(DOC/'output-map.json',data)
    write(DOC/'registration.json',dict(input_sha256=initial,output_sha256=sha(path),definition_ids=list(definitions),changed_wall_indices=changed,suppressed_wall_indices=suppressed,visual_rect=visual,opening=fixture['rect'],preserved_furniture=True,atlas_reuse='bath_v1 and bath_pocket_v1 originals'))
    print(f'Repaired {len(changed)} wall parts, suppressed {len(suppressed)} duplicate faces; latest layout preserved.')

if __name__=='__main__':main()
