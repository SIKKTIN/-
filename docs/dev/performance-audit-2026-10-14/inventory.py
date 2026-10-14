from pathlib import Path
import json,collections,struct,subprocess
root=Path(__file__).resolve().parents[3];dest=Path(__file__).parent
rows=[]
paths=subprocess.check_output(['rg','--files','--hidden','--no-ignore','art','audio','docs','.godot/imported'],cwd=root).decode('utf8').splitlines()
for name in paths:
 p=root/name
 if not name.startswith('art') or p.suffix.lower()!='.png':continue
 try:
  with p.open('rb') as f:
   header=f.read(24)
  if header[:8]!=b'\x89PNG\r\n\x1a\n':continue
  w,h=struct.unpack('>II',header[16:24])
  rows.append({'path':p.relative_to(root).as_posix(),'bytes':p.stat().st_size,'width':w,'height':h})
 except Exception:pass
totals={}
for name in ['art','audio','docs','.godot/imported']:
 files=[root/p for p in paths if p.replace('\\','/').startswith(name+'/')]
 totals[name]={'files':len(files),'mib':sum(p.stat().st_size for p in files)/1048576}
d=json.loads((dest/'forward_plus.json').read_text(encoding='utf8'))
groups=collections.defaultdict(lambda:{'count':0,'estimated_rgba_mips_mib':0})
for t in d['textures']:
 key=t['key'];group='/'.join(key.split('/')[:5])
 groups[group]['count']+=1;groups[group]['estimated_rgba_mips_mib']+=t['estimated_rgba_mips_mib']
sources=collections.Counter(t['key'].split('[')[0] for t in d['textures'])
report={'disk':totals,'png_count':len(rows),'png_disk_mib':sum(p['bytes'] for p in rows)/1048576,'largest_png_sources':sorted(rows,key=lambda x:-x['bytes'])[:25], 'runtime_cache_estimated_rgba_mips_mib':sum(t['estimated_rgba_mips_mib'] for t in d['textures']),'runtime_groups':dict(sorted(groups.items(),key=lambda x:-x[1]['estimated_rgba_mips_mib'])),'most_cropped_sources':sources.most_common(20),'note':'Disk inventory includes historical art and documentation. Cache estimates assume RGBA8 with full mip chain; idle frames without mips may be overestimated. Godot texture monitor includes additional textures.'}
(dest/'asset-inventory.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps({'disk':totals,'png_count':len(rows),'cache_mib_estimate':report['runtime_cache_estimated_rgba_mips_mib'],'groups':list(report['runtime_groups'].items())[:8]},ensure_ascii=False))
