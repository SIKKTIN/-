import json,html
from pathlib import Path
from PIL import Image
root=Path('E:/Project/Godot/这次怎么逃');d=root/'docs/art/architecture-v24'
m=json.loads((root/'art/architecture/v24/manifest.json').read_text(encoding='utf-8'));by={a['id']:a for a in m['assets']};assembly=json.loads((root/'art/architecture/v24/assembly.json').read_text(encoding='utf-8'))
def sprite(a,width,height):
 x,y,w,h=a['region'];iw,ih=a['texture_size'];sx=width/w;sy=height/h;src=(root/a['texture'].removeprefix('res://')).as_uri()
 return f'<div class="sprite" style="width:{width}px;height:{height}px;background-image:url(\'{src}\');background-size:{iw*sx}px {ih*sy}px;background-position:{-x*sx}px {-y*sy}px"></div>'
def building_layers():
 a=by['solitary_roof_axis_v24'];x,y,w,h=a['render_rect_on_shell']
 facade=dict(by['solitary_shell_closed_v24']);facade['region']=[60,530,1430,343]
 return '<div class="building"><div style="position:absolute;left:0px;top:189px">'+sprite(facade,456,109)+'</div>'+f'<div style="position:absolute;left:{x}px;top:{y}px">'+sprite(a,w,h)+'</div></div>'
ref=d/'concept-target.png';rw,rh=Image.open(ref).size
refspec={'texture':'res://docs/art/architecture-v24/concept-target.png','texture_size':[rw,rh],'region':[22,365,612,388]}
css='body{font:15px "Microsoft YaHei",sans-serif;background:#ede7d8;color:#34433f;margin:20px}h2{font-size:20px;margin:12px 0}.row{display:flex;gap:20px;align-items:flex-start}.card{padding:12px;background:#ced1c1;border:1px solid #a9b1a4;border-radius:6px}.label{margin:8px 0;font-size:14px}.sprite{background-repeat:no-repeat;flex:none}.building{position:relative;width:456px;height:298px}.wall{position:relative;width:600px;height:121.5px;background:#959e88}.icons{display:flex;gap:16px;align-items:center}.icon{width:64px;height:64px;display:flex;align-items:center;justify-content:center;background:#e9e7db;border:1px solid #bcc1b5}.note{font-size:13px;max-width:1460px}'
parts=['<!doctype html><meta charset="utf-8"><style>'+css+'</style><h2>A24 完整形体对照（源PNG缩放预览，非游戏截图）</h2><p class="note">左侧为用户确认目标的截图区域，部分屋顶被原HUD遮挡。中/右为制作素材；运行时需使用 opaque_core.gdshader 恢复实体核心不透明。</p><div class="row"><div class="card">'+sprite(refspec,456,288)+'<div class="label">确认目标：屋檐、前墙、门柱与基座</div></div><div class="card">'+building_layers()+'<div class="label">完整 CLOSED 建筑：不再程序平面拼贴</div></div><div class="card"><div class="building">'+sprite(by['solitary_shell_closed_v24'],456,298)]
a=dict(by['solitary_shell_open_v24']);a['region']=a['door_state_patch_region'];x,y,w,h=assembly['solitary']['door_state_patch_render_rect'];parts.append(f'<div style="position:absolute;left:{x}px;top:{y}px">'+sprite(a,w,h)+'</div></div><div class="label">OPEN 仅局部门部 patch，屋顶与石柱底图不动</div></div></div><h2>食堂同源结构模块装配（入口180×90）</h2><div class="row">')
gate_manifest=json.loads((root/'art/architecture/v23/manifest.json').read_text(encoding='utf-8'))
gates={a['id']:a for a in gate_manifest['assets']}
for state in ['closed','open']:
 parts.append('<div class="card"><div class="wall">')
 for item in assembly['cafeteria']['parts']:
  x,y,w,h=item['rect'];parts.append(f'<div style="position:absolute;left:{x}px;top:{y}px;z-index:2">'+sprite(by[item['id']],w,h)+'</div>')
 x,y,w,h=assembly['cafeteria']['gate']['rect'];parts.append(f'<div style="position:absolute;left:{x}px;top:{y}px;z-index:1">'+sprite(gates['cafeteria_gate_'+state+'_v23'],w,h)+'</div>')
 parts.append('</div><div class="label">食堂 '+state+'：完整翼已包含门柱，门楣单独接入</div></div>')
parts.append('</div><h2>新增建筑与模块图标64px</h2><div class="icons">')
for a in m['assets']:
 w,h=a['region'][2:];s=min(64/(w*1.12),64/(h*1.12))
 parts.append('<div class="icon">'+sprite(a,w*s,h*s)+'</div>')
parts.append('</div><p class="note">完整portal原图开口较窄，不可整张强拉为600宽。正式装配按左右翼200/220和独立180入口配准；长右翼需中段重复及最右柱收边。</p>')
(d/'scale-preview.html').write_text(''.join(parts),encoding='utf-8')

