"""One continuous painted four-corner master; no cap half-strip collage."""
from pathlib import Path
import copy, hashlib, json
root=Path(__file__).resolve().parents[3]
art=root/'art/architecture/v38'
old=json.loads((root/'art/architecture/v37/manifest.json').read_text('utf-8'))
assets=[]
tex='res://art/architecture/v38/four_corner_master.png'
sha=hashlib.sha256((root/'art/architecture/v38/four_corner_master.png').read_bytes()).hexdigest()
def patch(src,dst):
    return dict(source=src,destination=dst,modulate=[1,1,1,1],mirror_x=False,role='complete_wall_body')
for code in ['se','sw','ne','nw']:
    a=copy.deepcopy(next(a for a in old['assets'] if a['id']=='prison_l_'+code))
    east=code.endswith('e');south=code.startswith('s')
    h=120 if south else 140
    x=65 if east else 1367
    bands=[(59,53,0,28),(112,81,28,60),(193,46,88,32)] if south else [(742,27,0,20),(769,50,20,28),(819,83,48,60),(902,48,108,32)]
    a.update(texture=tex,texture_size=[1536,1024],region=[0,0,1536,1024],world_size=[40,h],render_size=[40,h],
        sha256=sha,authoring_set='universal-v38',corner_shape='continuous-rounded-two-port',
        alpha_core_shader='res://art/architecture/v38/shared-ports.gdshader',
        assembly_patches=[patch([x,y,104,sh],[0,dy,40,dh]) for y,sh,dy,dh in bands],
        editor_icon=f"res://art/editor/v17/icons/{a['id']}.tres")
    a['grid_tile'].update(rows=h//20,port_reference_texture='res://art/architecture/v33/full_wall_master_v33.png',horizontal_offset=0 if south else 20,horizontal_extent=120)
    a['collision_parts']=[[0,h-20,40,20]]+([] if south else [[0 if east else 20,0,20,h]])
    a['connection_tag']=','.join(sorted(a['connections']))+f'/40x{h}'
    assets.append(a)
(art/'manifest.json').write_text(json.dumps(dict(schema=2,version='continuous-corners-v38',assets=assets),ensure_ascii=False,indent=2)+'\n','utf-8')
(root/'art/editor/v17/manifest.json').write_text(json.dumps(dict(schema=1,assets=[dict(id=a['id'],name=a['name'],editor_icon=a['editor_icon'],category='furniture') for a in assets],tools=[]),ensure_ascii=False,indent=2)+'\n','utf-8')
print('Registered four continuous L corners; upper 2x6, lower 2x7 cells.')
