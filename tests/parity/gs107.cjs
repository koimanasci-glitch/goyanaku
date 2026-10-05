const assert=require('assert/strict'),fs=require('fs'),path=require('path');const root=path.resolve(__dirname,'../..');
module.exports=async function capture(browser,write=false){
 const cases=[],p=await browser.newPage({viewport:{width:390,height:844},timezoneId:'Asia/Jakarta'});
 try{
 await p.clock.install({time:new Date('2026-10-05T01:00:00Z')});
 await p.addInitScript(()=>{window.GoyanaNative={__events:[],postMessage(raw){if(raw.startsWith('{"event"')){this.__events.push(JSON.parse(raw));return}const m=JSON.parse(raw);setTimeout(()=>__goyanaNative.finish(m.id,true,m.method==='insets'?{top:31}:{}),5)}}});
 for(const width of [390,320])for(const state of ['perfume','duration','confirm','reward']){
  await p.setViewportSize({width,height:844});await p.goto(require('url').pathToFileURL(path.join(root,'mobile/assets/web/index.html')).href);await p.clock.runFor(3500);
  await p.evaluate(async faces=>{for(const face of faces){const f=new FontFace('Poppins','url(data:font/ttf;base64,'+face.data+')',{weight:face.weight});document.fonts.add(await f.load())}await document.fonts.ready},[['Regular','400'],['Medium','500'],['SemiBold','600']].map(([n,weight])=>({weight,data:fs.readFileSync(path.join(root,'mobile/assets/fonts/Poppins-'+n+'.ttf')).toString('base64')})));
  await p.evaluate(state=>{document.getElementById('ob189').hidden=true;
   if(state==='perfume'){openPage('perfume');document.querySelector('#perfume .primary').click()}
   if(state==='duration'){openPage('duration');[...document.querySelectorAll('#duration .duration-row')].find(r=>r.textContent.includes('Express')).querySelector('.edit').click()}
   if(state==='confirm'){openPage('perfume');document.querySelector('#perfume .primary').click();__goyanaForm('gs107','input',0,'Vanilla B12');document.getElementById('gs107-ok').click();[...document.querySelectorAll('#perfume .pf99')].at(-1).querySelector('.del').click()}
   if(state==='reward'){goyanaPlan111.plan={...goyanaPlan111.plan,id:'GOLD',paid:true,until:'2027-01-01T00:00:00Z'};openPage('crm');addRw130()}
  },state);await p.clock.runFor(600);
  const event=await p.evaluate(()=>GoyanaNative.__events.filter(e=>e.sheet?.id==='gs107').at(-1));assert.ok(event?.sheet.mirror,width+' '+state);
  const buttons=await p.evaluate(()=>[...document.querySelectorAll('#gs107 .sheet91-box button')].map((b,i)=>({i,t:b.textContent.trim()})));
  const inputs=await p.evaluate(()=>[...document.querySelectorAll('#gs107 input')].map((e,i)=>({i,numeric:e.inputMode==='numeric',v:e.value})));
  cases.push({width,state,model:event.sheet.mirror,buttons,inputs});
  if(state==='perfume'){
   const save=buttons.find(b=>b.t==='Tambah');await p.evaluate(i=>__goyanaForm('gs107','button',i),save.i);assert.equal(await p.locator('#gs107').isVisible(),true);assert.match(await p.locator('#toast90').textContent(),/Lengkapi/);
   await p.evaluate(()=>{__goyanaForm('gs107','input',0,'Vanilla B12');__goyanaForm('gs107','button',1)});assert.equal(await p.locator('#gs107 .gs107-c .on').getAttribute('data-c'),'#5aa9e6');
   await p.evaluate(i=>__goyanaForm('gs107','button',i),save.i);await p.clock.runFor(400);assert.equal(await p.locator('#gs107').isVisible(),false);assert.ok(await p.locator('#perfume').textContent().then(t=>t.includes('Vanilla B12')));
  }else if(state==='duration'){
   await p.evaluate(()=>__goyanaForm('gs107','input',0,'12'));await p.evaluate(i=>__goyanaForm('gs107','button',i),buttons.find(b=>b.t==='Simpan').i);await p.clock.runFor(300);assert.equal(await p.evaluate(()=>JSON.parse(localStorage.getItem('goyana-durations199')).Express),12);
  }else{
   // Cancellation must not run the destructive/reward callback.
   const before=await p.evaluate(()=>JSON.stringify(localStorage));await p.evaluate(i=>__goyanaForm('gs107','button',i),buttons.find(b=>b.t==='Batal').i);await p.clock.runFor(300);assert.equal(await p.evaluate(()=>JSON.stringify(localStorage)),before);assert.equal(await p.locator('#gs107').isVisible(),false);
  }
 }
 }finally{await p.close()}
 if(write)fs.writeFileSync(path.join(root,'mobile/test/fixtures/parity/gs107_cases.json'),JSON.stringify(cases)+'\n');return cases;
};
if(require.main===module)(async()=>{const {chromium}=require('playwright');const b=await chromium.launch({headless:true,args:['--no-sandbox','--single-process','--no-zygote']});try{console.log((await module.exports(b,true)).map(c=>[c.width,c.state]))}finally{await b.close()}})().catch(e=>{console.error(e);process.exit(1)});
