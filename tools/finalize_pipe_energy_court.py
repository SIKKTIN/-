from copy import deepcopy
from register_pipe_energy_court import ROOT,DOC,read,write,sha,assets
defs=assets()
path=ROOT/'data/rooms/r04.json'
before=read(path);digest=sha(path)
d=deepcopy(before)
assert d.get('pipe_energy_court_polish')==1
for f in d['fixtures']:
    if f.get('asset_id')=='energy_gantry_v1':f['render_size']=defs['energy_gantry_v1']['render_size']
    if f.get('id')=='energy-court-platform-tee':f['rect'][1]=2900
assert sha(path)==digest
write(DOC/'before-final-map.json',before)
write(path,d);write(DOC/'after-map.json',d);write(DOC/'candidate-map.json',d)
registration=read(DOC/'map-registration.json');registration['after_sha256']=sha(path)
write(DOC/'map-registration.json',registration)
print('Main pipe pair thickened by cropping source extent at uniform scale; source pixels and support collision unchanged.')
