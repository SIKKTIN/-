"""Read-only art checks; writes only the QA report under docs/art."""
from pathlib import Path
from PIL import Image
import json,hashlib,struct,wave,math
R=Path('E:/Project/Godot/这次怎么逃')
report={'static_png':[],'audio':[],'font':{},'characters':[],'scope':'resource checks, not main-scene integration or human playtest'}
for directory in ['art/environment','art/props','art/ui','art/fx']:
 data=json.loads((R/directory/'manifest.json').read_text(encoding='utf-8'))
 for a in data['assets']:
  p=R/a['texture'].removeprefix('res://');im=Image.open(p)
  assert im.size==(a['w'],a['h']),(p,im.size)
  alpha=im.convert('RGBA').getchannel('A').getextrema()
  if not a.get('opaque'):assert alpha==(0,255),(p,alpha)
  report['static_png'].append({'file':str(p.relative_to(R)),'size':list(im.size),'alpha':list(alpha),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
data=json.loads((R/'audio/manifest.json').read_text())
for a in data['cues']:
 p=R/a['file'].removeprefix('res://')
 with wave.open(str(p),'rb') as f:
  assert(f.getnchannels(),f.getsampwidth(),f.getframerate())==(1,2,44100)
  samples=struct.unpack('<'+'h'*f.getnframes(),f.readframes(f.getnframes()))
 assert samples[0]==samples[-1]==0
 peak=max(abs(v) for v in samples);assert 0<peak<32767
 report['audio'].append({'file':p.name,'loop':a['loop'],'boundary_delta':abs(samples[0]-samples[-1]),'peak_dbfs':round(20*math.log10(peak/32767),2),'duration':len(samples)/44100,'audition':'not yet human-reviewed'})
font=R/'art/fonts/NotoSansCJKsc-Regular.otf';raw=font.read_bytes()
assert raw[:4]==b'OTTO'
u16=lambda o:struct.unpack_from('>H',raw,o)[0]
s16=lambda o:struct.unpack_from('>h',raw,o)[0]
u32=lambda o:struct.unpack_from('>I',raw,o)[0]
tables={}
for i in range(u16(4)):
 o=12+16*i;tag=raw[o:o+4].decode('ascii');tables[tag]=(u32(o+8),u32(o+12))
cmap=tables['cmap'][0];unicode_sub=[]
for i in range(u16(cmap+2)):
 o=cmap+4+i*8;platform,enc=u16(o),u16(o+2);sub=cmap+u32(o+4)
 if platform==0 or(platform==3 and enc in(1,10)):unicode_sub.append(sub)
def glyph(cp):
 for o in unicode_sub:
  fmt=u16(o)
  if fmt==12:
   for i in range(u32(o+12)):
    g=o+16+i*12;start,end,gid=u32(g),u32(g+4),u32(g+8)
    if start<=cp<=end:return gid+cp-start
  elif fmt==4 and cp<=65535:
   count=u16(o+6)//2;ends=o+14;starts=ends+count*2+2;deltas=starts+count*2;ranges=deltas+count*2
   for i in range(count):
    if u16(starts+2*i)<=cp<=u16(ends+2*i):
     delta=s16(deltas+2*i);ro=u16(ranges+2*i)
     if not ro:return(cp+delta)&65535
     gid=u16(ranges+2*i+ro+2*(cp-u16(starts+2*i)))
     return(gid+delta)&65535 if gid else 0
 return 0
text='这次怎么逃站立聊天撬锁大力气选择取消已逃脱狱警操作中'
missing=[c for c in text if not glyph(ord(c))];assert not missing,missing
report['font']={'file':font.name,'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'glyph_sample':text,'missing':missing,'license_file':'art/fonts/LICENSE.txt'}
cm=R/'art/characters/manifest.json'
if cm.exists():
 data=json.loads(cm.read_text(encoding='utf-8'))
 for a in data['actors']:
  p=R/a['texture'].removeprefix('res://');im=Image.open(p);assert im.mode=='RGBA'
  for state,rect in a['frames'].items():
   x,y,w,h=rect;assert min(x,y)>=0 and x+w<=im.width and y+h<=im.height
   ax,ay=a['anchor'][state];assert 0<=ax<=w and 0<=ay<=h
  report['characters'].append({'actor_id':a['actor_id'],'size':list(im.size),'alpha':list(im.getchannel('A').getextrema()),'states':list(a['frames']),'world_height':a['world_height'],'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
report['passed']=True
(R/'docs/art/qa-resource-v01.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'static_png':len(report['static_png']),'audio':len(report['audio']),'font_glyphs_missing':report['font']['missing'],'characters':len(report['characters']),'passed':True}))
