"""Align fixed R04 props with the shared human-relative scale, retaining foot anchors."""
import argparse
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    settings = json.loads((ROOT/'data/presentation/prop_proportions.json').read_text(encoding='utf-8'))
    catalog = (ROOT/'scripts/presentation/prop_catalog.gd').read_text(encoding='utf-8')
    assets = {}
    for path in re.findall(r'"res://([^"]+manifest\.json)"', catalog):
        assets.update({a['id']: a for a in json.loads((ROOT/path).read_text(encoding='utf-8')).get('assets', [])})
    path = ROOT/'data/rooms/r04.json'
    data = json.loads(path.read_text(encoding='utf-8'))
    changes = []
    # Uniform table ground depth restores the full bench footprint. Keep
    # the central dining aisle usable without moving assigned seat targets.
    layout_adjustments = []
    if data.get('prop_proportions_layout_version', 0) < 1:
        for fixture in data['fixtures']:
            if fixture.get('id') in ['dine-table-2', 'dine-table-3', 'dine-tray-2', 'dine-tray-3']:
                fixture['rect'][1] += 32
                if 'draw_depth' in fixture: fixture['draw_depth'] += 32
                layout_adjustments.append(dict(id=fixture['id'], offset=[0, 32]))
        data['prop_proportions_layout_version'] = 1
    if data.get('prop_proportions_layout_version', 0) < 2:
        for fixture in data['fixtures']:
            if fixture['asset_id'] == 'bunk_bed_v42':
                fixture['rect'][1] -= 45
                layout_adjustments.append(dict(id=fixture.get('id'), offset=[0, -45]))
        data['prop_proportions_layout_version'] = 2
    for fixture in data['fixtures']:
        asset_id = fixture['asset_id']
        if asset_id not in settings['widths_at_reference']: continue
        asset = assets[asset_id]
        region = asset.get('region', [])
        source = region[2:] if region else asset['texture_size']
        scalar = settings['widths_at_reference'][asset_id]/source[0]
        ground = asset['ground_rect']
        old = fixture['rect'][:]
        width, depth = ground[2]*scalar, ground[3]*scalar
        # Bottom-centre is the registered ground origin; doors, walls,
        # activity targets and character proportions are not moved.
        new = [round(old[0]+old[2]/2-width/2, 4), round(old[1]+old[3]-depth, 4), round(width, 4), round(depth, 4)]
        if new != old or 'render_size' in fixture:
            changes.append(dict(id=fixture.get('id'), asset_id=asset_id, before=old, after=new,
                                old_render_size=fixture.get('render_size')))
            fixture['rect'] = new
            fixture.pop('render_size', None)
    report = dict(baseline_commit=subprocess.check_output(['git', 'rev-parse', '--short', 'HEAD'], cwd=ROOT, text=True).strip(),
                  reference_human_height=settings['reference_human_height'], calibrated_asset_types=len(settings['widths_at_reference']),
                  adjusted_instances=len(changes), applied=args.apply, layout_adjustments=layout_adjustments, changes=changes)
    if args.apply:
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
        output = ROOT/'docs/dev/p116/migration.json'
        output.parent.mkdir(parents=True, exist_ok=True)
        previous = json.loads(output.read_text(encoding='utf-8')) if output.exists() else {}
        baseline = previous.get('baseline_commit', report['baseline_commit'])
        original = json.loads(subprocess.check_output(['git', 'show', baseline+':data/rooms/r04.json'], cwd=ROOT, encoding='utf-8'))
        by_id = {f.get('id'): f for f in original['fixtures']}
        cumulative = []
        for fixture in data['fixtures']:
            before = by_id.get(fixture.get('id'), {})
            if fixture['asset_id'] in settings['widths_at_reference'] and (before.get('rect') != fixture['rect'] or 'render_size' in before):
                cumulative.append(dict(id=fixture.get('id'), asset_id=fixture['asset_id'], before=before.get('rect'), after=fixture['rect'], old_render_size=before.get('render_size')))
        history = previous.get('layout_adjustments', []) + layout_adjustments
        saved = dict(report, baseline_commit=baseline, adjusted_instances=len(cumulative), changes=cumulative, layout_adjustments=history)
        output.write_text(json.dumps(saved, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k!='changes'}, ensure_ascii=False))

if __name__ == '__main__': main()
