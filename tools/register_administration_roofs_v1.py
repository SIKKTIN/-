"""Register original fitted roof art; change only the two saved roof styles."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import struct
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "art/architecture/administration_roofs_v1"
DOC = ROOT / "docs/art/administration-roofs-v1"
GENERATED = Path("C:/Users/gst20/.codex/generated_images/01a1362e-bf9d-7ae2-9c86-1164dfa14cda")
SOURCES = {
    "duty": ("exec-0b0661b7-a644-4af6-aa40-0c2747a9932e.png", "值班室 · 蓝灰咬边金属屋顶", [380, 440]),
    "office": ("exec-ea313244-3dc1-43d7-80df-fbbd4e25c893.png", "办公室 · 灰瓦与金属屋脊", [460, 440]),
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")


def main():
    ART.mkdir(parents=True, exist_ok=True)
    DOC.mkdir(parents=True, exist_ok=True)
    assets = []
    for style, (filename, name, world_size) in SOURCES.items():
        source = GENERATED / filename
        target = ART / (style + "-roof.png")
        shutil.copyfile(source, target)
        pixels = target.read_bytes()
        assert pixels[:8] == b"\x89PNG\r\n\x1a\n"
        dimensions = list(struct.unpack(">II", pixels[16:24]))
        assets.append({
            "id": "roof_" + style, "name": name,
            "texture": "res://" + target.relative_to(ROOT).as_posix(),
            "texture_size": dimensions, "world_size": world_size,
            "runtime_size_limit": 512, "render_mode": "architecture_material",
            "fit_roof": True, "opaque": True, "blocking": False,
            "editor_hidden": True, "sha256": sha(pixels),
            "source_kind": "built-in-imagegen-original-png",
        })
    write(ART / "manifest.json", {"schema": 1, "version": "administration-roofs-v1", "assets": assets})
    map_path = ROOT / "data/rooms/r04.json"
    before_bytes = map_path.read_bytes()
    before = json.loads(before_bytes)
    after = json.loads(before_bytes)
    for room in after["visibility_rooms"]:
        if room["id"] in SOURCES:
            room["roof_style"] = room["id"]
            room["roof_asset_id"] = "roof_" + room["id"]
    # Explicitly verify every unrelated field and every door is untouched.
    restored = json.loads(json.dumps(after))
    previous_rooms = {r["id"]: r for r in before["visibility_rooms"]}
    for room in restored["visibility_rooms"]:
        if room["id"] not in SOURCES:
            continue
        for field in ("roof_style", "roof_asset_id"):
            if field in previous_rooms[room["id"]]:
                room[field] = previous_rooms[room["id"]][field]
            else:
                room.pop(field, None)
    assert restored == before
    digest = sha(before_bytes)
    backup = DOC / "input-map.json"
    if not backup.exists():
        backup.write_bytes(before_bytes)
    encoded = (json.dumps(after, ensure_ascii=False, indent="\t") + "\n").encode("utf-8")
    fd, temporary = tempfile.mkstemp(prefix="r04-roofs-", suffix=".tmp", dir=map_path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(encoded)
        assert sha(map_path.read_bytes()) == digest, "Map changed during registration; rerun against current saved map."
        os.replace(temporary, map_path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    write(DOC / "registration.json", {
        "map_before_sha256": digest, "map_after_sha256": sha(encoded),
        "changed_rooms": list(SOURCES), "changed_fields": ["roof_style", "roof_asset_id"],
        "mode": "built-in-imagegen", "assets": assets,
    })
    print("Registered 2 original roof PNGs; only duty/office roof metadata changed.")


if __name__ == "__main__":
    main()
