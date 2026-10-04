const {chromium}=require('C:/Users/gst20/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const path=require('path'),fs=require('fs');
(async()=>{
const browser=await chromium.launch({headless:true,channel:'msedge'});
const page=await browser.newPage({viewport:{width:960,height:540}});const errors=[];
page.on('pageerror',e=>errors.push(e.message));
await page.goto('file:///'+path.join(__dirname,'resource-preview-v01.html').replaceAll('\\','/'));
await page.waitForFunction(()=>window.artReady);
await page.evaluate(()=>document.fonts.ready);
const seen=new Set();for(let i=0;i<15;i++){seen.add(await page.locator('#actors').getAttribute('data-frame'));await page.waitForTimeout(70);}
if(!seen.has('1')||!seen.has('2'))throw new Error('Frames did not switch');
await page.locator('#toggle').click();const paused=await page.locator('#actors').getAttribute('data-frame');await page.waitForTimeout(400);
if(await page.locator('#actors').getAttribute('data-frame')!==paused)throw new Error('Pause failed');
const check=await page.evaluate(()=>({images:[...document.images].every(i=>i.complete&&i.naturalWidth>0),font:document.fonts.check('14px NotoCJK','这次怎么逃'),overflow:document.documentElement.scrollWidth>innerWidth,audio:[...document.querySelectorAll('audio')].map(a=>({duration:a.duration,readyState:a.readyState,loop:a.loop}))}));
if(!check.images||!check.font||check.overflow||check.audio.some(a=>!Number.isFinite(a.duration)))throw new Error(JSON.stringify(check));
await page.screenshot({path:path.join(__dirname,'qa-preview-960x540-v01.png'),fullPage:true});
await page.setViewportSize({width:1280,height:720});await page.screenshot({path:path.join(__dirname,'qa-preview-1280x720-v01.png'),fullPage:true});
if(errors.length)throw new Error(errors.join('\n'));
const report={viewport_checks:[[960,540],[1280,720]],frames:[...seen],pause:'passed',...check,errors,scope:'asset-preview only; not main-scene integration or human playtest',audition:'audio loaded; no claim of human listening',passed:true};
fs.writeFileSync(path.join(__dirname,'qa-browser-v01.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report));
await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
