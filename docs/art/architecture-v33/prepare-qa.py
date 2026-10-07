from pathlib import Path
import shutil
root=Path(r'E:/Project/Godot/这次怎么逃');doc=root/'docs/art/architecture-v33';qa=doc/'godot-qa'
for rel in ['art/architecture/v33/manifest.json','art/architecture/v33/full_wall_master_v33.png','art/editor/v13/manifest.json','art/architecture/v25/safe_edges_v25.gdshader']:
    p=qa/rel;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(root/rel,p)
(qa/'art/editor/v13/icons').mkdir(parents=True,exist_ok=True)
shutil.copy2(root/'docs/art/architecture-v26/assembly.gd',qa/'assembly.gd')
(qa/'build-icons.gd').write_text((root/'docs/art/architecture-v26/build-icons.gd').read_text(encoding='utf-8-sig').replace('/v26/','/v33/'),encoding='utf-8')
shutil.copy2(doc/'native-preview.gd',qa/'native-preview.gd')
(qa/'project.godot').write_text('config_version=5\n[application]\nconfig/name="A33 complete short wall"\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=850\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
