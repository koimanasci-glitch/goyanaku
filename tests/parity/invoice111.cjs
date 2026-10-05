// B10: capture the final dormant invoice DOM; keep production purchase guards intact.
const assert=require('assert/strict'),fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'../..');
module.exports=async function captureInvoice(browser,write=false){
 const cases=[];
 const p=await browser.newPage({viewport:{width:390,height:844},timezoneId:'Asia/Jakarta'});
 try{for(const width of [390,320]){
  await p.setViewportSize({width,height:844});
  await p.clock.install({time:new Date('2026-10-05T01:00:00Z')});
  await p.addInitScript(()=>{window.GoyanaNative={__events:[],postMessage(raw){if(raw.startsWith('{"event"')){this.__events.push(raw);return}const m=JSON.parse(raw);setTimeout(()=>__goyanaNative.finish(m.id,true,m.method==='insets'?{top:31}:{}),5)}}});
  await p.goto(require('url').pathToFileURL(path.join(root,'mobile/assets/web/index.html')).href);await p.clock.runFor(3500);
  await p.evaluate(async faces=>{for(const face of faces){const font=new FontFace('Poppins','url(data:font/ttf;base64,'+face.data+')',{weight:face.weight});document.fonts.add(await font.load())}await document.fonts.ready},[['Regular','400'],['Medium','500'],['SemiBold','600']].map(([name,weight])=>({weight,data:fs.readFileSync(path.join(root,'mobile/assets/fonts/Poppins-'+name+'.ttf')).toString('base64')})));
  await p.evaluate(()=>{document.getElementById('ob189').hidden=true;openPage('invoice111')});await p.clock.runFor(400);
  assert.notEqual(await p.evaluate(()=>document.querySelector('.page.active').id),'invoice111','invoice remains blocked');
  assert.match(await p.locator('#toast90').textContent(),/Pembelian belum tersedia/);
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>e.classList.remove('show'));document.querySelectorAll('.page').forEach(e=>e.classList.toggle('active',e.id==='invoice111'))});await p.clock.runFor(400);
  const result=await p.evaluate(()=>{const event=GoyanaNative.__events.map(JSON.parse).filter(e=>e.page==='invoice111').at(-1);return {model:event.model.mirror,buttons:[...document.querySelectorAll('#invoice111 button')].map((b,i)=>({i,t:b.textContent.trim()}))}});
  assert.equal((await p.locator('#invoice111 .content').textContent()).trim(),'','no invoice has been created');
  const before=await p.evaluate(()=>JSON.stringify(localStorage));
  await p.evaluate(()=>__goyanaMirror('invoice111','button',1));await p.clock.runFor(400);
  assert.notEqual(await p.evaluate(()=>document.querySelector('.page.active').id),'invoice111');
  assert.equal(await p.evaluate(()=>JSON.stringify(localStorage)),before);
  cases.push({width,...result});
 }}finally{await p.close()}
 if(write){fs.writeFileSync(path.join(root,'mobile/test/fixtures/mirror_pages/invoice111.json'),JSON.stringify(cases[0].model,null,2)+'\n');fs.writeFileSync(path.join(root,'mobile/test/fixtures/parity/invoice111_cases.json'),JSON.stringify(cases)+'\n')}
 return cases;
};
if(require.main===module)(async()=>{const {chromium}=require('playwright');const b=await chromium.launch({headless:true,args:['--no-sandbox','--single-process','--no-zygote']});try{console.log((await module.exports(b,true)).map(c=>c.width))}finally{await b.close()}})().catch(e=>{console.error(e);process.exit(1)});
