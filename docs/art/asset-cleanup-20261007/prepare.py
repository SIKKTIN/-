"""Prepare a scoped, recoverable retired-prop cleanup; no image editing."""
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
ARCHIVE = Path('E:/Project/Godot/art-archive/这次怎么逃/20261007-retired-props').resolve()
assert not ARCHIVE.is_relative_to(ROOT)
assert not ARCHIVE.exists(), 'Archive already exists; inspect before rerunning.'
plan = json.loads((OUT / 'plan.json').read_text(encoding='utf-8-sig'))
ids = set(plan['ids'])
records = []
for relative in plan['files']:
    source = (ROOT / relative).resolve()
    assert source.is_relative_to(ROOT) and source.is_file(), relative
    records.append({'path': relative, 'bytes': source.stat().st_size,
                    'sha256': hashlib.sha256(source.read_bytes()).hexdigest()})

ARCHIVE.mkdir(parents=True)
manifests = ['art/props/prison_v08/manifest.json',
             'art/props/prison_v17/manifest.json',
             'art/props/cafeteria_v14/manifest.json',
             'art/editor/v01/manifest.json', 'art/editor/v02/manifest.json']
for relative in manifests + ['scripts/editor/editor_catalog.gd']:
    backup = ARCHIVE / 'metadata-before' / relative
    backup.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / relative, backup)

# Record map bytes, without changing maps or other concurrent work.
maps = {str(p.relative_to(ROOT)).replace('\\', '/'):
        hashlib.sha256(p.read_bytes()).hexdigest()
        for p in (ROOT / 'data/rooms').glob('*.json')}
receipt = {'archive': str(ARCHIVE), 'files': records, 'map_sha256': maps,
           'removed_bytes': sum(r['bytes'] for r in records), 'ids': plan['ids']}
for target in [OUT / 'receipt.json', ARCHIVE / 'receipt.json']:
    target.write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

for relative in manifests:
    path = ROOT / relative
    doc = json.loads(path.read_text(encoding='utf-8-sig'))
    doc['assets'] = [a for a in doc['assets'] if a['id'] not in ids]
    if 'reuse' in doc:
        doc['reuse'] = [p for p in doc['reuse'] if p.removeprefix('res://') not in plan['textures']]
    path.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

path = ROOT / 'scripts/editor/editor_catalog.gd'
text = path.read_text(encoding='utf-8')
assert text.count('"res://art/editor/v18/manifest.json",') == 1
path.write_text(text.replace('"res://art/editor/v18/manifest.json",', ''), encoding='utf-8')
print(json.dumps({'prepared_files': len(records), 'archive': str(ARCHIVE),
                  'bytes': receipt['removed_bytes']}, ensure_ascii=False))
