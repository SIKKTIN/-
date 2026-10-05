"""Read original generated sheets and build isolated Atlas frames with shared scale.
No generated PNG pixels are edited, synthesized, interpolated or resampled.
"""
import json,hashlib,shutil
from pathlib import Path
from PIL import Image
import numpy as np
root=Path(__file__).resolve().parents[2];doc=root/'docs/art';out=root/'art/characters/walk_v09';out.mkdir(exist_ok=True)
data=json.loads((doc/'a07-image-inputs-v09.json').read_text(encoding='utf-8'))
old=json.loads((root/'art/characters/manifest-v03.json').read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
actors=[];qa=[];sources=[]
for n,e in enumerate(data['actors']):
    actor=old['actors'][n];source=Path(e['source']);target=out/e['filename']
    if target.exists()and sha(target)!=sha(source):raise RuntimeError('Refuse overwrite '+str(target))
    if not target.exists():shutil.copyfile(source,target)
    im=Image.open(target);a=np.asarray(im);assert im.mode=='RGBA'
    measurements=[]
    row_counts=(a[:,:,3]>32).sum(axis=1)
    candidates=[j for j in range(int(im.height*.4),int(im.height*.6)) if row_counts[j]==0]
    assert candidates,'No transparent separator between pose rows'
    separator=min(candidates,key=lambda j:abs(j-im.height/2))
    for i in range(8):
        row,col=divmod(i,4);x0=int(col*im.width/4);x1=int((col+1)*im.width/4);y0=0 if row==0 else separator;y1=separator if row==0 else im.height
        cell=a[y0:y1,x0:x1];mask=cell[:,:,3]>32;yy,xx=np.where(mask)
        assert xx.size,i
        bx0=x0+int(xx.min());bx1=x0+int(xx.max())+1;by0=y0+int(yy.min());by1=y0+int(yy.max())+1
        height=by1-by0
        head=a[by0:by0+int(height*.30),bx0:bx1,3]>128
        hy,hx=np.where(head);head_x=(int(hx.min())+int(hx.max())+1)/2+bx0
        # Whole-source integer shifts in Atlas region register a stable head/foot axis.
        root_x=int(round(head_x));foot_y=by1
        measurements.append({'id':f'walk_{i}','cell':[x0,y0,x1-x0,y1-y0],'opaque_canvas_bounds':[bx0,by0,bx1-bx0,by1-by0],'body_height_px':height,'head_width_px':int(hx.max()-hx.min()+1),'head_root_x':root_x,'foot_y':foot_y,'left_extent':root_x-bx0,'right_extent':bx1-root_x,'nominal_cell_core_pixels':int(mask.sum())})
    left=max(m['left_extent']for m in measurements)+6;right=max(m['right_extent']for m in measurements)+6
    hmax=max(m['body_height_px']for m in measurements);w=left+right;h=hmax+12;anchor=[left,h-6]
    median_h=float(np.median([m['body_height_px']for m in measurements]))
    idle=actor['frames']['idle'];opaque=actor['opaque_bounds']['idle'];target_visible=actor['world_height']*opaque[3]/idle[3]
    cell_world_height=target_visible*h/median_h
    frames=[];mask_hashes=[];leg_masks=[]
    for m in measurements:
        cell=m['cell'];bx,by,bw,bh=m['opaque_canvas_bounds']
        x=max(cell[0],bx-6);y=max(cell[1],by-6)
        rw=min(cell[0]+cell[2],bx+bw+6)-x;rh=min(cell[1]+cell[3],by+bh+6)-y
        frame_anchor=[m['head_root_x']-x,m['foot_y']-y];region=[x,y,rw,rh]
        valid=x>=0 and y>=0 and x+rw<=im.width and y+rh<=im.height
        within_cell=x>=cell[0] and y>=cell[1] and x+rw<=cell[0]+cell[2] and y+rh<=cell[1]+cell[3]
        assert valid,(e['id'],m['id'],region)
        body=(a[y:y+rh,x:x+rw,3]>32)
        assert body.shape==(rh,rw)
        yy,xx=np.indices(body.shape)
        outside=(xx+x<cell[0])|(xx+x>=cell[0]+cell[2])|(yy+y<cell[1])|(yy+y>=cell[1]+cell[3])
        outside_core=int((body&outside).sum())
        actual_core=int(body.sum())
        isolated=outside_core==0 and actual_core==m['nominal_cell_core_pixels']
        # Analysis-only masks registered to a common foot origin; never saved as artwork.
        registered=np.zeros((h,w),dtype=bool)
        ax=anchor[0]-(m['head_root_x']-bx);ay=anchor[1]-bh
        registered[ay:ay+bh,ax:ax+bw]=a[by:by+bh,bx:bx+bw,3]>32
        lower=registered[int(h*.55):]
        mask_hashes.append(hashlib.sha256(lower.tobytes()).hexdigest());leg_masks.append(lower)
        m.update({'region':region,'anchor':frame_anchor,'region_valid':valid,'inside_regular_cell':within_cell,'outside_nominal_cell_core_pixels':outside_core,'actual_region_core_pixels':actual_core,'own_pose_core_pixel_count_equal':actual_core==m['nominal_cell_core_pixels'],'neighbor_pose_isolated':isolated,'visible_world_height':m['body_height_px']*cell_world_height/h,'head_world_width':m['head_width_px']*cell_world_height/h,'head_top_world_y':(m['opaque_canvas_bounds'][1]-y-frame_anchor[1])*cell_world_height/h,'foot_world_error':0})
        frames.append({'id':m['id'],'region':region,'anchor':frame_anchor})
    changes=[]
    for i in range(8):
        z=(i+1)%8;diff=np.logical_xor(leg_masks[i],leg_masks[z]).sum();union=np.logical_or(leg_masks[i],leg_masks[z]).sum()
        changes.append({'from':i,'to':z,'lower_silhouette_changed_fraction':round(float(diff/max(1,union)),4)})
    heights=[m['visible_world_height']for m in measurements];head=[m['head_world_width']for m in measurements]
    ratio=(max(heights)-min(heights))/float(np.median(heights));head_ratio=(max(head)-min(head))/float(np.median(head))
    walk={'texture':'res://'+target.relative_to(root).as_posix(),'texture_size':list(im.size),'fps':12,'scale_height':round(h*actor['world_height']/cell_world_height,8),'region_policy':'individual clean regions; draw every frame with world_height / scale_height, never divide by region height','registration_origin':'head-center axis at lowest opaque foot; per-frame source anchor maps to common world origin','row_separator':separator,'frames':frames,'shadow_baked':False,'direction':'right','cycle_seconds':8/12,'sha256':sha(target)}
    actors.append({'actor_id':actor['actor_id'],'world_height':actor['world_height'],'walk_animation':walk})
    report={'actor_id':actor['actor_id'],'texture':walk['texture'],'copy_matches_original':sha(source)==sha(target),'mode':im.mode,'source_size':list(im.size),'body_height_spread_fraction':round(ratio,4),'head_width_spread_fraction':round(head_ratio,4),'legacy_idle_visible_world_height':target_visible,'new_median_visible_world_height':float(np.median(heights)),'distinct_lower_silhouettes':len(set(mask_hashes)),'neighbor_lower_silhouette_changes':changes,'frames':measurements,'passed':sha(source)==sha(target)and len(set(mask_hashes))==8 and ratio<=.06 and head_ratio<=.08 and all(m['neighbor_pose_isolated']for m in measurements)}
    qa.append(report)
    sources.append({'actor_id':actor['actor_id'],'source_png':str(source),'project_png':target.relative_to(root).as_posix(),'sha256':sha(target),'original_copy_matches':sha(source)==sha(target),'reference':actor['texture'],'prompt_index':e.get('prompt_index',n),'initial_source':e.get('initial_source'),'correction_prompt':e.get('correction_prompt')})
write(root/'art/characters/manifest-v09.json',{'schema':1,'version':'walk-art-v09-20261005','actors':actors,'idle_policy':'keep original manifest-v03 idle; this manifest only supplies walk-animation override'})
oldbase=json.loads((doc/'a07-old-assets-v09.json').read_text(encoding='utf-8'))['files'];changed=[b['path']for b in oldbase if sha(root/b['path'])!=b['sha256']]
write(doc/'a07-qa-resources-v09.json',{'actors':qa,'old_assets_checked':len(oldbase),'changed_old_assets':changed,'passed':all(q['passed']for q in qa)and not changed,'scope':'per-frame clean regions/shared scale/foot metadata and lower-mask distinction; actual pose order/identity/loop visually reviewed separately'})
write(doc/'a07-source-license-v09.json',{'schema':1,'mode':'built-in imagegen','pixel_policy':'original generated PNGs copied byte-identically; regions/register metadata only; no generated pose interpolation','license':'Project-owned generated artwork, only project-owned character references','prompts':'docs/art/a07-imagegen-prompts-v09.json','correction_prompts':'docs/art/a07-imagegen-corrections-v09.json','sources':sources})
print(json.dumps({'actors':[{k:q[k]for k in ['actor_id','body_height_spread_fraction','head_width_spread_fraction','distinct_lower_silhouettes','passed']}for q in qa],'changed_old_assets':changed}))
