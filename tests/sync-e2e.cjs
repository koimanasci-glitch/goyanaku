// Two phones + real Laravel server: data made on one phone reaches the other,
// also after working offline. Requires PHP + backend/vendor (composer install).
const {chromium}=require('playwright'),assert=require('assert/strict'),fs=require('fs'),os=require('os'),path=require('path'),{spawn,spawnSync}=require('child_process');
const root=path.resolve(__dirname,'..'),backend=path.join(root,'backend'),port=8000+Math.floor(Math.random()*900),api='http://127.0.0.1:'+port;
const tmp=fs.mkdtempSync(path.join(os.tmpdir(),'goyana-sync-')),db=path.join(tmp,'db.sqlite'),web=path.join(tmp,'web');fs.writeFileSync(db,'');
const env={...process.env,DB_CONNECTION:'sqlite',DB_DATABASE:db,APP_ENV:'local',APP_KEY:'base64:'+Buffer.alloc(32,7).toString('base64'),SESSION_DRIVER:'array',CACHE_STORE:'array',QUEUE_CONNECTION:'sync'};
const run=(cmd,args,o={})=>{const r=spawnSync(cmd,args,{encoding:'utf8',env,...o});if(r.status)throw Error(cmd+' '+args.join(' ')+'\n'+r.stdout+r.stderr);return r.stdout};
run('php',['artisan','migrate','--force','-q'],{cwd:backend});
run('php',['tests/fixtures/create_owner.php','owner@sync.test','kasir@sync.test'],{cwd:backend});
run('python',[path.join(root,'tools/prepare_web.py'),root,web,'--api='+api]);
fs.copyFileSync(require.resolve('@zxing/library/umd/index.min.js'),path.join(web,'zxing.min.js'));
fs.writeFileSync(path.join(web,'capacitor.js'),'');
const server=spawn('php',['artisan','serve','--host=127.0.0.1','--port='+port],{cwd:backend,env,stdio:'ignore'});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function phone(b,name){const ctx=await b.newContext({viewport:{width:390,height:844}}),p=await ctx.newPage(),errors=[];p.on('pageerror',e=>errors.push(name+': '+e.message));
  await p.goto(require('url').pathToFileURL(path.join(web,'index.html')).href);await p.waitForTimeout(3300);return {ctx,p,errors}}
async function login(p,email){if(!globalThis.shot1){globalThis.shot1=1;await p.screenshot({path:path.join(os.tmpdir(),'goyana-sync-login.png')})}assert.ok(await p.evaluate(()=>document.getElementById('lg167').classList.contains('show')),'login screen shown when server is configured');
  if(!globalThis.forgot1){globalThis.forgot1=1;const pop=p.waitForEvent('popup',{timeout:5000});await p.evaluate(()=>{const b=[...document.querySelectorAll('#lg167 button,#lg167 a')].find(x=>/Lupa password/i.test(x.textContent));b.click()});
    const w=await pop;assert.match(w.url(),/\/forgot-password$/,'Lupa password opens the server reset page');await w.close()}
  await p.fill('#lg167-u',email);await p.fill('#lg167-p','PasswordAman123');
  await Promise.all([p.waitForEvent('load',{timeout:20000}).catch(()=>null),p.click('#lg167 .go')]);await p.waitForTimeout(3500);
  await p.evaluate(()=>{const o=document.getElementById('ob189');if(o)o.hidden=true})}
async function order(p,customer,phoneNo){await p.evaluate(([n,ph])=>{document.getElementById('v88-name').value=n;document.getElementById('v88-phone').value=ph;document.getElementById('v88-address').value='Jakarta';saveCustomerV88();
  document.querySelector('#f61-services .f61-customerbar div b').textContent=n;window.pickedName136=n;f61.cart=[{id:'t',n:'Cuci Baju',name:'Cuci Baju',ic:'Kiloan',unit:'kg',price:7000,qty:2}];f61.total=14000;f61.dur='Reguler';f61Payment();f61Finish('Bayar Nanti')},[customer,phoneNo]);await p.waitForTimeout(600)}
const ids=p=>p.evaluate(()=>Array.from(document.querySelectorAll('#orders .g62-ordercard .g62-order-top b'),b=>b.textContent.trim()).sort());
async function sync(p){await p.evaluate(()=>GoyanaSync.cycle());return p.evaluate(()=>({phase:GoyanaSync.status.phase,pending:GoyanaSync.status.pending,error:GoyanaSync.status.error,inbox:(JSON.parse(localStorage.getItem('goyana-sync-inbox')||'[]')).length}))}
async function receive(p){const s=await sync(p);if(s.inbox){await Promise.all([p.waitForEvent('load'),p.evaluate(()=>location.reload())]);await p.waitForTimeout(3300)}return s}
(async()=>{for(let i=0;i<40;i++){try{await fetch(api+'/up');break}catch{await sleep(250)}}
const b=await chromium.launch({headless:true,args:['--no-sandbox'],...(process.env.GOYANA_BROWSER_EXECUTABLE?{executablePath:process.env.GOYANA_BROWSER_EXECUTABLE}:{})});
try{
  const A=await phone(b,'A');await login(A.p,'owner@sync.test');
  assert.deepEqual(await A.p.evaluate(()=>JSON.parse(localStorage.getItem('goyana-outlets180')).map(o=>o.id)),['srv-1']);
  await order(A.p,'Budi Sync','081234500001');const aIds=await ids(A.p);assert.equal(aIds.length,1);
  let s=await sync(A.p);assert.equal(s.phase,'ok',s.error);assert.equal(s.pending,0);
  console.log('PASS phone A logs in to the server and uploads its order and customer');

  const B=await phone(b,'B');await login(B.p,'owner@sync.test');
  assert.deepEqual(await ids(B.p),aIds);
  assert.ok(await B.p.evaluate(()=>Array.from(document.querySelectorAll('#cust59-db .cust59-row b'),x=>x.textContent).includes('Budi Sync')));
  console.log('PASS phone B downloads the same order and customer after login');

  await order(B.p,'Sari Sync','081234500002');assert.equal((await sync(B.p)).pending,0);
  await receive(A.p);assert.deepEqual(await ids(A.p),await ids(B.p));assert.equal((await ids(A.p)).length,2);
  console.log('PASS an order made on phone B appears on phone A');

  await A.ctx.setOffline(true);await order(A.p,'Offline Sync','081234500003');
  s=await sync(A.p);assert.equal(s.phase,'offline');assert.ok(s.pending>0,'changes wait while offline');
  assert.match(await A.p.evaluate(()=>{openPage('settings');return document.querySelector('#sync197 .s197-line').textContent}),/Offline · \d+ data menunggu/);
  await A.ctx.setOffline(false);s=await sync(A.p);assert.equal(s.pending,0);
  await receive(B.p);assert.equal((await ids(B.p)).length,3);
  console.log('PASS offline work is kept and sent automatically when back online');

  // Echo check: applying downloaded data must not create endless uploads.
  assert.equal((await sync(B.p)).pending,0);assert.equal((await sync(A.p)).pending,0);
  console.log('PASS no ping-pong uploads after downloads');
  await A.p.evaluate(()=>{openPage('settings');document.querySelector('#settings .content').scrollTop=0});await A.p.screenshot({path:path.join(os.tmpdir(),'goyana-sync-settings.png')});

  // Phones A and B (owner) already use both cashier slots of the outlet.
  const C=await phone(b,'C');await login(C.p,'kasir@sync.test');assert.equal((await ids(C.p)).length,3);
  await order(C.p,'Kasir Sync','081234500004');s=await sync(C.p);
  assert.equal(s.pending,1,'only the order waits; the new customer is not a transaction and still syncs');
  assert.match(await C.p.evaluate(()=>GoyanaSync.status.rejected),/Maksimal 2 perangkat kasir per outlet/);
  console.log('PASS kasir sees outlet data; a third cashier phone cannot upload transactions');
  assert.deepEqual([...A.errors,...B.errors,...C.errors],[]);
}finally{await b.close();server.kill();fs.rmSync(tmp,{recursive:true,force:true})}})().catch(e=>{console.error(e);server.kill();process.exit(1)});
