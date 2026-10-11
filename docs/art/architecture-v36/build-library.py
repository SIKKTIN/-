"""Universal grid kit using native UV geometry and the approved original paint."""
from pathlib import Path
import json,hashlib
root=Path(__file__).resolve().parents[3]
out=Path(__file__).resolve().parent
art=root/'art/architecture/v36'; icons=root/'art/editor/v15/icons'
art.mkdir(parents=True,exist_ok=True);icons.mkdir(parents=True,exist_ok=True)
tex='res://art/architecture/v33/full_wall_master_v33.png'
sha=hashlib.sha256((root/tex.removeprefix('res://')).read_bytes()).hexdigest()
assets=[]
def patch(src,dest):return {'source':src,'destination':dest,'modulate':[1,1,1,1],'mirror_x':False,'role':'complete_wall_body'}
def make(ident,name,size,patches,mode,connections,collisions,stem=-1,**extra):
    g={'cell':20,'columns':size[0]//20,'rows':size[1]//20,'parameterized_shader':True,
       'horizontal_ports':bool(set(connections)&{'west','east'}),'horizontal_left':'west' in connections,'horizontal_right':'east' in connections,
       'vertical_ports':False,'north_port':False,'north_stem':'north' in connections and stem>=0,'south_stem':'south' in connections and stem>=0,
       'stem_x':stem,'horizontal_profile':[1030,130,0,370],'vertical_profile':[710,600,120,0]}
    g.update(extra.pop('grid',{}))
    a={'id':ident,'name':name,'texture':tex,'texture_size':[1536,1024],'region':[0,0,1536,1024],
       'world_size':size,'render_size':size,'render_mode':mode,'assembly_patches':patches,'blocking':False,
       'alpha_core_shader':'res://art/architecture/v36/shared-ports.gdshader','grid_tile':g,'collision_parts':collisions,
       'connections':connections,'authoring_set':'universal-v36','connection_tag':','.join(sorted(connections))+f'/{size[0]}x{size[1]}',
       'sha256':sha,'editor_icon':f'res://art/editor/v15/icons/{ident}.tres'}
    a.update(extra);assets.append(a)
def facade(srcx,w=40):return [patch([srcx,130,190*w/40,370],[0,0,w,120])]
names=[('a','横墙 A · 素面',425),('b','横墙 B · 石纹',1035),('c','横墙 C · 旧痕',1210),('d','横墙 D · 轻裂',90),('e','横墙 E · 潮痕',265)]
for suffix,name,x in names:
    make('prison_h_'+suffix,name,[40,120],facade(x),'architecture_tiled_facade',['west','east'],[[0,100,40,20]],variant_family='horizontal')
for suffix,x in [('a',425),('b',1035),('c',1210)]:
    make('prison_h_short_'+suffix,'短横墙 '+suffix.upper()+' · 1×6格',[20,120],facade(x,20),'architecture_tiled_facade',['west','east'],[[0,100,20,20]],variant_family='horizontal_short')
for suffix,y in [('a',250),('b',400),('c',520)]:
    make('prison_v_'+suffix,'纵墙 '+suffix.upper()+' · 1×3格',[20,60],[patch([710,y,120,144],[0,0,20,60])],'architecture_tiled_top',['north','south'],[[0,0,20,60]],grid={'vertical_ports':True},variant_family='vertical')
make('prison_v_long','长纵墙 · 1×6格',[20,120],[patch([710,382,120,288],[0,0,20,120])],'architecture_tiled_top',['north','south'],[[0,0,20,120]],grid={'vertical_ports':True})
make('prison_v_short','短纵墙 · 1×1格',[20,20],[patch([710,540,120,48],[0,0,20,20])],'architecture_tiled_top',['north','south'],[[0,0,20,20]],grid={'vertical_ports':True})
def root_down(x):return [patch([710,130,120,370],[x,0,20,120])]
def post(x):return [patch([710,670,120,84],[x,0,20,28]),patch([710,754,120,128],[x,28,20,60]),patch([710,882,120,88],[x,88,20,32])]
left=patch([590,130,120,370],[0,0,20,120])
def right(x):return patch([830,130,120,370],[x,0,20,120])
for code,name,south,east in [('se','左上转角 · 向右 / 向下',True,True),('sw','右上转角 · 向左 / 向下',True,False),('ne','左下转角 · 向右 / 向上',False,True),('nw','右下转角 · 向左 / 向上',False,False)]:
    sx=0 if east else 20
    patches=(root_down(sx) if south else post(sx))+([right(20)] if east else [left])
    collisions=[[0,100,40,20]]+([] if south else [[sx,0,20,120]])
    make('prison_corner_'+code,name,[40,120],patches,'architecture_junction_l',['east' if east else 'west','south' if south else 'north'],collisions,stem=sx)
for code,name,north,south in [('s','T形 · 向下分叉',False,True),('n','T形 · 向上分叉',True,False),('cross','十字连接',True,True)]:
    conn=['west','east']+(['north'] if north else [])+(['south'] if south else [])
    middle=root_down(20) if south else post(20)
    make('prison_t_'+code,name,[60,120],[left]+middle+[right(40)],'architecture_junction_t',conn,[[0,100,60,20]]+([[20,0,20,120]] if north else []),stem=20)
for code,east in [('e',True),('w',False)]:
    sx=0 if east else 20
    make('prison_t_'+code,'T形 · 向'+('右' if east else '左')+'分叉',[40,120],root_down(sx)+([right(20)] if east else [left]),'architecture_junction_t',['north','south','east' if east else 'west'],[[0,100,40,20],[sx,0,20,120]],stem=sx)
make('prison_end_s','纵墙收口 · 南端',[20,100],[patch([710,670,120,300],[0,0,20,100])],'architecture_endface',['north'],[[0,0,20,100]],grid={'north_port':True})
make('prison_end_n','纵墙收口 · 北端',[20,20],[patch([710,236,120,60],[0,0,20,20])],'architecture_endface',['south'],[[0,0,20,20]],grid={'south_port':True})
for code,east in [('w',True),('e',False)]:
    sx=0 if east else 20
    # A closed, complete post and a plain wing: no orphan coping overlay.
    wing=patch([950 if east else 400,130,95,370],[20 if east else 0,0,20,120])
    make('prison_end_'+code,'横墙收口 · '+('左端' if east else '右端'),[40,120],post(sx)+[wing],'architecture_endface',['east' if east else 'west'],[[0,100,40,20]])
make('prison_jamb','门柱 · 1×6格',[20,120],post(0),'architecture_jamb',[],[[0,100,20,20]])
for w in [80,20]:
    make('prison_lintel_'+str(w),'门楣 · '+str(w//20)+'×1格',[w,20],[patch([950,130,190*w/40,84],[0,0,w,20])],'architecture_lintel',['west','east'],[],grid={'horizontal_profile':[1030,130,0,84]})
manifest={'schema':2,'version':'universal-prison-v36','master_texture':tex,'source_sha256':sha,'assets':assets}
(art/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
paired={'schema':1,'assets':[{'id':a['id'],'name':a['name'],'editor_icon':a['editor_icon'],'category':'furniture'} for a in assets],'tools':[]}
(root/'art/editor/v15/manifest.json').write_text(json.dumps(paired,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'assets':len(assets),'source_sha256':sha},ensure_ascii=False))
