"""Seal only the roof holes identified by the native R04 doorway audit."""
from pathlib import Path
from copy import deepcopy
import json,hashlib,os,tempfile
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/art/roof-door-coverage-v1'
def write(p,d):
 p.parent.mkdir(parents=True,exist_ok=True)
 with tempfile.NamedTemporaryFile(mode='w',encoding='utf-8',dir=p.parent,delete=False) as f:
  f.write(json.dumps(d,ensure_ascii=False,indent='\t')+'\n');temp=f.name
 os.replace(temp,p)
def main():
 audit=json.loads((OUT/'before-audit.json').read_bytes())
 affected={r['room']:[p['id'] for p in r['ports'] if p['inward_area']>0 and p['uncovered_area']>.01] for r in audit}
 affected={k:v for k,v in affected.items() if v}
 assert affected=={'workshop-two':['fixture:campus-workshop-two-north','fixture:campus-workshop-two-east'],'warehouse':['fixture:campus-warehouse-west','fixture:campus-warehouse-east-north','fixture:campus-warehouse-east-south']},affected
 p=ROOT/'data/rooms/r04.json';raw=p.read_bytes();sha=hashlib.sha256(raw).digest();m=json.loads(raw);before=deepcopy(m)
 for room in m['visibility_rooms']:
  if room['id'] in affected:room['roof_sealed']=True
 changed=[]
 for ids in affected.values():
  for id in ids:
   assert id.startswith('fixture:')
   f=next(f for f in m['fixtures'] if f['id']==id[8:])
   f['roof_occludes_door']=True;changed.append(f['id'])
 for k in before:
  if k not in ['fixtures','visibility_rooms']:assert m[k]==before[k],k
 for old,f in zip(before['fixtures'],m['fixtures']):
  clean=deepcopy(f);clean.pop('roof_occludes_door',None)
  previous=deepcopy(old);previous.pop('roof_occludes_door',None)
  assert previous==clean
 (OUT/'before-map.json').write_bytes(raw)
 write(OUT/'map-registration.json',dict(affected=affected,rooms=list(affected),fixture_ids=changed,input_sha256=hashlib.sha256(raw).hexdigest()))
 with tempfile.NamedTemporaryFile(mode='w',encoding='utf-8',dir=p.parent,delete=False) as f:
  f.write(json.dumps(m,ensure_ascii=False,indent='\t')+'\n');temp=f.name
 assert hashlib.sha256(p.read_bytes()).digest()==sha,'Map changed during preparation; retry from latest.'
 os.replace(temp,p)
 print(json.dumps(dict(rooms=list(affected),doors=changed),ensure_ascii=False))
if __name__=='__main__':main()
