import copy

def remodel(a):
    # Existing workshop north/side walls and all workstations stay in place.
    left=next(i for i,r in enumerate(a['walls']) if r==[720,140,24,440])
    a['walls'][left]=[720,140,24,660]
    right=next(i for i,r in enumerate(a['walls']) if r==[2000,140,24,660])
    top=next(i for i,r in enumerate(a['walls']) if r==[720,140,1304,24])
    bottom=[]
    for r in [[720,800,380,24],[1280,800,744,24]]:
        bottom.append(len(a['walls']));a['walls'].append(r)
    surfaces=a.setdefault('architecture',{}).setdefault('wall_surfaces',[])
    surfaces[:]=[s for s in surfaces if s['wall_index'] not in [left,right,top]]
    for i in [top]+bottom:
        surfaces.append({'wall_index':i,'height':90,'front':'cafeteria_wall_mid_v33','top':'cafeteria_wall_mid_v33','painted_facade':{'layout':'tiled','asset':'cafeteria_wall_mid_v33'},'alpha_shader':'res://art/architecture/v25/safe_edges_v25.gdshader'})
    for i,asset in [(left,'cafeteria_wall_v_l_v33'),(right,'cafeteria_wall_v_r_v33')]:
        surfaces.append({'wall_index':i,'height':90,'top':asset,'front':'cafeteria_end_v33','return_wall':{'top':asset,'end':'cafeteria_end_v33','tile_size':[24,189.14594594594593],'tile_origin_y':140,'mirror_x':False},'alpha_shader':'res://art/architecture/v25/safe_edges_v25.gdshader'})
    a['access_doors'].append({'id':'workshop-entry','name':'生产车间门禁','kind':'workshop','rect':[1100,800,180,24],'initial_closed':False,'blocks_sight':False})
    a['fixtures'].append({'id':'workshop-door-visual','asset_id':'cafeteria_gate_closed_v23','rect':[1100,800,180,24],'blocks_movement':False,'blocks_sight':False,'access_id':'workshop-entry','closed_asset':'cafeteria_gate_closed_v23','open_asset':'cafeteria_gate_open_v23','render_size':[180,100],'alpha_shader':'res://art/architecture/v25/safe_edges_v25.gdshader'})
    a['workshop']={'room_rect':[744,164,1256,636],'access_id':'workshop-entry','arrival_minutes':60,'warning_seconds':8,'overseer_start':[1040,420],'patrol':[[1040,350],[1040,600],[1440,600],[1800,340],[1440,340]]}
    for merchant in a.get('merchants',[]):
        for activity in merchant.get('routine',[]):
            if activity.get('kind') == 'work': activity['position']=[1700,610]
    return a
