// Tangkap hasil HTML untuk tes paritas Dart (mobile/test/parity_test.dart).
// Pakai:  node tests/parity/capture.cjs <keluaran.json> '<langkah JSON>'
//   langkah: ["mk",nama,hp,kg,metode,penyerahan(0 Datang|1 Antar|2 Jemput&Antar)], ["adv",nama,status_tujuan],
//            ["cancel",nama], ["days",n]
// Jam dipalsukan (mulai 2026-10-03 10:00 WIB) supaya hasil bisa diulang. Lalu ubah keluaran jadi fixture:
//   home_*.json   = {now, store, home}
//   orders_*.json = {now, store, tabs: ordersTabs, search:{q,tab,model: ordersSearch}}
// Butuh: npm install --prefix tests ; GOYANA_BROWSER_EXECUTABLE (opsional) ; python tools/prepare_flutter_web.py dijalankan otomatis.
const path=require('path'),{spawnSync}=require('child_process');
const root=path.resolve(__dirname,'..','..');
{const r=spawnSync('python',[path.join(root,'tools/prepare_flutter_web.py'),root,path.join(root,'tests/node_modules/@zxing/library/umd/index.min.js')],{encoding:'utf8'});if(r.status)throw Error(r.stderr||r.stdout);}
const {chromium}=require('playwright');const fs=require('fs');
(async()=>{const b=await chromium.launch({headless:true,args:['--no-sandbox'],...(process.env.GOYANA_BROWSER_EXECUTABLE?{executablePath:process.env.GOYANA_BROWSER_EXECUTABLE}:{})});
const ctx=await b.newContext({viewport:{width:390,height:844},timezoneId:'Asia/Jakarta'});const p=await ctx.newPage();
await p.clock.install({time:new Date('2026-10-03T03:00:00Z')});
await p.addInitScript(()=>{window.GoyanaNative={__events:[],postMessage(raw){if(raw.startsWith('{"event"')){this.__events.push(raw);return}const m=JSON.parse(raw);setTimeout(()=>window.__goyanaNative.finish(m.id,true,{}),5)}}});
await p.goto(require('url').pathToFileURL(path.join(root,'mobile/assets/web/index.html')).href);await p.clock.runFor(3500);
await p.evaluate(()=>{document.getElementById('ob189').hidden=true;openPage('home');document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});
addBranch96();const f=document.querySelector('#outletedit');f.querySelector('input.profile-input').value='Uji';f.querySelector('textarea').value='Jakarta';f.querySelector('input[inputmode=tel]').value='081234567890';saveOutlet158();});
const mk=async(n,ph,qty,method,dur)=>{await p.evaluate(([n,ph,qty,method,dur])=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});
 document.getElementById('v88-name').value=n;document.getElementById('v88-phone').value=ph;document.getElementById('v88-address').value='Jakarta';saveCustomerV88();
 document.querySelector('#f61-services .f61-customerbar div b').textContent=n;window.pickedName136=n;f61.cart=[{id:'t',n:'Cuci Baju',name:'Cuci Baju',ic:'Kiloan',unit:'kg',price:7000,qty:qty}];f61.total=7000*qty;f61.dur='Reguler';const ho=document.getElementById('f61-handover');if(ho)ho.selectedIndex=+(dur||0);f61Payment();f61Finish(method);
 document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});},[n,ph,qty,method,dur]);await p.clock.runFor(800);};
const adv=async(name,target)=>{for(let k=0;k<8;k++){const st=await p.evaluate(n=>{const c=[...document.querySelectorAll('#orders .g62-ordercard')].find(c=>(c.querySelector('.g62-order-body div b')||{}).textContent===n);return c&&c.dataset.st},name);if(!st||st===target)return st;
 await p.evaluate(n=>{const cs=[...document.querySelectorAll('#orders .g62-ordercard')];const i=cs.findIndex(c=>(c.querySelector('.g62-order-body div b')||{}).textContent===n);if(i>=0)__goyanaTap('#orders .g62-ordercard',i,'.next91')},name);await p.clock.runFor(600);
 await p.evaluate(()=>{if(window.g62CloseDetail)g62CloseDetail();document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')})});await p.clock.runFor(300);}};
const steps=JSON.parse(process.argv[3]||'[]');
for(const st of steps){
 if(st[0]==='adv'){await p.evaluate(()=>openPage('orders'));await p.clock.runFor(500);console.error('adv',st[1],await adv(st[1],st[2]));}
 if(st[0]==='mk'){await mk(st[1],st[2],st[3],st[4],st[5]);}
 if(st[0]==='cancel'){await p.evaluate(()=>openPage('orders'));await p.clock.runFor(400);await p.evaluate(n=>{const c=[...document.querySelectorAll('#orders .g62-ordercard')].find(c=>(c.querySelector('.g62-order-body div b')||{}).textContent===n);c.click()},st[1]);await p.clock.runFor(500);await p.evaluate(()=>{openSheet91('cancel91');const r=document.getElementById('cancel91-reason');r.selectedIndex=1;confirmCancel91()});await p.clock.runFor(600);await p.evaluate(()=>{if(window.g62CloseDetail)g62CloseDetail();document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')})});await p.clock.runFor(300);}
 if(st[0]==='days'){await p.clock.fastForward(st[1]*86400000);await p.clock.runFor(2000);}
}
await p.evaluate(()=>openPage('home'));await p.clock.runFor(500);await p.evaluate(()=>openPage('orders'));await p.clock.runFor(21000);
const ordersTabs=[];
const ntabs=await p.evaluate(()=>document.querySelectorAll('#orders .g62-tabs button').length);
for(let t=0;t<ntabs;t++){await p.evaluate(t=>__goyanaTap('#orders .g62-tabs button',t),t);await p.clock.runFor(600);
 ordersTabs.push(await p.evaluate(()=>{const ev=GoyanaNative.__events.map(JSON.parse).filter(x=>x.page==='orders');return ev[ev.length-1].model}));}
await p.evaluate(()=>__goyanaTap('#orders .g62-tabs button',1));await p.clock.runFor(400);
await p.evaluate(()=>__goyanaSearch('#g62-order-search','sari'));await p.clock.runFor(700);
const ordersSearch=await p.evaluate(()=>{const ev=GoyanaNative.__events.map(JSON.parse).filter(x=>x.page==='orders');return ev[ev.length-1].model});
await p.evaluate(()=>__goyanaSearch('#g62-order-search',''));await p.clock.runFor(400);
await p.evaluate(()=>openPage('home'));await p.clock.runFor(900);
const out=await p.evaluate(()=>{const ev=GoyanaNative.__events.map(JSON.parse).filter(x=>x.page==='home');const st={};for(let i=0;i<localStorage.length;i++){const k=localStorage.key(i);if(/^goyana-/.test(k))st[k]=localStorage.getItem(k)}
 return {now:new Date().toISOString(),home:ev[ev.length-1].model,store:st,cards:[...document.querySelectorAll('#orders .g62-ordercard')].map(c=>c.dataset.st+':'+c.textContent.replace(/\s+/g,' ').slice(0,40))}});
out.ordersTabs=ordersTabs;out.ordersSearch=ordersSearch;fs.writeFileSync(process.argv[2],JSON.stringify(out,null,1));
console.log(JSON.stringify({now:out.now,home:{statIn:out.home.statIn,statReady:out.home.statReady,statLate:out.home.statLate,today:out.home.today},cards:out.cards,keys:Object.keys(out.store)}));
await b.close()})();
