const fs=require('fs'),path=require('path'),crypto=require('crypto');
const sharp=require('C:/Users/gst20/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const ROOT='E:/Project/Godot/这次怎么逃';
const sha=p=>crypto.createHash('sha256').update(fs.readFileSync(path.join(ROOT,p))).digest('hex');
async function main(){
 const d=JSON.parse(fs.readFileSync(path.join(ROOT,'docs/art/delivery-v02.json')));
 const inventory=d.files.map(f=>({path:f.path,hash_match:sha(f.path)===f.sha256}));
 const images=[];
 for(const a of d.assets){const m=await sharp(path.join(ROOT,a.folder,a.id+'.png')).metadata();const result={id:a.id,width:m.width,height:m.height,alpha:m.hasAlpha,dimensions_match:m.width===a.w&&m.height===a.h};if(a.ground_rect){const [x,y,w,h]=a.ground_rect;const [ww,hh]=a.world_size;const ground=[w/a.w*ww,h/a.h*hh];const offset=[-x/a.w*ww,-y/a.h*hh];result.ground_world=ground;result.ground_matches=ground.every((v,i)=>Math.abs(v-a.footprint_world_size[i])<1e-6);result.offset_matches=offset.every((v,i)=>Math.abs(v-a.visual_offset_from_ground_rect[i])<1e-6);}images.push(result);}
 const old=JSON.parse(fs.readFileSync(path.join(ROOT,'docs/art/delivery-v01.json')));
 const original=old.files.filter(f=>f.path.startsWith('art/characters/')&&f.path.endsWith('.png')).map(f=>({path:f.path,unchanged:sha(f.path)===f.sha256}));
 const current=JSON.parse(fs.readFileSync(path.join(ROOT,'art/characters/manifest.json')));
 const resized=JSON.parse(fs.readFileSync(path.join(ROOT,'art/characters/manifest-v02.json')));
 const actors=resized.actors.map((a,i)=>({actor_id:a.actor_id,height:a.world_height,frames_unchanged:JSON.stringify(a.frames)===JSON.stringify(current.actors[i].frames),anchors_unchanged:JSON.stringify(a.anchor)===JSON.stringify(current.actors[i].anchor),texture_unchanged:a.texture===current.actors[i].texture}));
 const passed=inventory.every(f=>f.hash_match)&&images.every(i=>i.dimensions_match&&(i.ground_matches??true)&&(i.offset_matches??true))&&original.length===4&&original.every(f=>f.unchanged)&&actors.every(a=>a.frames_unchanged&&a.anchors_unchanged&&a.texture_unchanged);
 const report={version:d.version,inventory,images,original_characters:original,actors,passed,scope:'asset hashes, image metadata, footprint registration and original character preservation only'};
 fs.writeFileSync(path.join(ROOT,'docs/art/qa-resources-v02.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({version:d.version,files:inventory.length,images:images.length,characters:original.length,passed}));if(!passed)process.exitCode=1;
}
main().catch(e=>{console.error(e);process.exit(1)});
