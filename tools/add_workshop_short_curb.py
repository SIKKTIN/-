"""Add a native short curb and fill the saved workshop-two doorway's left flank."""
import copy
import hashlib
import json
import math
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/art/workshop-short-curb-v1'


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + '.short-curb.tmp')
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent='\t') + '\n', encoding='utf-8')
    os.replace(temporary, path)


def main():
    manifest_path = ROOT / 'art/props/workshop_roads_v4/manifest.json'
    manifest_sha = sha(manifest_path)
    manifest = read(manifest_path)
    asset_id = 'workshop_road_curb_240_v4'
    assert not any(a['id'] == asset_id for a in manifest['assets'])
    asset = copy.deepcopy(next(a for a in manifest['assets'] if a['id'] == 'workshop_road_curb_600_v4'))
    width = math.ceil(1938 * 240 / 600)
    asset.update(id=asset_id, name='车间连接道路 · 短石条 240',
                 region=[24, 195, width, 80], world_size=[240, 20], render_size=[240, 20],
                 ground_rect=[0, 32, width, 48], footprint_world_size=[240, 12],
                 editor_hidden=False, runtime_size_limit=1024)
    manifest['assets'].append(asset)
    assert sha(manifest_path) == manifest_sha
    write(manifest_path, manifest)

    map_path = ROOT / 'data/rooms/r04.json'
    map_sha = sha(map_path)
    before = read(map_path)
    after = copy.deepcopy(before)
    fixture = dict(id='workshop-road-workshop-two-front-short-curb', asset_id=asset_id,
                   rect=[2280, 1746.38500976563, 240, 12], render_size=[240, 20],
                   blocks_movement=False, blocks_sight=False, exterior_shell=True,
                   draw_depth=0, workshop_short_curb_generated=True)
    assert not any(f['id'] == fixture['id'] for f in after['fixtures'])
    door = next(f for f in after['fixtures'] if f['id'] == 'campus-workshop-two-south')
    assert door['rect'][0] == 2520 and fixture['rect'][0] + fixture['rect'][2] == door['rect'][0]
    after['fixtures'].append(fixture)
    assert {k: v for k, v in before.items() if k != 'fixtures'} == {k: v for k, v in after.items() if k != 'fixtures'}
    assert after['fixtures'][:-1] == before['fixtures']
    assert sha(map_path) == map_sha, 'Map changed during preparation; retry against the new saved map.'
    write(OUT / 'before-map.json', before)
    write(map_path, after)
    write(OUT / 'registration.json', dict(asset_id=asset_id, fixture=fixture,
          prior_map_sha256=map_sha, saved_map_sha256=sha(map_path), width=240,
          source_png=asset['texture'], source_sha256=asset['sha256']))
    print('Registered visible 240-unit short curb and filled the doorway left flank; all saved content retained.')


if __name__ == '__main__':
    main()
