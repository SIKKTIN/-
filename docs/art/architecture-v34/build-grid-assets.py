from pathlib import Path
import json,hashlib,shutil
r=Path(r'E:/Project/Godot/这次怎么逃');a=r/'art/architecture/v34';d=r/'docs/art/architecture-v34';a.mkdir(parents=True,exist_ok=True);d.mkdir(parents=True,exist_ok=True)
shutil.copy2(r/'art/architecture/v33/full_wall_master_v33.png',a/'grid_wall_master.png')
tex='res://art/architecture/v34/grid_wall_master.png';sha=hashlib.sha256((a/'grid_wall_master.png').read_bytes()).hexdigest();rows=[]
def part(s,t):return dict(source=s,destination=t,modulate=[1,1,1,1],transpose=False,mirror_x=False,rotation_quarters=0,role='complete_grid_wall')
def make(id,name,size,patches,mode,**ports):
 grid=dict(cell=20,columns=size[0]//20,rows=size[1]//20,horizontal_ports=False,vertical_ports=False,stem_x=-1,horizontal_profile=[397,132,0,366],vertical_profile=[712,600,114,0]);grid.update(ports)
 rows.append(dict(id=id,name=name,texture=tex,texture_size=[1536,1024],region=[0,0,1536,1024],world_size=size,render_size=size,render_mode=mode,assembly_patches=patches,blocking=False,interactive=False,shadow_baked=False,sha256=sha,alpha_core_shader='res://art/architecture/v34/grid_ports.gdshader',grid_tile=grid,editor_icon='res://art/editor/v14/icons/'+id+'.tres'))
make('wall_grid_h','横墙 · 2×6格',[40,120],[part([420,132,150,366],[0,0,40,120])],'architecture_tiled_facade',horizontal_ports=True)
make('wall_grid_t','T接口 · 3×6格',[60,120],[part([590,132,122,366],[0,0,20,120]),part([712,132,114,366],[20,0,20,120]),part([826,132,124,366],[40,0,20,120])],'architecture_junction_t',horizontal_ports=True,stem_x=20)
make('wall_grid_l_left','左转角 · 2×6格',[40,120],[part([712,132,114,366],[0,0,20,120]),part([826,132,124,366],[20,0,20,120])],'architecture_junction_l',horizontal_ports=True,horizontal_left=False,stem_x=0)
make('wall_grid_l_right','右转角 · 2×6格',[40,120],[part([590,132,122,366],[0,0,20,120]),part([712,132,114,366],[20,0,20,120])],'architecture_junction_l',horizontal_ports=True,horizontal_right=False,stem_x=20)
make('wall_grid_v','纵墙 · 1×6格',[20,120],[part([712,382,114,288],[0,0,20,120])],'architecture_tiled_top',vertical_ports=True)
make('wall_grid_end','端面 · 1×5格',[20,100],[part([712,670,114,299],[0,0,20,100])],'architecture_endface',north_port=True)
make('wall_grid_jamb','门柱 · 1×6格',[20,120],[part([712,670,114,299],[0,0,20,120])],'architecture_jamb')
make('wall_grid_lintel','门楣 · 4×1格',[80,20],[part([400,132,234,84],[0,0,80,20])],'architecture_lintel',horizontal_ports=True,horizontal_profile=[397,132,0,84])
for path,obj in [(a/'manifest.json',dict(schema=2,version='grid-wall-review-v34',master_texture=tex,master_sha256=sha,assets=rows)),(r/'art/editor/v14/manifest.json',dict(schema=1,assets=[dict(id=x['id'],name=x['name'],category='furniture',editor_icon=x['editor_icon']) for x in rows],tools=[]))]:
 path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(d/'scope.md').write_text('本轮用户直接授权主美全权负责格子墙：现20网格为基准，先本人完成并供用户审，用户认可后再反馈制作人。没有发送制作人消息或验收反馈。复用：批准V33原PNG；修改：编辑器新建库/格子块放置和自身shader参数；新增：V34八种整数格组件、端口采样shader和本轮native预览QA；归档：旧墙在新建库隐退，旧ID及现有地图保留。R04及运行中未保存草稿不改，未提交Git或发布。\n',encoding='utf-8')
print('grid assets',len(rows),'source',sha)
