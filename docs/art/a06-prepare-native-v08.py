import json,shutil,hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[2];doc=root/'docs/art';qa=doc/'a06-native-v08';qa.mkdir(exist_ok=True);(qa/'textures').mkdir(exist_ok=True)
manifest=json.loads((root/'art/props/prison_v08/manifest.json').read_text(encoding='utf-8'))
files=[]
for a in manifest['assets']:
    source=root/a['texture'].replace('res://','');target=qa/'textures'/source.name
    if target.exists()and target.read_bytes()!=source.read_bytes():raise RuntimeError('Refuse overwrite original QA source')
    if not target.exists():shutil.copyfile(source,target)
    files.append({'id':a['id'],'project_path':source.relative_to(root).as_posix(),'test_texture':'res://textures/'+target.name,'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
with(qa/'metadata.json').open('w',encoding='utf-8',newline='\n')as f:f.write(json.dumps({'manifest':manifest,'files':files},ensure_ascii=False,indent=2)+'\n')
with(qa/'project.godot').open('w',encoding='utf-8',newline='\n')as f:f.write('config_version=5\n[application]\nconfig/name="A06 isolated native asset import QA"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
print(json.dumps({'test_project':str(qa),'unmodified_png_copies':len(files),'main_project_untouched':True}))
