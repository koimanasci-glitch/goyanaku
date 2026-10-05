// A6 fixtures come from original HTML timers and read-only closure oracles.
const fs=require('fs'),path=require('path'),assert=require('assert/strict');
const {spawnSync}=require('child_process'),{chromium}=require('playwright');
const root=path.resolve(__dirname,'../..');
(async()=>{
 const prep=spawnSync('python',[path.join(root,'tools/prepare_flutter_web.py'),root,path.join(root,'tests/node_modules/@zxing/library/umd/index.min.js')],{encoding:'utf8'});assert.equal(prep.status,0,prep.stderr);
 const b=await chromium.launch({headless:true,args:['--no-sandbox'],...(process.env.GOYANA_BROWSER_EXECUTABLE?{executablePath:process.env.GOYANA_BROWSER_EXECUTABLE}:{})});
 try{
 const p=await b.newPage({viewport:{width:390,height:844},timezoneId:'Asia/Jakarta'}),errors=[];p.on('pageerror',e=>errors.push(e.message));
 await p.clock.install({time:new Date('2026-10-06T00:00:00Z')});
 await p.addInitScript(()=>{window.GoyanaNative={__events:[],postMessage(raw){if(raw.startsWith('{"event"'))this.__events.push(raw);else{const m=JSON.parse(raw);setTimeout(()=>window.__goyanaNative.finish(m.id,true,{}),5)}}}});
 await p.goto(require('url').pathToFileURL(path.join(root,'mobile/assets/web/index.html')).href);await p.clock.runFor(3500);
 await p.evaluate(()=>{
  document.getElementById('ob189').hidden=true;
  addBranch96();const f=document.querySelector('#outletedit');f.querySelector('input.profile-input').value='A6';f.querySelector('textarea').value='Jakarta';f.querySelector('input[inputmode=tel]').value='081234567890';saveOutlet158();
  document.getElementById('v88-name').value='Uji A6';document.getElementById('v88-phone').value='081200000001';saveCustomerV88();
  document.querySelector('#f61-services .f61-customerbar div b').textContent='Uji A6';window.pickedName136='Uji A6';f61.cart=[{id:'t',n:'Cuci Baju',name:'Cuci Baju',ic:'Kiloan',unit:'kg',price:7000,qty:1}];f61.total=7000;f61.dur='Reguler';document.getElementById('f61-duration-label').textContent='Reguler';f61Payment();f61Finish('Bayar Nanti');
  window.a6Template=document.querySelector('#orders .g62-ordercard').cloneNode(true);
 });await p.clock.runFor(1000);
 const shots=[];
 for(const [name,q,qMin,lateDays,reminderDays] of [['default',true,60,7,7],['queue_off',false,60,7,7],['queue_90_minutes',true,90,7,7],['late_3',true,60,3,3],['late_5',true,60,5,5],['late_14',true,60,14,14],['independent_reminder_threshold',true,60,7,3]]){
  await p.evaluate(([q,qMin,lateDays,reminderDays])=>{
   document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});AUTO133.q=q;AUTO133.qMin=qMin;AUTO133.p=false;telatDays140(lateDays);remTh138(reminderDays);
   const list=document.querySelector('#orders .g62-orderlist');list.querySelectorAll('.g62-ordercard').forEach(c=>c.remove());
   const specs=[['q_before','antrian',qMin*60000-1],['q_exact','antrian',qMin*60000],['q_after','antrian',qMin*60000+1],['q_future','antrian',-60000],['q_missing','antrian',null],['ready_before','siap',0,lateDays*86400000-1],['ready_exact','siap',0,lateDays*86400000],['ready_after','siap',0,lateDays*86400000+1],['ready_delivery','siap',0,20*86400000,'1'],['late_under','telat',0,(lateDays-1)*86400000],['late_missing','telat',0,null],['ready_future','siap',0,-86400000],['ready_invalid','siap',0,'bad'],...['jemput','cuci','kering','setrika','packing','diantar','diambil','batal'].map(st=>['ignore_'+st,st,100*86400000,100*86400000])];
   window.a6Specs=specs;specs.forEach(([id,st])=>{const c=a6Template.cloneNode(true);delete c.dataset.w133;delete c.dataset.w138;c.dataset.st=st;c.querySelector('.g62-order-top b').textContent=id;list.appendChild(c);paint108(c)});
   Object.keys(LOG138).forEach(k=>delete LOG138[k]);LOG138.ready_exact=[{k:'rem',t:new Date()}];LOG138.ready_delivery=[{k:'rem',t:new Date()},{k:'rem',t:new Date()}];
  },[q,qMin,lateDays,reminderDays]);await p.clock.runFor(5);
  const shot=await p.evaluate(name=>{
   const now=Date.now();a6Specs.forEach(([id,st,elapsed,age,antar])=>{const c=[...document.querySelectorAll('#orders .g62-ordercard')].find(c=>c.querySelector('.g62-order-top b').textContent===id);if(elapsed===null)delete c.dataset.ts133;else c.dataset.ts133=String(now-elapsed);if(age===null||age===undefined)delete c.dataset.siap138;else c.dataset.siap138=age==='bad'?'bad':String(now-age);c.dataset.antar=antar||'0'});
   const snapshot=__goyanaStatusA6();autoTick133();telatSync140();
   return {name,...snapshot,after:[...document.querySelectorAll('#orders .g62-ordercard')].map(c=>({id:c.querySelector('.g62-order-top b').textContent,st:c.dataset.st}))};
  },name);
  for(const card of shot.cards){const move=shot.expected.moves.find(x=>x.id===card.id);const queue=shot.expected.queue.find(x=>x.id===card.id);const next=move?.next||queue?.next||card.dataset.st;assert.equal(shot.after.find(x=>x.id===card.id).st,next,name+' '+card.id);}
  assert.equal(shot.after.find(x=>x.id==='ignore_packing').st,'packing','ready always manual');shots.push(shot);
 }
 assert.deepEqual(errors,[]);
 const file=path.join(root,'mobile/test/fixtures/parity/status_a6.json');
 if(process.argv.includes('--verify-only')){
  const saved=JSON.parse(fs.readFileSync(file,'utf8')).shots;
  const relative=s=>({...s.expected,reminders:s.expected.reminders.map(r=>({...r,since:r.since-s.now})),notices:s.expected.notices.map(n=>({...n,at:n.at-s.now}))});
  assert.equal(shots.length,saved.length);
  shots.forEach((s,i)=>{assert.equal(s.name,saved[i].name);assert.deepEqual(relative(s),relative(saved[i]),'original A6 oracle changed: '+s.name);assert.deepEqual(s.after,saved[i].after,'timer outcomes changed: '+s.name)});
 }else fs.writeFileSync(file,JSON.stringify({shots},null,2)+'\n');
 console.log('PASS A6 original HTML: '+shots.length+' settings, '+shots[0].cards.length+' timer/status boundaries each; ready manual');
 }finally{await b.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
