"""Compare opaque retained wall interiors in eight native before/after pairs."""
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / "docs" / "tests"
report = json.loads((ROOT / "p80-connected-native.json").read_text("utf-8"))
checks = {}
for key, rects in report["pixel_masks"].items():
    before = np.asarray(Image.open(ROOT / f"p80-{key}-covered.png").convert("RGB"))
    after = np.asarray(Image.open(ROOT / f"p80-{key}-revealed.png").convert("RGB"))
    mask = np.zeros(before.shape[:2], dtype=bool)
    for x, y, width, height in rects:
        x1, y1 = int(np.ceil(x)), int(np.ceil(y))
        x2, y2 = int(np.floor(x + width)), int(np.floor(y + height))
        mask[y1:y2, x1:x2] = True
    delta = np.max(np.abs(before.astype(np.int16) - after.astype(np.int16)), axis=2)
    checks[key] = {
        "pixels": int(mask.sum()),
        "different_pixels": int(np.count_nonzero(delta[mask])),
        "max_channel_difference": int(delta[mask].max()),
        "passed": bool(mask.sum() > 1000 and not delta[mask].any()),
    }
passed = bool(checks) and all(check["passed"] for check in checks.values())
(ROOT / "p80-wall-pixel-parity.json").write_text(
    json.dumps({"checks": checks, "passed": passed}, indent=2), "utf-8"
)
print(f"{len(checks)} wall pixel pairs passed: {passed}")
raise SystemExit(0 if passed else 1)
