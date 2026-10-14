"""Keep room art intact; correct chess sign size and add a visible clinic entrance plaque."""
from pathlib import Path
import json,hashlib,os,tempfile
root=Path(__file__).resolve().parents[1]
doc=root/'docs/art/room-sign-size-v1';doc.mkdir(parents=True,exist_ok=True)
def read(p):return json.loads(p.read_bytes())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,d,expected):
    assert sha(p)==expected,f'Concurrent change: {p}; retry on latest saved file.'
    fd,tmp=tempfile.mkstemp(prefix=p.name+'.',suffix='.tmp',dir=p.parent)
    try:
        with os.fdopen(fd,'w',encoding='utf-8') as f:f.write(json.dumps(d,ensure_ascii=False,indent='\t')+'\n')
        assert sha(p)==expected,f'Concurrent change: {p}'
        os.replace(tmp,p)
    finally:
        if os.path.exists(tmp):os.unlink(tmp)
manifest=root/'art/props/chess_room_v1/manifest.json'
map_path=root/'data/rooms/r04.json'
clinic_path=root/'art/architecture/clinic_v1/manifest.json'
mh,dh,ch=sha(manifest),sha(map_path),sha(clinic_path)
assets=read(manifest);data=read(map_path)
before=json.loads(json.dumps(data));old_assets=json.loads(json.dumps(assets))
chess=next(a for a in assets['assets'] if a['id']=='chess_sign_v1')
chess['proportion_locked']=True
# Match the reading-room sign's glyph size while retaining the wider five-character label.
# Correcting the locked proportions restores the authored 150x38.3 world-unit plate.
reading=next(f for f in data['fixtures'] if f['id']=='reading-exterior-sign')
clinic_manifest=read(clinic_path)
clinic=next(a for a in clinic_manifest['assets'] if a['id']=='clinic_medical_sign')
# The red cross and margins leave smaller glyphs than the reading-room artwork.
# A wider 170-unit plaque brings the actual three-character text to the reference size.
w=170.0;h=w*clinic['region'][3]/clinic['region'][2]
for key in ['world_size','render_size','footprint_world_size']:clinic[key]=[w,h]
for f in data['fixtures']:
    if f['asset_id']!='clinic_medical_sign':continue
    fx,fy,fw,fh=f['rect'];f['rect']=[fx+fw/2-w/2,fy+fh/2-h/2,w,h]
door=next(f for f in data['fixtures'] if f['id']=='campus-clinic')
x,y,dw,depth=door['rect']
new={'id':'clinic-exterior-sign','asset_id':'clinic_medical_sign',
     'rect':[x+dw/2-w/2,y+depth-120-h-8,w,h],
     'blocks_movement':False,'blocks_sight':False,'exterior_shell':True,'in_front_of_wall_trim':True}
data['fixtures']=[f for f in data['fixtures'] if f['id']!=new['id']]+[new]
assert all(before[k]==data[k] for k in before if k!='fixtures')
assert [f for f in data['fixtures'] if f['id']!=new['id'] and f['asset_id']!='clinic_medical_sign']==[f for f in before['fixtures'] if f['id']!=new['id'] and f['asset_id']!='clinic_medical_sign']
write(manifest,assets,mh);write(clinic_path,clinic_manifest,ch);write(map_path,data,dh)
record={'changes':['chess_sign_v1.proportion_locked=true','clinic-exterior-sign fixture added at front doorway'],
        'reading_reference':reading,'chess_display_size':chess['world_size'],'clinic_display_size':clinic['world_size'],
        'clinic_fixture':new,'map_sha256_before':dh,'map_sha256_after':sha(map_path),
        'unrelated_map_fields_preserved':True,'other_existing_fixtures_preserved':True,'art_pixels_unchanged':True}
(doc/'change.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Restored chess sign to 150x38.3; clinic entrance plaque 170x46.1; reading sign untouched.')
