"""Resize only the clinic, retaining the campus's other authored wall tiles."""
from copy import deepcopy

AREA = [1520, 420, 520, 500]

def contains_wall(area, rect):
    x,y,w,h = area
    rx,ry,rw,rh = rect
    return x-20 <= rx and y-120 <= ry and rx+rw <= x+w+20 and ry+rh <= y+h+40

def compact(room):
    previous = next(r['rect'] for r in room['visibility_rooms'] if r['id']=='clinic')
    selected = {i for i,r in enumerate(room['walls']) if contains_wall(previous,r)}
    surfaces = {s['wall_index']:s for s in room['architecture']['wall_surfaces']}
    templates = {}
    for i in selected:
        s=deepcopy(surfaces[i])
        base=s.pop('clinic_base_asset',s['grid_tile_asset'])
        s['grid_tile_asset']=base
        templates[base]=s
    assert selected and all(k in templates for k in ['prison_l_se','prison_l_sw','prison_l_ne','prison_l_nw','prison_v_long','prison_v_short','prison_lintel_80','prison_lintel_20','prison_h_c','prison_h_short_c'])
    retained = []
    remap = {}
    for i,r in enumerate(room['walls']):
        if i not in selected:
            remap[i] = len(retained)
            retained.append(r)
    retained_surfaces = []
    for s in room['architecture']['wall_surfaces']:
        if s['wall_index'] in remap:
            s=deepcopy(s)
            s['wall_index']=remap[s['wall_index']]
            retained_surfaces.append(s)
    def tile(asset,x,y,w,h):
        s=deepcopy(templates[asset])
        s['wall_index']=len(retained)
        if asset.startswith('prison_v_'): s['collision_parts']=[[0,0,w,h]]
        retained.append([x,y,w,h])
        retained_surfaces.append(s)
    tile('prison_l_se',1500,300,40,120)
    for x in range(1540,2020,40): tile('prison_h_c',x,300,40,120)
    tile('prison_l_sw',2020,300,40,120)
    tile('prison_l_ne',1500,820,40,140)
    for x in [1540,1580,1620,1660,1880,1920,1960]: tile('prison_h_c',x,840,40,120)
    tile('prison_lintel_80',1700,840,80,20)
    tile('prison_lintel_80',1780,840,80,20)
    tile('prison_lintel_20',1860,840,20,20)
    tile('prison_h_short_c',2000,840,20,120)
    tile('prison_l_nw',2020,820,40,140)
    for x in [1500,2040]:
        for y in [420,540,660]: tile('prison_v_long',x,y,20,120)
        tile('prison_v_short',x,780,20,40)
    room['walls']=retained
    room['architecture']['wall_surfaces']=retained_surfaces
    for group in ['zones','visibility_rooms']:
        next(r for r in room[group] if r['id']=='clinic')['rect']=AREA.copy()
    # The room plaque identifies the clinic without a floating label over the counter.
    next(r for r in room['zones'] if r['id']=='clinic')['hide_label']=True
    for s in room['concept_plan']['horizontal']:
        if s['id']=='clinic-north': s.update(x1=2060)
        if s['id']=='clinic-south': s.update(x1=2060,y=940,gaps=[[1700,1880]])
    for s in room['concept_plan']['vertical']:
        if s['id']=='clinic-west': s.update(y1=940)
        if s['id']=='clinic-east': s.update(x=2040,y1=940)
    next(f for f in room['fixtures'] if f['id']=='campus-clinic')['rect']=[1700,940,180,20]
    room['clinic_compact_version']=1
