const {chromium}=require('C:/Users/gst20/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const {pathToFileURL}=require('url');
(async()=>{
 const base=__dirname;
 const browser=await chromium.launch({channel:'msedge',headless:true});
 const page=await browser.newPage({viewport:{width:1430,height:1000},deviceScaleFactor:1});
 const errors=[];
 page.on('pageerror',e=>errors.push(String(e)));
 await page.goto(pathToFileURL(base+'/scale-preview.html').href);
 await page.evaluate(async()=>{await document.fonts.ready; const imgs=Array.from(document.querySelectorAll('.sprite')).map(el=>getComputedStyle(el).backgroundImage.match(/url\(["']?(.*?)["']?\)/)?.[1]).filter(Boolean); await Promise.all([...new Set(imgs)].map(src=>new Promise((resolve,reject)=>{const im=new Image(); im.onload=resolve;im.onerror=()=>reject(new Error(src));im.src=src;})));});
 await page.screenshot({path:base+'/scale-preview.png',fullPage:true});
 require('fs').writeFileSync(base+'/preview-qa.json',JSON.stringify({browser:'headless Edge',errors,screenshot:'scale-preview.png',passed:errors.length===0},null,2));
 await browser.close();
 if(errors.length)process.exitCode=1;
})();
