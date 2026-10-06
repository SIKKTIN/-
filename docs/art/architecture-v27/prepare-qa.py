from pathlib import Path
import shutil
root=Path(r'E:/Project/Godot/这次怎么逃');doc=root/'docs/art/architecture-v27';qa=doc/'godot-qa'
for rel in ['art/architecture/v27/manifest.json','art/editor/v07/manifest.json','art/architecture/v24/cafeteria_portal_v24.png','art/architecture/v24/manifest.json','art/architecture/v25/safe_edges_v25.gdshader']:
    target=qa/rel;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(root/rel,target)
(qa/'art/editor/v07/icons').mkdir(parents=True,exist_ok=True)
# Reuse the checked native 2D mesh builder; all phase shifts are zero here.
shutil.copy2(root/'docs/art/architecture-v26/assembly.gd',qa/'assembly.gd')
builder=(root/'docs/art/architecture-v26/build-icons.gd').read_text(encoding='utf-8-sig').replace('/v26/','/v27/')
(qa/'build-icons.gd').write_text(builder,encoding='utf-8')
shutil.copy2(doc/'native-preview.gd',qa/'native-preview.gd')
(qa/'project.godot').write_text('config_version=5\n[application]\nconfig/name="A27 original art local repair"\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=960\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
print(str(qa))
