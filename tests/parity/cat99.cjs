const assert=require('assert/strict'),fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'../..');
module.exports=async function capture(browser,write=false){
 const cases=[],p=await browser.newPage({viewport:{width:390,height:844},timezoneId:'Asia/Jakarta'});
 try{
 await p.clock.install({time:new Date('2026-10-05T01:00:00Z')});
 await p.addInitScript(()=>{localStorage.clear();window.GoyanaNative={__events:[],postMessage(raw){if(raw.startsWith('{"event"')){this.__events.push(JSON.parse(raw));return}const m=JSON.parse(raw);setTimeout(()=>__goyanaNative.finish(m.id,true,m.method==='insets'?{top:31}:{}),5)}}});
 for(const width of [390,320])for(const state of ['empty','changed']){
  await p.setViewportSize({width,height:844});
   await p.goto(require('url').pathToFileURL(path.join(root,'mobile/assets/web/index.html')).href);await p.clock.runFor(3500);
   await p.evaluate(async faces=>{for(const face of faces){const f=new FontFace('Poppins','url(data:font/ttf;base64,'+face.data+')',{weight:face.weight});document.fonts.add(await f.load())}await document.fonts.ready},[['Regular','400'],['Medium','500'],['SemiBold','600']].map(([n,weight])=>({weight,data:fs.readFileSync(path.join(root,'mobile/assets/fonts/Poppins-'+n+'.ttf')).toString('base64')})));
   await p.evaluate(()=>{document.getElementById('ob189').hidden=true;openPage('services');document.querySelector('#services .bar99 button').click()});await p.clock.runFor(600);
   const buttons=await p.evaluate(()=>[...document.querySelectorAll('#cat99 .sheet91-box button')].map((b,i)=>({i,t:b.textContent.trim(),icon:b.dataset.ic||null})));
   assert.equal(buttons.length,30);const save=buttons.find(b=>b.t==='Simpan Kategori');
   const change=async()=>{
    // Exercise every HTML action index, then leave a stable selected state.
    for(const b of buttons.filter(b=>b.icon)){
     await p.evaluate(i=>__goyanaForm('cat99','button',i),b.i);
     assert.equal(await p.locator('#cat99 .pk99.on').getAttribute('data-ic'),b.icon);
    }
    for(const b of buttons.filter(b=>['kg','pcs','m'].includes(b.t))){
     await p.evaluate(i=>__goyanaForm('cat99','button',i),b.i);
     assert.equal(await p.locator('#cat99-unit .on').textContent(),b.t);
    }
    for(const b of buttons.filter(b=>['Cuci','Kering','Setrika','Packing'].includes(b.t))){
     const before=await p.locator('#cat99-proc button').nth(b.i-25).evaluate(e=>e.classList.contains('on'));
     await p.evaluate(i=>__goyanaForm('cat99','button',i),b.i);
     assert.equal(await p.locator('#cat99-proc button').nth(b.i-25).evaluate(e=>e.classList.contains('on')),!before);
    }
    // Restore Kering/Packing, keeping Cuci off and Setrika on.
    await p.evaluate(()=>{__goyanaForm('cat99','button',26);__goyanaForm('cat99','button',28);['Kategori B12','7000','85'].forEach((v,i)=>__goyanaForm('cat99','input',i,v))});
   };
   if(state==='changed')await change();await p.clock.runFor(400);
   const event=await p.evaluate(()=>GoyanaNative.__events.filter(e=>e.sheet?.id==='cat99').at(-1));assert.ok(event?.sheet.mirror);
   const inputs=await p.evaluate(()=>[...document.querySelectorAll('#cat99 input')].map((e,i)=>({i,numeric:e.inputMode==='numeric',v:e.value})));
   cases.push({width,state,model:event.sheet.mirror,buttons,inputs});
   if(state==='empty'){
    await p.evaluate(i=>__goyanaForm('cat99','button',i),save.i);assert.equal(await p.locator('#cat99').isVisible(),true);assert.match(await p.locator('#toast90').textContent(),/Isi nama kategori dulu/);await change();
   }
   await p.evaluate(i=>__goyanaForm('cat99','button',i),save.i);await p.clock.runFor(400);assert.equal(await p.locator('#cat99').isVisible(),false);
   const stored=await p.evaluate(()=>JSON.parse(localStorage.getItem('goyana-services158')).find(s=>s.name==='Kategori B12'));
   assert.equal(stored.unit,'m');assert.deepEqual(stored.proc,['Kering','Setrika','Packing']);assert.deepEqual(stored.prices,{Reguler:7000,Express:10000,Kilat:14000});
   const before=await p.evaluate(()=>localStorage.getItem('goyana-services158'));
   await p.evaluate(()=>{document.querySelector('#services .bar99 button').click();__goyanaForm('cat99','input',0,'Tidak disimpan');__goyanaForm('cat99','close',0)});await p.clock.runFor(300);
   assert.equal(await p.locator('#cat99').isVisible(),false);assert.equal(await p.evaluate(()=>localStorage.getItem('goyana-services158')),before);
 }
 }finally{await p.close()}
 if(write)fs.writeFileSync(path.join(root,'mobile/test/fixtures/parity/cat99_cases.json'),JSON.stringify(cases)+'\n');return cases;
};
if(require.main===module)(async()=>{const {chromium}=require('playwright');const b=await chromium.launch({headless:true,args:['--no-sandbox','--single-process','--no-zygote']});try{console.log((await module.exports(b,true)).map(c=>[c.width,c.state]))}finally{await b.close()}})().catch(e=>{console.error(e);process.exit(1)});
