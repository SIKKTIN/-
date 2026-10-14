"""Record the reviewed solver's MIT attribution; do not modify the live map."""
from pathlib import Path
import subprocess
import hashlib
import json

root = Path(__file__).resolve().parents[1]
repo = Path('C:/Users/gst20/.codex/research/water-2026-10-13/swe2d')
out = root / 'art/fx/seaside_swe_v1'
license_text = subprocess.check_output(['git', 'show', 'HEAD:LICENSE'], cwd=repo)
(out / 'LICENSE-upstream.txt').write_bytes(license_text)
commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip()
provenance = {
    'upstream': 'https://github.com/opengenius/godot_swe_ocean2d',
    'commit': commit,
    'license': 'MIT',
    'attribution': 'Copyright (c) 2024 Evgenii Gubenko',
    'adaptation': [
        'staggered velocity advection and free-surface pressure gradient',
        'upwind depth flux update',
        'foam production from compression and persistent advection',
        'double-buffered state instead of shared intermediate texture',
        'fixed 120 Hz steps, dry boundaries and shallow-water drag',
        'procedural bathymetry and bridge-pier obstacles',
        'incoming waves forced only at outer boundary',
        'water shading from computed height gradients; no water photograph, normal-map or foam image',
    ],
    'scope': 'independent verification scene; no game map integration',
    'map_sha256_at_start': hashlib.sha256((root / 'data/rooms/r04.json').read_bytes()).hexdigest(),
}
(out / 'provenance.json').write_text(json.dumps(provenance, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('Recorded upstream attribution and map baseline.')
