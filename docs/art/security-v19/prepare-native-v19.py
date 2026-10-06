"""Minimal isolated resource QA project. Copies only images and 13 icon resources."""
from pathlib import Path
import json,shutil
ROOT=Path(__file__).resolve().parents[3];DOC=Path(__file__).resolve().parent;QA=DOC/'godot-qa'
QA.mkdir(exist_ok=True)
(QA/'project.godot').write_text('config_version=5\n\n[application]\nconfig/name="A19 isolated Atlas resource QA"\n\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8',newline='\n')
manifest=json.loads((ROOT/'art/editor/v02/manifest.json').read_text(encoding='utf-8'));metadata=json.loads((DOC/'editor-icon-regions-v19.json').read_text(encoding='utf-8'))
paths={'art/props/security_v19/manifest.json','art/editor/v02/manifest.json','art/props/prison_v17/manifest.json'}
for e in metadata['icons']:paths.add(e['texture'].removeprefix('res://'));paths.add(e['editor_icon'].removeprefix('res://'))
for p in paths:
 dest=QA/p;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/p,dest)
print('Isolated resource files',len(paths))
