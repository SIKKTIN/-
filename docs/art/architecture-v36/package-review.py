import json,hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[3];out=Path(__file__).resolve().parent
paths=['data/rooms/r04.json','scripts/editor/editor_catalog.gd','scripts/editor/map_document.gd','scripts/editor/map_editor.gd','scripts/editor/map_canvas.gd','scripts/presentation/prop_catalog.gd','scripts/presentation/world_volume.gd','scripts/world/prison_world.gd']
for directory in ['art/architecture/v36','art/editor/v15']:
    paths += [p.relative_to(root).as_posix() for p in (root/directory).rglob('*') if p.is_file() and not p.name.endswith(('.uid','.import'))]
paths += [p.relative_to(root).as_posix() for p in out.iterdir() if p.is_file() and p.suffix in ['.md','.json','.png','.gd','.py'] and p.name!='review-package.json']
package={'status':'local implementation awaiting human visual approval','producer_not_contacted':True,'asset_count':29,'r04_migrated_tiles':85,'checks':{'library':146,'r04_native':182,'access_rules':73},'source_png_sha256':hashlib.sha256((root/'art/architecture/v33/full_wall_master_v33.png').read_bytes()).hexdigest(),'files':[{'path':p,'sha256':hashlib.sha256((root/p).read_bytes()).hexdigest()} for p in sorted(set(paths))]}
(out/'review-package.json').write_text(json.dumps(package,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
