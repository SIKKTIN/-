"""Audit registered character sources and documentation-only Godot caches."""
import argparse
import hashlib
import json
import re
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/dev/p109'

def audit():
    catalog = json.loads((ROOT/'data/presentation/character_libraries.json').read_text(encoding='utf-8'))
    characters, missing, seen = [], [], set()
    for path in catalog['libraries']:
        manifest = json.loads((ROOT/path.removeprefix('res://')).read_text(encoding='utf-8'))
        for asset in manifest['characters']:
            source = ROOT/asset['texture'].removeprefix('res://')
            if asset['id'] in seen:
                missing.append('duplicate ID: '+asset['id'])
            seen.add(asset['id'])
            if not source.is_file():
                missing.append(asset['texture'])
                continue
            digest = hashlib.sha256(source.read_bytes()).hexdigest()
            if digest != asset['sha256']:
                missing.append('changed PNG: '+asset['id'])
            image = Image.open(source)
            animation = asset['walk_animation']
            walk_source = ROOT/animation['texture'].removeprefix('res://')
            if not walk_source.is_file():
                missing.append(animation['texture'])
                continue
            walk_image = image if walk_source == source else Image.open(walk_source)
            if 'sha256' in animation and hashlib.sha256(walk_source.read_bytes()).hexdigest() != animation['sha256']:
                missing.append('changed walk PNG: '+asset['id'])
            frames = [asset['frames']['idle']]+[frame['region'] for frame in animation['frames']]
            for index, (x, y, w, h) in enumerate(frames):
                frame_image = image if index == 0 else walk_image
                if x < 0 or y < 0 or x+w > frame_image.width or y+h > frame_image.height or w <= 0 or h <= 0:
                    missing.append('invalid region: '+asset['id'])
            characters.append(dict(id=asset['id'], name=asset['name'], source=asset['texture'], bytes=source.stat().st_size,
                sha256=digest, size=list(image.size), poses=len(frames),
                previous_idle_rgba_bytes=image.width*image.height*4,
                cropped_idle_rgba_bytes=frames[0][2]*frames[0][3]*4))
    concepts = []
    for folder, file in [('factory-cast-v47','approved-concept.png'), ('factory-occupations-v48','concept-review.png'), ('factory-antagonists-v49','concept-review.png')]:
        path = ROOT/'docs/art'/folder/file
        if not path.is_file():
            missing.append(str(path.relative_to(ROOT)))
        else:
            concepts.append(dict(path=path.relative_to(ROOT).as_posix(), bytes=path.stat().st_size, sha256=hashlib.sha256(path.read_bytes()).hexdigest(), runtime=False))
    cached = {}
    for sidecar in (ROOT/'docs').rglob('*.import'):
        text = sidecar.read_text(encoding='utf-8-sig')
        match = re.search(r'^source_file="(res://docs/[^"\n]+)"', text, re.M)
        if not match:
            continue
        # Only importer output paths belonging to this project, never original images.
        for target in re.findall(r'"(res://\.godot/imported/[^"\n]+)"', text):
            path = ROOT/target.removeprefix('res://')
            if path.is_file():
                cached[target] = dict(path=target.removeprefix('res://'), source=match[1], bytes=path.stat().st_size)
            digest_sidecar = path.with_suffix('.md5')
            if digest_sidecar.is_file():
                key = 'res://'+digest_sidecar.relative_to(ROOT).as_posix()
                cached[key] = dict(path=digest_sidecar.relative_to(ROOT).as_posix(), source=match[1], bytes=digest_sidecar.stat().st_size)
    runtime_docs = []
    for folder in ['scripts','scenes','data']:
        for path in (ROOT/folder).rglob('*'):
            if path.is_file() and path.suffix in ['.gd','.tscn','.tres','.json']:
                matches = re.findall(r'["\'](res://docs/[^"\'\n]+)["\']', path.read_text(encoding='utf-8-sig'))
                if matches:
                    runtime_docs.append(dict(source=path.relative_to(ROOT).as_posix(), references=matches))
    return dict(characters=characters, character_count=len(characters), pose_count=sum(c['poses'] for c in characters),
        original_character_png_bytes=sum(c['bytes'] for c in characters), concepts=concepts,
        previous_idle_rgba_bytes=sum(c['previous_idle_rgba_bytes'] for c in characters),
        cropped_idle_rgba_bytes=sum(c['cropped_idle_rgba_bytes'] for c in characters),
        documentation_import_cache=list(cached.values()), documentation_import_cache_bytes=sum(c['bytes'] for c in cached.values()),
        runtime_documentation_dependencies=runtime_docs, errors=missing)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage', choices=['before','after'], required=True)
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    report = audit()
    (OUT/(args.stage+'.json')).write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k not in ['characters','documentation_import_cache','concepts']}, ensure_ascii=False))
    return 1 if report['errors'] or report['runtime_documentation_dependencies'] else 0

if __name__ == '__main__':
    raise SystemExit(main())
