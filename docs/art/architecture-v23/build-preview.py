import json,html
from pathlib import Path
root=Path('E:/Project/Godot/这次怎么逃');d=root/'docs/art/architecture-v23'
m=json.loads((root/'art/architecture/v23/manifest.json').read_text(encoding='utf-8'))
def sprite(a,width,height):
 x,y,w,h=a['region'];iw,ih=a['texture_size'];sx=width/w;sy=height/h
 src=(root/a['texture'].removeprefix('res://')).as_uri()
 return f'<div class="sprite" style="width:{width}px;height:{height}px;background-image:url(\'{src}\');background-size:{iw*sx}px {ih*sy}px;background-position:{-x*sx}px {-y*sy}px"></div>'
css='body{font:16px "Microsoft YaHei",sans-serif;background:#eae5d6;color:#344145;margin:24px}h2{font-size:20px;margin:18px 0 10px}.row{display:flex;gap:24px;align-items:flex-start}.card{background:#d6d8cc;border:1px solid #b9c1b4;padding:16px;border-radius:6px}.label{font-size:13px;margin:10px 0 0}.sprite{background-repeat:no-repeat}.icons{display:flex;gap:18px;align-items:center;margin:16px 0}.icon{display:flex;justify-content:center;align-items:center;width:64px;height:64px;background:#f2eee2;border:1px solid #c2c7ba}.dots{background-color:#d1d7cc;background-image:radial-gradient(#acb4a8 .8px,transparent .8px);background-size:8px 8px;padding:12px}.strip{display:flex;gap:0;overflow:hidden;width:400px}'
parts=['<!doctype html><meta charset="utf-8"><style>'+css+'</style><h2>A23 材质与原始门图检查</h2><p>展示按 manifest 区域渲染；底色用于核对真实透明通道。不是运行游戏截图。</p><div class="row">']
for a in m['assets'][:5]:
 parts.append('<div class="card">'+sprite(a,128,100 if 'cafeteria_wall' in a['id'] else 110 if 'wall_front' in a['id'] else 96)+'<div class="label">'+html.escape(a['name'])+'</div></div>')
parts.append('</div><h2>实际可视门高 110px（开闭共用完整区域）</h2><div class="row">')
for a in m['assets'][5:]:
 parts.append('<div class="card"><div class="dots">'+sprite(a,*a['render_size'])+'</div><div class="label">'+html.escape(a['name'])+'</div></div>')
parts.append('</div><h2>编辑器图标 64px / 48px（6%留白）</h2>')
for sz in [64,48]:
 parts.append('<div class="icons">')
 for a in m['assets']:
  w,h=a['region'][2:];s=min(sz/(w*1.12),sz/(h*1.12))
  parts.append(f'<div class="icon" style="width:{sz}px;height:{sz}px">'+sprite(a,w*s,h*s)+'</div>')
 parts.append('</div>')
parts.append('<h2>屋顶与墙面连续铺设</h2><div class="row">')
for a in [m['assets'][0],m['assets'][1],m['assets'][3]]:
 parts.append('<div class="card"><div class="strip">'+''.join(sprite(a,128,100) for _ in range(4))+'</div><div class="label">'+html.escape(a['name'])+' 横向连续</div></div>')
parts.append('</div>')
(d/'scale-preview.html').write_text(''.join(parts),encoding='utf-8')

