"""Register original clinic roof PNGs and apply only the saved roof style."""
from pathlib import Path
import hashlib
import json
import shutil
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs/art/clinic-restoration'
ART=ROOT/'art/architecture/clinic_roof_v1'

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')

def main():
    sources=json.loads((DOC/'roof-assets.json').read_text(encoding='utf-8'))
    assets=[];records=[]
    widths={'roof_skylight':138,'roof_extractor':44,'roof_drain':26}
    for entry in sources['assets']:
        path=ROOT/entry['path'];path.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(entry['source'],path)
        assert sha(path)==sha(Path(entry['source']))
        im=Image.open(path)
        definition={'id':'clinic_'+entry['key'],'name':{'roof_surface':'医务室防水屋面','roof_skylight':'医务室磨砂天窗','roof_extractor':'医务室排风口','roof_drain':'医务室排水口'}[entry['key']],
                    'texture':'res://'+entry['path'],'texture_size':list(im.size),'blocking':False}
        if entry['transparent']:
            assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
            x,y,right,bottom=im.getchannel('A').point(lambda v:255 if v>=180 else 0).getbbox()
            region=[max(0,x-3),max(0,y-3),min(im.width,right+3)-max(0,x-3),min(im.height,bottom+3)-max(0,y-3)]
            width=widths[entry['key']]
            definition.update(region=region,world_size=[width,width*region[3]/region[2]],render_mode='architecture_roof_detail')
        else:
            definition.update(world_size=[560,540],render_mode='architecture_material',fit_roof=True,opaque=True)
        assets.append(definition)
        records.append({'key':entry['key'],'path':entry['path'],'sha256':sha(path)})
    write(ART/'manifest.json',{'schema':1,'version':'clinic-roof-v1','assets':assets})
    map_path=ROOT/'data/rooms/r04.json';before=map_path.read_bytes();before_hash=sha(map_path)
    room=json.loads(before)
    clinic=next(r for r in room['visibility_rooms'] if r['id']=='clinic')
    clinic['roof_style']='clinic'
    assert sha(map_path)==before_hash,'Map changed during registration; rerun on the latest saved map.'
    (DOC/'roof-last-input-map.json').write_bytes(before)
    (DOC/'last-input-map.json').write_bytes(before)
    write(map_path,room)
    write(DOC/'roof-registration.json',{'mode':sources['mode'],'assets':records,'map_before_sha256':before_hash,'map_after_sha256':sha(map_path)})
    print('Registered 4 unchanged original PNGs; applied only clinic roof style on latest saved map.')

if __name__=='__main__':main()
