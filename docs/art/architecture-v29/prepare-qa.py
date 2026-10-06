from pathlib import Path
import shutil
root=Path(r'E:/Project/Godot/这次怎么逃');doc=root/'docs/art/architecture-v29';qa=doc/'godot-qa'
for rel in ['art/architecture/v29/manifest.json','art/architecture/v29/cafeteria_t_master_v29.png','art/editor/v09/manifest.json','art/architecture/v27/manifest.json','art/architecture/v24/manifest.json','art/architecture/v24/cafeteria_portal_v24.png','art/architecture/v25/safe_edges_v25.gdshader']:
    target=qa/rel;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(root/rel,target)
(qa/'art/editor/v09/icons').mkdir(parents=True,exist_ok=True)
shutil.copy2(root/'docs/art/architecture-v26/assembly.gd',qa/'assembly.gd')
(qa/'build-icons.gd').write_text((root/'docs/art/architecture-v26/build-icons.gd').read_text(encoding='utf-8-sig').replace('/v26/','/v29/'),encoding='utf-8')
shutil.copy2(doc/'native-preview.gd',qa/'native-preview.gd')
(qa/'project.godot').write_text('config_version=5\n[application]\nconfig/name="A29 native T junction"\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=850\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
