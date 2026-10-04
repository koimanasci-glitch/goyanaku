// 3c SIAPKAN: capture HTML asli. Tidak dipanggil oleh tes Dart.
// NODE_PATH=tests/node_modules node tests/parity/save.cjs
const fs=require('fs'),path=require('path'),assert=require('assert/strict');
const {spawnSync}=require('child_process'),{chromium}=require('playwright');
const root=path.resolve(__dirname,'../..');
async function main(){
 const prep=spawnSync('python',[path.join(root,'tools/prepare_flutter_web.py'),root,path.join(root,'tests/node_modules/@zxing/library/umd/index.min.js')],{encoding:'utf8'});
 if(prep.status)throw Error(prep.stderr||prep.stdout);
 const browser=await chromium.launch({headless:true,args:['--no-sandbox'],...(process.env.GOYANA_BROWSER_EXECUTABLE?{executablePath:process.env.GOYANA_BROWSER_EXECUTABLE}:{})});
 try{
 const ctx=await browser.newContext({viewport:{width:390,height:844},timezoneId:'Asia/Jakarta'}),p=await ctx.newPage();
 await p.clock.install({time:new Date('2026-10-04T03:00:00Z')});
 await p.addInitScript(()=>{window.GoyanaNative={__events:[],postMessage(raw){if(raw.startsWith('{"event"'))return;const m=JSON.parse(raw);setTimeout(()=>window.__goyanaNative.finish(m.id,true,{}),5)}}});
 await p.goto(require('url').pathToFileURL(path.join(root,'mobile/assets/web/index.html')).href);await p.clock.runFor(3500);
 await p.evaluate(()=>{document.getElementById('ob189').hidden=true;openPage('home');
  // Outlet wajib ada; tanpa outlet HTML menolak menghitung dan menyimpan angka bawaan Rp 20.000.
  addBranch96();const f=document.querySelector('#outletedit');f.querySelector('input.profile-input').value='Uji';f.querySelector('textarea').value='Jakarta';f.querySelector('input[inputmode=tel]').value='081234567890';saveOutlet158();document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});});
 const cases=[];
 for(const [i,config] of [
  {method:'Bayar Nanti',dur:'Reguler'},
  {method:'Tunai',dur:'Express'},
  {method:'QRIS',dur:'Kilat'},
  {method:'Transfer',dur:'Express',hours:{Express:12}},
 ].entries()){
  await p.clock.setSystemTime(new Date('2026-10-04T03:00:00Z'));
  const result=await p.evaluate(({i,config})=>{
   document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});
   const name='Uji Save '+i,phone='0812345678'+i;
   document.getElementById('v88-name').value=name;document.getElementById('v88-phone').value=phone;document.getElementById('v88-address').value='Jakarta';saveCustomerV88();
   // Pola mk() capture.cjs: jangan klik pemilih pelanggan.
   document.querySelector('#f61-services .f61-customerbar div b').textContent=name;window.pickedName136=name;
   localStorage.setItem('goyana-durations199',JSON.stringify(config.hours||{}));
   f61.cart=[{id:'t',n:'Cuci Baju',name:'Cuci Baju',ic:'Kiloan',unit:'kg',price:7000,qty:2.5}];f61.total=17500;f61.dur=config.dur;
   document.getElementById('f61-duration-label').textContent=config.dur;
   document.getElementById('f61-handover').selectedIndex=0;
   f61Payment();flushTransactions177();
   const before=JSON.parse(localStorage.getItem('goyana-business177')),now=new Date().toISOString(),code=nextCode136();
   const draft={name,phone,cart:JSON.parse(JSON.stringify(f61.cart)),dur:f61.dur,durationLabel:document.getElementById('f61-duration-label').textContent,method:config.method,total:f61.total,payamount:document.getElementById('f61-payamount').textContent,priority:document.getElementById('f61-priority').checked,handover:document.getElementById('f61-handover').value,perfume:document.querySelector('#f61-options select').value};
   f61Finish(config.method);flushTransactions177();
   return {name:config.method+' '+config.dur,now,store:{'goyana-durations199':localStorage.getItem('goyana-durations199')},before,draft,code,htmlModel:JSON.parse(localStorage.getItem('goyana-business177'))};
  },{i,config});
  assert.equal(result.htmlModel.orders.length,result.before.orders.length+1);
  cases.push(result);await p.clock.runFor(800);
 }
 fs.writeFileSync(path.join(root,'mobile/test/fixtures/parity/save_orders.json'),JSON.stringify({cases},null,2)+'\n');console.log('Captured',cases.length,'save cases');
 }finally{await browser.close()}
}
main().catch(e=>{console.error(e);process.exitCode=1});
