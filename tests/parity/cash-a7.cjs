// Read-only original HTML cash oracle; each scenario boots from saved real orders.
const fs=require('fs'),path=require('path'),assert=require('assert/strict');
const {spawnSync}=require('child_process'),{chromium}=require('playwright');
const root=path.resolve(__dirname,'../..');
const original=JSON.parse(fs.readFileSync(path.join(root,'mobile/test/fixtures/parity/flows_a4_a5_a7.json'))).steps.find(s=>s.part==='A7');
(async()=>{
 const prep=spawnSync('python',[path.join(root,'tools/prepare_flutter_web.py'),root,path.join(root,'tests/node_modules/@zxing/library/umd/index.min.js')],{encoding:'utf8'});assert.equal(prep.status,0,prep.stderr);
 const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
 const shots=[],errors=[];
 try {
 for(const [name,inputs] of [['uncounted',{}],['balanced',{start:100000,phys:149000}],['short',{phys:40000}],['over',{phys:60000}],['zero',{phys:0}],['reconciled',{phys:49000,qrisReal:'17500',tfReal:'14000'}],['setor_capped',{phys:49000,setor:999999}],['denominations',{den:{100000:1,20000:2,5000:1,2000:2}}],['manual_in_cash',{}],['manual_in_noncash',{}],['manual_out_cash',{}],['manual_out_noncash_audit',{}],['deposit_audit',{sales:[{m:'Deposit',a:28000}]}],['noncash_out_audit',{outs:[{m:'Non-Tunai',a:5000,t:'Audit'}]}]]) {
  const page=await browser.newPage({viewport:{width:390,height:844},timezoneId:'Asia/Jakarta'});page.on('pageerror',e=>errors.push(name+': '+e.message));
  await page.clock.install({time:new Date('2026-10-06T03:00:00Z')});
  const seed={...original.before};const business=JSON.parse(seed['goyana-business177']);Object.assign(business.kas,inputs);seed['goyana-business177']=JSON.stringify(business);
  await page.addInitScript(seed=>{
   if(!sessionStorage.getItem('a7seed')){sessionStorage.setItem('a7seed','1');for(const [k,v] of Object.entries(seed))sessionStorage.setItem('sq:'+k,v)}
   window.GoyanaStore={all:()=>JSON.stringify(Object.fromEntries(Object.keys(sessionStorage).filter(k=>k.startsWith('sq:')).map(k=>[k.slice(3),sessionStorage.getItem(k)]))),set:(k,v)=>{sessionStorage.setItem('sq:'+k,v);return true},setMany:j=>{for(const [k,v] of Object.entries(JSON.parse(j)))sessionStorage.setItem('sq:'+k,v);return true},remove:k=>sessionStorage.removeItem('sq:'+k),get:k=>sessionStorage.getItem('sq:'+k),sizeBytes:()=>0};
   window.GoyanaNative={__events:[],postMessage(raw){if(raw.startsWith('{"event"'))this.__events.push(raw);else{const m=JSON.parse(raw);setTimeout(()=>window.__goyanaNative.finish(m.id,true,{}),5)}}};
  },seed);
  await page.goto(require('url').pathToFileURL(path.join(root,'mobile/assets/web/index.html')).href);await page.clock.runFor(3500);
  await page.evaluate(()=>{document.getElementById('ob189').hidden=true;openPage('cashclose')});await page.clock.runFor(500);
  let entry;
  if(name.startsWith('manual_')) {
   entry=await page.evaluate(name=>{
    flushTransactions177();const before={'goyana-business177':localStorage.getItem('goyana-business177')};
    const income=name.startsWith('manual_in'),method=name.includes('noncash')?'Non-Tunai':'Tunai';
    openPage(income?'cashin':'cashout');
    const form=document.getElementById(income?'cashin':'cashout');
    form.querySelector('input[placeholder=Jumlah]').value='5000';
    form.querySelector('select.cash-input').value=method;
    form.querySelector('input[placeholder=Keterangan]').value='Uji';
    form.querySelector('.cash-submit').click();
    return {before,income,method,amount:5000,note:'Uji'};
   },name);
   await page.clock.runFor(400);
   entry.after=await page.evaluate(()=>{flushTransactions177();return {'goyana-business177':localStorage.getItem('goyana-business177')}});
   await page.evaluate(()=>openPage('cashclose'));await page.clock.runFor(200);
   if(name==='manual_out_noncash_audit'){const after=JSON.parse(entry.after['goyana-business177']).kas.outs;assert.equal(after.length,JSON.parse(entry.before['goyana-business177']).kas.outs.length+1);assert.equal(after.at(-1).m,'Non-Tunai');}
  }
  const shot=await page.evaluate(name=>({name,...__goyanaCashA7()}),name);if(entry)shot.entry=entry;shots.push(shot);
  if(name==='balanced'){
   await page.evaluate(()=>kcClose137());await page.clock.runFor(100);await page.evaluate(()=>document.querySelector('#gs107-ok').click());await page.clock.runFor(500);
   const closed=await page.evaluate(()=>{return __goyanaCashA7().kas});assert.equal(closed.start,100000);assert.equal(closed.hist[0].omset,80500);
   await page.reload();await page.clock.runFor(3500);await page.evaluate(()=>openPage('cashclose'));await page.clock.runFor(200);
   const restored=await page.evaluate(()=>__goyanaCashA7());assert.deepEqual(restored.kas,closed,'closed shift survives Android storage reload');assert.equal(restored.model.sections[5].history.length,closed.hist.length);
   shot.closed=closed;shot.restored=restored;
  }
  await page.close();
 }
 assert.deepEqual(errors,[]);
 const file=path.join(root,'mobile/test/fixtures/parity/cash_a7_corrected.json');
 if(process.argv.includes('--verify-only')) {
  const stable=s=>({name:s.name,expected:s.expected,denTotal:s.denTotal,unpaid:s.unpaid,model:s.model,restoredModel:s.restored?.model});
  assert.deepEqual(shots.map(stable),JSON.parse(fs.readFileSync(file)).shots.map(stable));
 }else fs.writeFileSync(file,JSON.stringify({shots},null,2)+'\n');
 console.log('PASS A7 '+shots.length+' corrected cash states; close and SQLite-adapter reload');
 } finally {await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
