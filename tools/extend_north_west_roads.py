"""Extend the marked dorm/chess/clinic streets without changing saved room geometry."""
from copy import deepcopy
from math import ceil
from tools.register_valve_maintenance import ROOT, read, write, sha

DOC = ROOT / 'docs/art/north-west-roads-v5'
ART = ROOT / 'art/props/north_west_roads_v5'
MANIFEST = 'res://art/props/north_west_roads_v5/manifest.json'
OWNER = 'north_west_roads_generated'


def restore():
    path = ROOT / 'data/rooms/r04.json'
    disk = sha(path)
    before = read(path)
    after = deepcopy(before)
    assert not any(f.get(OWNER) for f in before['fixtures'])
    assets, definitions, added = [], {}, []
    original = read(ROOT / 'art/props/workshop_roads_v4/manifest.json')['assets'][0]

    def asset(length):
        if length in definitions:
            return definitions[length]
        a = deepcopy(original)
        width = ceil(1938 * length / 600)
        a.update(id=f'north_west_road_curb_{length}_v5',
                 name=f'宿舍北侧连接道路 · 石质路缘 {length}',
                 region=[24, 195, width, 80], world_size=[length, 20], render_size=[length, 20],
                 footprint_world_size=[length, 12], ground_rect=[0, 32, width, 48],
                 runtime_size_limit=2048, editor_hidden=length not in [600, 240])
        assets.append(a)
        definitions[length] = a['id']
        return a['id']

    def curb(key, x, y, length, turn=0):
        offset = 0
        while offset < length:
            part = min(600, length - offset)
            f = dict(id=f'north-west-road-{key}-{offset}', asset_id=asset(part),
                     rect=[x, y + offset, 12, part] if turn % 2 else [x + offset, y, part, 12],
                     render_size=[part, 20], rotation_quarters=turn, draw_depth=0,
                     blocks_movement=False, blocks_sight=False, exterior_shell=True)
            f[OWNER] = True
            after['fixtures'].append(f)
            added.append(f['id'])
            offset += part

    paving = dict(asset_id='loading_floor_v1', manifest='res://art/environment/loading_yard_v1/manifest.json',
                  tile_size=[240, 240], tile_origin=[2140, 3980], natural_ground=False)
    paving[OWNER] = True
    floors = []
    for key, rect in [('chess-west-spine', [700, 200, 200, 620]),
                      ('workshop-west-spine', [700, 820, 180, 1000]),
                      ('clinic-entry-apron', [1500, 760, 560, 60])]:
        f = dict(paving, id='north-west-road-' + key, rect=rect)
        after['floor_regions'].append(f)
        floors.append(f['id'])

    # Leave each west dorm/reading doorway clear, including the actual saved door widths.
    doors = [f['rect'] for f in before['fixtures']
             if f['id'] in ['reading-room-entry', 'campus-dorm-extra-1', 'campus-dorm-extra-2']]
    doors += [f['rect'] for f in before['dorm_doors'] if f['rect'][1] < 1820]
    cursor = 200
    for r in sorted(doors, key=lambda r: r[1]):
        if r[1] > cursor:
            curb('dorm-edge-' + str(cursor), 700, cursor, r[1] - cursor, 1)
        cursor = max(cursor, r[1] + r[3])
    if cursor < 1820:
        curb('dorm-edge-' + str(cursor), 700, cursor, 1820 - cursor, 1)

    curb('chess-west-edge', 888, 200, 620, 3)
    curb('chess-front-left', 880, 828, 260)
    curb('chess-front-right', 1300, 828, 200)
    # Raised clinic frontage turns north while preserving the sliding-door approach.
    curb('clinic-west-turn', 1488, 768, 60, 1)
    curb('clinic-front-left', 1500, 768, 200)
    curb('clinic-front-right', 1880, 768, 180)
    curb('clinic-east-turn', 2048, 768, 60, 1)
    curb('workshop-north-edge', 868, 932, 1252)
    curb('workshop-west-edge', 868, 944, 756, 3)
    asset(240)  # Keep a reusable short variant in the editor palette.

    assert before['fixtures'] == [f for f in after['fixtures'] if not f.get(OWNER)]
    assert before['floor_regions'] == [f for f in after['floor_regions'] if not f.get(OWNER)]
    assert {k: v for k, v in before.items() if k not in ['fixtures', 'floor_regions']} == \
           {k: v for k, v in after.items() if k not in ['fixtures', 'floor_regions']}
    write(ART / 'manifest.json', dict(schema=2, version='north-west-roads-v5', assets=assets))
    catalog = ROOT / 'scripts/presentation/prop_catalog.gd'
    text = catalog.read_text(encoding='utf-8')
    entry = '\t"' + MANIFEST + '",\n'
    if entry.strip() not in text:
        catalog.write_text(text.replace('\n]\n', '\n' + entry + ']\n', 1), encoding='utf-8')
    assert sha(path) == disk, 'Map changed while preparing streets; reread the saved map.'
    write(DOC / 'before-map.json', before)
    write(path, after)
    write(DOC / 'registration.json', dict(added_floor_ids=floors, added_fixture_ids=added,
          door_gaps=doors, paving_rects=[f['rect'] for f in after['floor_regions'] if f.get(OWNER)],
          new_blocking_objects=False, source_png=original['texture'], source_sha256=original['sha256'],
          saved_map_sha256=sha(path)))
    print(f'Added {len(floors)} paving regions and {len(added)} editable stone curb pieces; all saved objects retained.')


if __name__ == '__main__':
    restore()
