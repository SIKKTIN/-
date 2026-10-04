import json,shutil,hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[2];doc=root/'docs/art';qa=doc/'a05-native-project-v07'
qa.mkdir(exist_ok=True);(qa/'textures').mkdir(exist_ok=True)
m=json.loads((doc/'inventory-assets-v07.json').read_text())
r=json.loads((doc/'a05-icon-sources-v07.json').read_text())['records']
paths=[m['merchant']['texture'].replace('res://','')]+[x['texture']for x in r]+[x['source']for x in r]
for rel in paths:
    p=root/rel;t=qa/'textures'/p.name
    if t.exists()and t.read_bytes()!=p.read_bytes():raise RuntimeError('Refuse overwrite '+str(t))
    if not t.exists():shutil.copyfile(p,t)
metadata={'manifest':m,'icons':r,'files':[{'project_path':rel,'test_texture':'res://textures/'+Path(rel).name,'sha256':hashlib.sha256((root/rel).read_bytes()).hexdigest()}for rel in paths]}
(qa/'metadata.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2),encoding='utf-8')
(qa/'project.godot').write_text('config_version=5\n[application]\nconfig/name="A05 isolated native asset QA"\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=720\n[rendering]\nrenderer/rendering_method="gl_compatibility"\ntextures/default_filters/use_nearest_mipmap_filter=false\n',encoding='utf-8')
print(json.dumps({'copied_unmodified_sources':len(paths),'test_project':str(qa),'main_project_generated_directory_touched':False}))
