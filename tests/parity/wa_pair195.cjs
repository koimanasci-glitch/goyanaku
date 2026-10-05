const assert=require('assert/strict'),fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'../..');
module.exports=async function capture(browser,write=false){
 const cases=[],p=await browser.newPage({viewport:{width:390,height:844},timezoneId:'Asia/Jakarta'});
 try{
 await p.clock.install({time:new Date('2026-10-05T01:00:00Z')});
 await p.addInitScript(()=>{window.GoyanaNative={__events:[],postMessage(raw){if(raw.startsWith('{"event"')){this.__events.push(raw);return}const m=JSON.parse(raw);setTimeout(()=>__goyanaNative.finish(m.id,true,m.method==='insets'?{top:31}:{}),5)}}});
 for(const width of [390,320]){
 await p.setViewportSize({width,height:844});
 await p.goto(require('url').pathToFileURL(path.join(root,'mobile/assets/web/index.html')).href);await p.clock.runFor(3500);
 await p.evaluate(async faces=>{for(const face of faces){const font=new FontFace('Poppins','url(data:font/ttf;base64,'+face.data+')',{weight:face.weight});document.fonts.add(await font.load())}await document.fonts.ready},[['Regular','400'],['Medium','500'],['SemiBold','600']].map(([name,weight])=>({weight,data:fs.readFileSync(path.join(root,'mobile/assets/fonts/Poppins-'+name+'.ttf')).toString('base64')})));
 await p.evaluate(()=>{document.getElementById('ob189').hidden=true;localStorage.setItem('goyana-outlets180',JSON.stringify([{id:'A',name:'Pusat'}]));localStorage.setItem('goyana-active-outlet180',JSON.stringify('A'));localStorage.setItem('goyana-wa-devices195',JSON.stringify([{id:'pair-test',name:'WA Kasir',phone:'6281234567890',outletId:'A',status:'unconnected'}]));openPage('wadevices195');document.querySelector('[data-wa195-connect]').click()});await p.clock.runFor(400);
 const before=await p.evaluate(()=>JSON.stringify(localStorage));
 for(const [method,index] of [['qr',0],['code',1]]){
 await p.evaluate(i=>__goyanaForm('wa195-pair','button',i),index);await p.clock.runFor(400);
 const event=await p.evaluate(()=>GoyanaNative.__events.map(JSON.parse).filter(e=>e.page==='wadevices195'&&e.sheet?.id==='wa195-pair').at(-1));
 assert.ok(event,'native page survives pairing popup');assert.equal(event.sheet.id,'wa195-pair');
 assert.deepEqual(event.sheet.items.flatMap(i=>i.type==='buttons'?i.options:i.type==='button'?[i]:[]).map(i=>[i.i,i.t]),[[0,'Scan QR'],[1,'Kode WhatsApp'],[2,'Tutup']]);
 assert.equal(event.sheet.items.some(i=>i.type==='input'||i.type==='qr'),false);
 assert.equal(await p.locator('#wa195-pair-'+method).getAttribute('aria-pressed'),'true');
 assert.equal(await p.locator('#wa195-pair .wa195-panel').evaluate(e=>e.scrollWidth<=e.clientWidth+1),true);
 assert.equal(await p.evaluate(()=>JSON.stringify(localStorage)),before);assert.equal(await p.evaluate(()=>Boolean(WA141.conn)),false);
 cases.push({width,method,model:event.model,sheet:event.sheet});
 }
 await p.evaluate(()=>__goyanaForm('wa195-pair','button',2));await p.clock.runFor(200);assert.equal(await p.locator('#wa195-pair').isVisible(),false);
 await p.evaluate(()=>document.querySelector('[data-wa195-connect]').click());assert.equal(await p.locator('#wa195-pair-qr').getAttribute('aria-pressed'),'true');
 await p.evaluate(()=>__goyanaForm('wa195-pair','close',0));assert.equal(await p.locator('#wa195-pair').isVisible(),false);
 await p.evaluate(()=>document.querySelector('[data-wa195-connect]').click());await p.keyboard.press('Escape');assert.equal(await p.locator('#wa195-pair').isVisible(),false);
 await p.evaluate(()=>{document.querySelector('[data-wa195-connect]').click();openPage('settings')});assert.equal(await p.locator('#wa195-pair').isVisible(),false);
 }
 }finally{await p.close()}
 if(write)fs.writeFileSync(path.join(root,'mobile/test/fixtures/parity/wa_pair195.json'),JSON.stringify(cases)+'\n');
 return cases;
};
if(require.main===module)(async()=>{const {chromium}=require('playwright');const b=await chromium.launch({headless:true,args:['--no-sandbox','--single-process','--no-zygote']});try{console.log((await module.exports(b,true)).map(c=>[c.width,c.method]))}finally{await b.close()}})().catch(e=>{console.error(e);process.exit(1)});
