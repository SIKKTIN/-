"""Native UV study: retain approved artwork, cut continuous faces on integer cells."""
import json,hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[3]
out=Path(__file__).resolve().parent
out.mkdir(parents=True,exist_ok=True)
tex='res://art/architecture/v33/full_wall_master_v33.png'
sha=hashlib.sha256((root/tex.removeprefix('res://')).read_bytes()).hexdigest()
assets=[]
def patch(src,dest,mirror=False):
    return {'source':src,'destination':dest,'mirror_x':mirror,'modulate':[1,1,1,1]}
def make(ident,name,size,patches,mode,collisions):
    assets.append({'id':ident,'name':name,'texture':tex,'region':[0,0,1536,1024],'texture_size':[1536,1024],
      'world_size':size,'render_size':size,'render_mode':mode,'assembly_patches':patches,
      'blocking':False,'alpha_core_shader':'res://docs/art/architecture-v35/retain-paint.gdshader',
      'grid_tile':{'cell':20,'columns':size[0]//20,'rows':size[1]//20,'horizontal_ports':False,'vertical_ports':False,'stem_x':-1,
                   'horizontal_profile':[0,0,0,0],'vertical_profile':[0,0,0,0]},'collision_parts':collisions,'sha256':sha})
for side,start in [('left',20),('right',950)]:
    for i in range(3):
        make(f'study_h_{side}_{i}','连续横墙 · '+side+str(i),[40,120],[patch([start+i*190,130,190,370],[0,0,40,120])],'architecture_tiled_facade',[[0,100,40,20]])
        make(f'study_h_{side}_{i}_mirror','连续横墙 · '+side+str(i)+'反向',[40,120],[patch([start+i*190,130,190,370],[0,0,40,120],True)],'architecture_tiled_facade',[[0,100,40,20]])
make('study_t','完整圆弧T · 3×6格',[60,120],[patch([590,130,120,370],[0,0,20,120]),patch([710,130,120,370],[20,0,20,120]),patch([830,130,120,370],[40,0,20,120])],'architecture_junction_t',[[0,100,60,20]])
make('study_v','连续纵墙 · 1×3格',[20,60],[patch([710,500,120,170],[0,0,20,60])],'architecture_tiled_top',[[0,0,20,60]])
make('study_end','完整端面 · 1×5格',[20,100],[patch([710,670,120,300],[0,0,20,100])],'architecture_endface',[[0,0,20,100]])
(out/'sample-manifest.json').write_text(json.dumps({'schema':2,'version':'v35-local-style-study','source_sha256':sha,'assets':assets},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Native study assets:',len(assets),'unchanged source:',sha)
