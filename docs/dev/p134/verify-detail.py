"""Measure the rendered outline, rather than accepting only matching edge pixels."""
import hashlib
import json
from pathlib import Path
from statistics import median
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent

def contour(path, start, end):
    image = Image.open(path).convert('RGB')
    centers = []
    for x in [386, 396, 400, 404, 410, 416, 424, 432, 440]:
        dark = [y for y in range(start, end) if max(image.getpixel((x, y))) < 85]
        assert dark, f'Missing outline at column {x}'
        centers.append(median(dark))
    return max(centers) - min(centers)

old = contour(OUT / 'assembled-before.png', 475, 530)
new = contour(OUT / 'assembled-after.png', 475, 530)
top = contour(OUT / 'assembled-after.png', 370, 400)
native = json.loads((OUT / 'native-checks.json').read_text('utf-8'))
before = json.loads((OUT / 'manifest-before.json').read_text('utf-8'))['assets'][0]
current = json.loads((ROOT / 'art/architecture/v53/manifest.json').read_text('utf-8'))['assets'][0]
image_path = ROOT / current['texture'].removeprefix('res://')
checks = {
    'lower outline stays within half a world unit at 4x': new <= 2,
    'visible outline step reduced by at least 70 percent': new <= old * 0.3,
    'upper outline stays within one world unit at 4x': top <= 4,
    'original painting bytes retained': hashlib.sha256(image_path.read_bytes()).hexdigest() == before['sha256'],
    'map data and collision unchanged': json.loads((OUT / 'map-before.json').read_text('utf-8')) == json.loads((ROOT / 'data/rooms/r04.json').read_text('utf-8')),
    'native render and editor checks pass': not native['failed'],
    'native engine error output empty': not (OUT / 'final.err').read_text('utf-8').strip(),
}
failed = [name for name, passed in checks.items() if not passed]
report = dict(checks=checks, failed=failed, native_checks=len(native['checks']),
    total_checks=len(checks) + len(native['checks']),
    outline_spread_before_pixels=old, outline_spread_after_pixels=new, render_scale=4,
    method='native UV registration and junction-only interface feather; no PNG pixel edits')
(OUT / 'verification.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', 'utf-8')
print(json.dumps(report, ensure_ascii=False))
raise SystemExit(1 if failed else 0)
