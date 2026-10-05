// B11 follows the active production redirect, not the hidden ONLINE demo page.
const assert=require('assert/strict'),fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'../..');
module.exports=async function capture(browser,write=false){
 const cases=[],p=await browser.newPage({viewport:{width:390,height:844},timezoneId:'Asia/Jakarta'});
 try{
 await p.clock.install({time:new Date('2026-10-05T01:00:00Z')});
 await p.addInitScript(()=>{
  localStorage.setItem('gy175-ck',JSON.stringify({acct:'fixture-only',key:null,at:null}));
  localStorage.setItem('gy175-feat',JSON.stringify({nota:1,siap:1,telat:1,bot:1,balas:1,terima:1}));
  localStorage.setItem('gy175-intent',JSON.stringify({status:1,tagihan:1,harga:1,jam:1,jemput:1,cs:1}));
  window.GoyanaNative={__events:[],postMessage(raw){if(raw.startsWith('{"event"')){this.__events.push(JSON.parse(raw));return}const m=JSON.parse(raw);setTimeout(()=>__goyanaNative.finish(m.id,true,m.method==='insets'?{top:31}:{}),5)}};
 });
 for(const width of [390,320])for(const state of ['trial','gold','changed']){
  await p.setViewportSize({width,height:844});
  await p.goto(require('url').pathToFileURL(path.join(root,'mobile/assets/web/index.html')).href);await p.clock.runFor(3500);
  await p.evaluate(async faces=>{for(const face of faces){const font=new FontFace('Poppins','url(data:font/ttf;base64,'+face.data+')',{weight:face.weight});document.fonts.add(await font.load())}await document.fonts.ready},[['Regular','400'],['Medium','500'],['SemiBold','600']].map(([name,weight])=>({weight,data:fs.readFileSync(path.join(root,'mobile/assets/fonts/Poppins-'+name+'.ttf')).toString('base64')})));
  await p.evaluate(state=>{document.getElementById('ob189').hidden=true;if(state!=='trial'){goyanaPlan111.plan={...goyanaPlan111.plan,id:'GOLD',paid:true,until:'2027-01-01T00:00:00Z'};BOT175.bot=1;BOT175.balas=1}openPage('waautomation')},state);await p.clock.runFor(400);
  assert.equal(await p.evaluate(()=>document.querySelector('.page.active').id),'whatsappbot');
  assert.equal(await p.locator('#waautomation').isVisible(),false);
  const latest=()=>p.evaluate(()=>GoyanaNative.__events.filter(e=>e.page==='whatsappbot').at(-1));
  if(state==='changed'){
   for(const i of [0,5])await p.evaluate(i=>__goyanaForm('whatsappbot','toggle',i),i);
   await p.clock.runFor(400);
   assert.deepEqual(await p.evaluate(()=>[JSON.parse(localStorage.getItem('gy175-feat')).terima,JSON.parse(localStorage.getItem('gy175-feat')).nota,JSON.parse(localStorage.getItem('gy175-intent')).status]),[0,0,0]);
   await p.evaluate(()=>{openPage('settings');openPage('waautomation')});await p.clock.runFor(400);
  }
  const event=await latest();assert.ok(event);assert.equal(event.sheet,null);assert.equal(event.model.mirror,undefined);
  assert.ok(event.model.items.some(i=>i.t==='Layanan WhatsApp belum terhubung'));
  assert.equal(await p.locator('#c175-qr').count(),0);assert.equal(await p.evaluate(()=>Boolean(WA141.conn)),false);
  assert.equal(JSON.stringify(event.model).includes('ONLINE'),false);
  const toggles=event.model.items.filter(i=>i.type==='toggle');assert.equal(toggles.length,state==='trial'?0:11);
  if(state==='changed')assert.deepEqual(toggles.filter(i=>[0,5].includes(i.i)).map(i=>i.on),[false,false]);
  const buttons=event.model.items.filter(i=>i.type==='button'&&i.i>=0).map(i=>({i:i.i,t:i.t}));
  cases.push({width,state,page:event.page,model:event.model,buttons});
  for(const [label,target] of [['Kelola Perangkat WhatsApp','wadevices195'],['Balasan Cepat & Trigger ›',state==='trial'?'whatsappbot':'triggers191'],['Pengaturan Chatbot AI ›',state==='trial'?'whatsappbot':'ai191']]){
   const button=buttons.find(b=>b.t===label);assert.ok(button);
   await p.evaluate(i=>__goyanaForm('whatsappbot','button',i),button.i);await p.clock.runFor(250);
   assert.equal(await p.evaluate(()=>document.querySelector('.page.active').id),target);
   await p.evaluate(()=>openPage('waautomation'));await p.clock.runFor(250);
  }
  const blast=buttons.find(b=>b.t==='WhatsApp Blast ›');await p.evaluate(i=>__goyanaForm('whatsappbot','button',i),blast.i);await p.clock.runFor(250);assert.equal(await p.evaluate(()=>document.querySelector('.page.active').id),'whatsappbot');assert.match(await p.locator('#toast90').textContent(),/Platinum/);
  if(state==='gold')for(const item of toggles){
   const result=await p.evaluate(i=>{
    const el=document.querySelectorAll('#whatsappbot .content input[type=checkbox]')[i],before=el.checked,key=el.dataset.f||el.dataset.i,store=el.dataset.f?'gy175-feat':'gy175-intent';
    __goyanaForm('whatsappbot','toggle',i);
    const saved=JSON.parse(localStorage.getItem(store));
    return {before,after:el.checked,saved:saved[key]};
   },item.i);
   assert.equal(result.after,!result.before);assert.equal(result.saved,result.after?1:0);
  }
  await p.evaluate(()=>__goyanaBack());await p.clock.runFor(250);assert.equal(await p.evaluate(()=>document.querySelector('.page.active').id),'settings');
 }
 }finally{await p.close()}
 if(write)fs.writeFileSync(path.join(root,'mobile/test/fixtures/parity/waautomation_active.json'),JSON.stringify(cases)+'\n');
 return cases;
};
if(require.main===module)(async()=>{const {chromium}=require('playwright');const b=await chromium.launch({headless:true,args:['--no-sandbox','--single-process','--no-zygote']});try{console.log((await module.exports(b,true)).map(c=>[c.width,c.state]))}finally{await b.close()}})().catch(e=>{console.error(e);process.exit(1)});
