from pathlib import Path
import shutil
root=Path(r'E:/Project/Godot/这次怎么逃');doc=root/'docs/art/architecture-v26';qa=doc/'godot-qa'
files=['art/architecture/v26/manifest.json','art/architecture/v26/wall_tiles_master_v26.png','art/editor/v06/manifest.json','art/architecture/v25/safe_edges_v25.gdshader']
for rel in files:
    d=qa/rel;d.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(root/rel,d)
(qa/'art/editor/v06/icons').mkdir(parents=True,exist_ok=True)
for f in ['assembly.gd','build-icons.gd']:shutil.copy2(doc/f,qa/f)
(qa/'project.godot').write_text('config_version=5\n[application]\nconfig/name="A26 isolated material assembly"\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=900\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
