const fs=require('fs');
const path=require('path');
const sharp=require('C:/Users/gst20/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root='E:/Project/Godot/这次怎么逃';
const ink='#303b46',paper='#f2ebdd',sage='#a6b2a3',teal='#328b82',wood='#bc965a',purple='#9a8fb9',red='#c9534b',amber='#d9ac54';
const defs=[];
function add(folder,id,w,h,body,extra={}){defs.push({folder,id,w,h,body,...extra});}
function svg(w,h,body){return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"><g stroke-linecap="round" stroke-linejoin="round">${body}</g></svg>`;}
add('art/environment','floor_tile_v01',128,128,`<rect width="128" height="128" fill="${sage}"/><path d="M0 64H128M64 0V128" stroke="${ink}" opacity=".07"/><path d="M8 13h10m78 90h12" stroke="${paper}" opacity=".13"/>`,{world_size:[40,40],opaque:true,tileable:true});
add('art/environment','low_wall_v01',128,128,`<rect x="3" y="3" width="122" height="122" rx="3" fill="${ink}"/><rect x="8" y="8" width="112" height="99" fill="#b4b8aa"/><rect x="8" y="107" width="112" height="13" fill="#7f8e83"/><path d="M8 54h112M43 9v44m43 1v52M26 24h14m59 46h10" fill="none" stroke="${ink}" stroke-width="2" opacity=".3"/>`,{anchor:[64,64],fit_to_logic_rect:true,blocking_visual_only:true});
const jamb=`<path d="M5 4v248M59 4v248" stroke="${ink}" stroke-width="10"/><path d="M7 8v240M57 8v240" stroke="#8b988d" stroke-width="3"/>`;
add('art/props','locked_door_closed_v01',64,256,`${jamb}<rect x="11" y="6" width="42" height="244" fill="#c5cebf" stroke="${ink}" stroke-width="3"/><path d="M20 10v236M32 10v236M44 10v236M12 49h40m-40 79h40m-40 79h40" fill="none" stroke="${ink}" stroke-width="3"/><rect x="21" y="112" width="23" height="27" rx="3" fill="${wood}" stroke="${ink}" stroke-width="3"/><path d="M27 112v-8q6-12 12 0v8" fill="none" stroke="${ink}" stroke-width="4"/><circle cx="33" cy="122" r="3" fill="${ink}"/><path d="M33 122v8" stroke="${ink}" stroke-width="3"/>`,{anchor:[32,128],world_size:[22,120],state:'closed',fit_to_logic_rect:true});
add('art/props','locked_door_open_v01',64,256,`${jamb}<path d="M14 8v240" stroke="#8b988d" stroke-width="5"/>`,{anchor:[32,128],world_size:[22,120],state:'open',fit_to_logic_rect:true});
add('art/props','heavy_crate_v01',128,128,`<rect x="3" y="3" width="122" height="122" rx="4" fill="${wood}" stroke="${ink}" stroke-width="6"/><path d="M6 17h116M6 110h116M20 7v115M108 7v115" stroke="#8d6d43" stroke-width="9"/><path d="M29 9v109M53 9v109M77 9v109M100 9v109" stroke="${ink}" stroke-width="2" opacity=".32"/><path d="M12 18l103 91" stroke="#d7b77c" stroke-width="13"/><path d="M14 21l99 85" stroke="${ink}" stroke-width="2"/><g fill="${ink}"><circle cx="13" cy="13" r="3"/><circle cx="115" cy="13" r="3"/><circle cx="13" cy="115" r="3"/><circle cx="115" cy="115" r="3"/></g>`,{anchor:[64,64],world_size:[94,92],fit_to_logic_rect:true});
add('art/props','exit_v01',128,128,`<rect x="4" y="4" width="120" height="120" rx="8" fill="${paper}" stroke="${teal}" stroke-width="5"/><path d="M19 46h49V25l41 39-41 39V82H19Z" fill="${teal}"/>`,{anchor:[64,64],world_size:[56,56],purpose:'exit-sign-inside-exit-zone'});
add('art/ui','paper_card_v01',384,160,`<rect x="3" y="3" width="378" height="154" rx="5" fill="${paper}" stroke="#9eaa9d" stroke-width="3"/><path d="M15 18h354M15 143h354" stroke="${ink}" opacity=".08"/>`,{nine_patch_margins:[12,12,12,12],text_baked:false});
const outline=(body)=>`<g fill="none" stroke="${ink}" stroke-width="8">${body}</g>`;
add('art/ui','skill_chat_v01',128,128,outline('<path d="M22 91l-5 23 29-17q42 10 61-18t-1-43Q90 16 58 17T16 40q-12 24 6 51Z"/>')+`<g fill="${ink}"><circle cx="41" cy="59" r="6"/><circle cx="64" cy="59" r="6"/><circle cx="87" cy="59" r="6"/></g>`,{display_sizes:[24,32],skill_id:'chat'});
add('art/ui','skill_lockpick_v01',128,128,outline('<rect x="15" y="58" width="58" height="50" rx="5"/><path d="M27 58V42c0-28 35-28 35 0v16M91 107V35l-11-16h-18"/>')+`<circle cx="44" cy="78" r="7" fill="${ink}"/><path d="M44 78v16" stroke="${ink}" stroke-width="7"/>`,{display_sizes:[24,32],skill_id:'lockpick'});
add('art/ui','skill_strong_v01',128,128,outline('<rect x="79" y="36" width="35" height="67" rx="2"/><path d="M81 53h31M90 37v65M18 98V62c0-8 9-11 14-4V31c0-10 13-10 13 0v-4c0-9 13-9 13 0v6c0-9 13-9 13 0v41q0 26-22 26H18Z"/>'),{display_sizes:[24,32],skill_id:'strong'});
add('art/fx','selected_v01',128,128,`<path d="M6 36V8h28m60 0h28v28m0 57v27H94m-61 0H6V93" fill="none" stroke="${teal}" stroke-width="9"/>`,{selected_only:true,display_sizes:[24,32]});
add('art/fx','detected_v01',128,128,`<path d="M64 8 119 114H9Z" fill="${paper}" stroke="${red}" stroke-width="8"/><path d="M64 40v36" stroke="${red}" stroke-width="10"/><circle cx="64" cy="94" r="6" fill="${red}"/>`,{display_sizes:[24,32],instantaneous:true});
add('art/fx','searching_v01',128,128,`<path d="M33 33c2-31 69-34 69 3 0 27-34 26-34 50" fill="none" stroke="${amber}" stroke-width="11"/><circle cx="68" cy="108" r="7" fill="${amber}"/>`,{display_sizes:[24,32]});
add('art/fx','escaped_v01',128,128,`<circle cx="64" cy="64" r="55" fill="${paper}" stroke="${teal}" stroke-width="7"/><path d="m31 65 23 23 44-47" fill="none" stroke="${teal}" stroke-width="11"/>`,{display_sizes:[24,32]});
add('art/fx','captured_v01',128,128,`<path d="M38 91H27V21h40v31M48 69h29c40 0 38 42 10 42H63" fill="none" stroke="${red}" stroke-width="9"/><path d="m49 47-22 22 22 21" fill="none" stroke="${red}" stroke-width="9"/>`,{display_sizes:[24,32]});
add('art/fx','cancelled_v01',128,128,`<circle cx="64" cy="64" r="53" fill="${paper}" stroke="${red}" stroke-width="7"/><path d="m42 42 44 44m0-44L42 86" stroke="${red}" stroke-width="9"/>`,{display_sizes:[24,32]});
(async()=>{
 const manifest=[];
 for(const d of defs){
   const folder=path.join(root,d.folder);fs.mkdirSync(folder,{recursive:true});
   const sourcePath=path.join(folder,d.id+'.svg'),targetPath=path.join(folder,d.id+'.png');
   if(fs.existsSync(sourcePath)||fs.existsSync(targetPath))throw new Error('Existing asset '+d.id);
   fs.writeFileSync(sourcePath,svg(d.w,d.h,d.body));
   await sharp(Buffer.from(svg(d.w,d.h,d.body))).png().toFile(targetPath);
   const {body,...meta}=d;manifest.push({...meta,source:`res://${d.folder}/${d.id}.svg`,texture:`res://${d.folder}/${d.id}.png`,source_kind:'original-vector-authored',license:'Project-owned original artwork; no external art'});
 }
 for(const folder of ['art/environment','art/props','art/ui','art/fx']){
   const assets=manifest.filter(a=>a.folder===folder);
   fs.writeFileSync(path.join(root,folder,'manifest.json'),JSON.stringify({schema:1,assets},null,2));
 }
 console.log(JSON.stringify({assets:manifest.length,source:'original SVG; PNG rendered without character image edits'}));
})().catch(e=>{console.error(e);process.exit(1)});
