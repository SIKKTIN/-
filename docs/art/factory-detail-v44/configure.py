from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
p=ROOT/'scripts/editor/editor_catalog.gd'
s=p.read_text(encoding='utf-8')
needle='"res://art/editor/v21/manifest.json"]'
if '"res://art/editor/v22/manifest.json"' not in s:
 assert needle in s
 p.write_text(s.replace(needle,'"res://art/editor/v21/manifest.json","res://art/editor/v22/manifest.json"]'),encoding='utf-8')
s=(ROOT/'docs/art/factory-expansion-v43/build-icons.gd').read_text(encoding='utf-8').replace('factory_v43','factory_v44')
(Path(__file__).resolve().parent/'build-icons.gd').write_text(s,encoding='utf-8')
