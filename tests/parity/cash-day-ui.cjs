const {chromium}=require('playwright'),assert=require('assert/strict'),fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'../..'),key='goyana-business177';
(async()=>{
 const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
 try{
  const page=await browser.newPage({viewport:{width:390,height:844},timezoneId:'Asia/Jakarta'}),errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.clock.install({time:new Date('2026-11-01T01:00:00Z')});
  const seed=JSON.parse(fs.readFileSync(path.join(root,'mobile/test/fixtures/parity/flows_a4_a5_a7.json'))).steps.find(s=>s.part==='A7').before;
  const b=JSON.parse(seed[key]);b.kas={start:0,openAt:'07:00',kasir:'Koiman',outlet:'Gramapuri',sales:[{m:'Tunai',a:10000,at:'2026-10-31T16:59:59Z'},{m:'Deposit',a:28000,at:'2026-10-31T17:00:00Z'}],ins:[{m:'Tunai',a:50000,deposit178:true,at:'2026-11-01T00:00:00Z'}],outs:[],hist:[],den:{},phys:60000,qrisReal:'',tfReal:'',setor:null};seed[key]=JSON.stringify(b);
  await page.addInitScript(seed=>{
   if(!sessionStorage.getItem('daySeed')){sessionStorage.setItem('daySeed','1');for(const [k,v] of Object.entries(seed))sessionStorage.setItem('sq:'+k,v)}
   window.GoyanaStore={all:()=>JSON.stringify(Object.fromEntries(Object.keys(sessionStorage).filter(k=>k.startsWith('sq:')).map(k=>[k.slice(3),sessionStorage.getItem(k)]))),set:(k,v)=>{if(window.failCashStore&&k==='goyana-business177')return false;sessionStorage.setItem('sq:'+k,v);return true},setMany:j=>{for(const [k,v] of Object.entries(JSON.parse(j)))sessionStorage.setItem('sq:'+k,v);return true},remove:k=>sessionStorage.removeItem('sq:'+k)};
   window.GoyanaNative={postMessage(raw){if(raw.startsWith('{"event"'))return;const m=JSON.parse(raw);setTimeout(()=>window.__goyanaNative.finish(m.id,true,{}),5)}};
  },seed);
  await page.goto(require('url').pathToFileURL(path.join(root,'mobile/assets/web/index.html')).href);await page.clock.runFor(3500);
  await page.evaluate(()=>{document.getElementById('ob189').hidden=true;openPage('home')});
  assert.equal(await page.locator('#gy155-today').textContent(),'Rp 28.000');
  await page.evaluate(()=>{openPage('cashclose');kcClose137()});await page.clock.runFor(50);
  const before=await page.evaluate(()=>JSON.stringify(KAS137));
  await page.evaluate(()=>closeSheet91('gs107'));
  assert.equal(await page.evaluate(()=>JSON.stringify(KAS137)),before,'cancel leaves full ledger unchanged');
  await page.evaluate(()=>{window.failCashStore=true;kcClose137()});await page.clock.runFor(50);await page.evaluate(()=>document.querySelector('#gs107-ok').click());await page.clock.runFor(100);
  assert.equal(await page.evaluate(()=>JSON.stringify(KAS137)),before,'failed storage restores shift');
  assert.equal(await page.evaluate(()=>JSON.parse(sessionStorage.getItem('sq:goyana-business177')).kas.hist.length),0);
  await page.evaluate(()=>{window.failCashStore=false;kcClose137()});await page.clock.runFor(50);await page.evaluate(()=>document.querySelector('#gs107-ok').click());await page.clock.runFor(100);
  await page.evaluate(()=>{closeSheet91('kc137s');openPage('home')});assert.equal(await page.locator('#gy155-today').textContent(),'Rp 28.000');
  await page.evaluate(()=>{KAS137.sales.push({m:'QRIS',a:5000,at:new Date()},{m:'Deposit',a:7000,at:new Date()});KAS137.ins.push({m:'Non-Tunai',a:30000,deposit178:true,at:new Date()});KAS137.outs.push({m:'Non-Tunai',a:2000,t:'Uji',at:new Date()});KAS137.phys=0;flushTransactions177();openPage('cashclose')});
  const summary=await page.evaluate(()=>readCashA7().expected);assert.equal(summary.nt,33000);assert.equal(summary.expect,0);assert.equal(summary.omset,12000);
  await page.evaluate(()=>kcClose137());await page.clock.runFor(50);await page.evaluate(()=>document.querySelector('#gs107-ok').click());await page.clock.runFor(100);
  await page.evaluate(()=>{closeSheet91('kc137s');openPage('home')});assert.equal(await page.locator('#gy155-today').textContent(),'Rp 40.000');
  await page.reload();await page.clock.runFor(3500);await page.evaluate(()=>openPage('home'));assert.equal(await page.locator('#gy155-today').textContent(),'Rp 40.000');
  assert.equal(await page.evaluate(()=>KAS137.hist.length),2);
  const unchanged=await page.evaluate(()=>JSON.stringify(KAS137));
  await page.evaluate(()=>{window.failCashStore=true;openPage('cashout');var f=document.getElementById('cashout');f.querySelector('input[placeholder=Jumlah]').value='5000';f.querySelector('select.cash-input').value='Non-Tunai';f.querySelector('.cash-submit').click()});await page.clock.runFor(100);
  assert.equal(await page.evaluate(()=>JSON.stringify(KAS137)),unchanged,'failed noncash expense restores ledger');
  assert.equal(await page.locator('#cashout input[placeholder=Jumlah]').inputValue(),'5000');
  assert.deepEqual(errors,[]);
  console.log('PASS daily UI: WIB midnight, topup excluded, two shifts, cancellation, storage rollback and SQLite reload');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
