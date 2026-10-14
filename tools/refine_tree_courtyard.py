from copy import deepcopy
from register_pipe_energy_court import ROOT,read,write,sha
DOC=ROOT/'docs/art/tree-courtyard-restoration-v1'
path=ROOT/'data/rooms/r04.json';before=read(path);digest=sha(path)
assert before.get('tree_courtyard_restoration_version')==1
assert not before.get('tree_courtyard_polish')
d=deepcopy(before)
removed=['energy-court-shrub-7','energy-court-shrub-8']
for f in d['fixtures']:
    if f['id']=='tree-court-south-right':f['rect'][0]=4035
d['fixtures']=[f for f in d['fixtures'] if f['id'] not in removed]
d['tree_courtyard_polish']=1
assert sha(path)==digest
write(DOC/'before-polish-map.json',before);write(path,d);write(DOC/'after-map.json',d)
write(DOC/'candidate-map.json',d)
registration=read(DOC/'registration.json');registration['removed_fixture_ids']=removed
registration['output_map_sha256']=sha(path);registration['polish_input_sha256']=digest
write(DOC/'registration.json',registration)
print('Aligned southeast grass cluster and removed two superseded garden weeds.')
