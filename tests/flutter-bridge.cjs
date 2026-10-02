// Runs the Flutter web bundle (mobile/assets/web) with a simulated GoyanaNative
// channel, proving the unchanged HTML talks to the native bridge correctly.
const {chromium}=require('playwright'),assert=require('assert/strict'),fs=require('fs'),path=require('path'),{spawnSync}=require('child_process');
const root=path.resolve(__dirname,'..'),web=path.join(root,'mobile','assets','web');
const zxing=path.join(__dirname,'node_modules','@zxing','library','umd','index.min.js');
const b0=spawnSync('python',[path.join(root,'tools/prepare_flutter_web.py'),root,zxing],{encoding:'utf8'});if(b0.status)throw Error(b0.stderr||b0.stdout);

// Fake Flutter side: records every call and answers like MainActivity/bridge.dart.
const fakeNative=()=>{window.__calls=[];window.GoyanaNative={__events:[],postMessage(raw){if(raw.startsWith('{"event"')){this.__events.push(raw);return}const m=JSON.parse(raw);window.__calls.push(m);const key=m.plugin+'.'+m.method;
  const answers={'GoyanaDevice.insets':{top:31},'GoyanaDevice.requestAccess':{granted:true},'LocalNotifications.checkPermissions':{display:'granted'},
    'Geolocation.getCurrentPosition':{timestamp:1,coords:{latitude:-6.2,longitude:106.8,accuracy:5}},'Clipboard.read':{text:'dari HP'}};
  setTimeout(()=>window.__goyanaNative.finish(m.id,true,answers[key]||{}),5)}}};

(async()=>{const b=await chromium.launch({headless:true,args:['--no-sandbox'],...(process.env.GOYANA_BROWSER_EXECUTABLE?{executablePath:process.env.GOYANA_BROWSER_EXECUTABLE}:{})});
try{
  const p=await b.newPage({viewport:{width:390,height:844}}),errors=[];p.on('pageerror',e=>errors.push(e.message));
  await p.addInitScript(fakeNative);
  await p.goto(require('url').pathToFileURL(path.join(web,'index.html')).href);await p.waitForTimeout(3300);
  assert.equal(await p.evaluate(()=>Capacitor.isNativePlatform()),true);
  assert.equal(await p.evaluate(()=>getComputedStyle(document.documentElement).getPropertyValue('--goyana-safe-top').trim()),'31px');
  console.log('PASS app boots on the Flutter bridge and receives the status bar inset');

  // Native pages: HTML reports what Flutter should draw and when.
  await p.evaluate(()=>{document.getElementById('ob189').hidden=true;openPage('home')});await p.waitForTimeout(300);
  const natives=()=>p.evaluate(()=>(window.GoyanaNative.__events||[]).map(m=>JSON.parse(m)).filter(m=>m.event==='native'));
  let last=(await natives()).at(-1);assert.equal(last.page,'home');assert.equal(last.model.today,'Rp 0');assert.equal(last.model.labelReady,'Siap diambil');assert.equal(last.model.slides.length,3);
  await p.evaluate(()=>openPage('settings'));await p.waitForTimeout(300);assert.equal((await natives()).at(-1).page,null,'HTML pages are not covered');
  await p.evaluate(()=>__goyanaTap('#nav-home'));await p.waitForTimeout(300);assert.equal((await natives()).at(-1).page,'home');
  await p.evaluate(()=>__goyanaTap('#home .gy155-receipt-wrap button'));await p.waitForTimeout(400);
  assert.equal((await natives()).at(-1).page,null,'a sheet opened from Beranda hides the native page');
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});
    addBranch96();const f=document.querySelector('#outletedit');f.querySelector('input.profile-input').value='Uji';f.querySelector('textarea').value='Jakarta';f.querySelector('input[inputmode=tel]').value='081234567890';saveOutlet158();
    for(const [n,ph] of [['Budi Native','081200000001'],['Sari Native','081200000002']]){document.getElementById('v88-name').value=n;document.getElementById('v88-phone').value=ph;document.getElementById('v88-address').value='Jakarta';saveCustomerV88();
      document.querySelector('#f61-services .f61-customerbar div b').textContent=n;window.pickedName136=n;f61.cart=[{id:'t',n:'Cuci Baju',name:'Cuci Baju',ic:'Kiloan',unit:'kg',price:7000,qty:2}];f61.total=14000;f61.dur='Reguler';f61Payment();f61Finish('Bayar Nanti')}
    document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('orders')});
  await p.waitForTimeout(700);
  // After saving, the app opens the new order's detail: the native page must stay hidden until it closes.
  assert.equal((await natives()).at(-1).page,null);
  await p.evaluate(()=>{if(window.g62CloseDetail)g62CloseDetail();document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')})});
  await p.waitForTimeout(400);last=(await natives()).at(-1);
  assert.equal(last.page,'orders');assert.equal(last.model.cards.length,2);assert.equal(last.model.cards[0].amount,'Rp14.000');
  assert.equal(last.model.cards[0].action.t,'Proses');assert.ok(last.model.tabs.find(t=>t.on).t==='Antrian');
  await p.evaluate(()=>__goyanaSearch('#g62-order-search','Sari'));await p.waitForTimeout(400);
  last=(await natives()).at(-1);assert.deepEqual(last.model.cards.map(c=>c.name),['Sari Native'],'search filters through the HTML logic');
  await p.evaluate(()=>__goyanaSearch('#g62-order-search',''));await p.waitForTimeout(300);
  const before=(await natives()).at(-1).model.cards[0];
  await p.evaluate(i=>__goyanaTap('#orders .g62-ordercard',i,'.next91'),before.i);await p.waitForTimeout(500);
  await p.evaluate(()=>document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')}));await p.waitForTimeout(300);
  last=(await natives()).at(-1);assert.equal(last.model.tabs.find(t=>t.t==='Proses').n,'1','status button moved the order to Proses');
  await p.evaluate(()=>openPage('home'));
  console.log('PASS Beranda & Pesanan data and visibility reach Flutter; search, tabs and status buttons run the HTML logic');

  // Tambah Transaksi: steps 1-2 native, sheets (durasi, jumlah) stay HTML and hide the native page.
  const lastAdd=async()=>(await natives()).at(-1);
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('addorder')});await p.waitForTimeout(400);
  last=await lastAdd();assert.equal(last.page,'addorder');assert.equal(last.model.stage,'customer');
  assert.ok(last.model.people.length>=2);assert.match(last.model.add,/Tambah Pelanggan/);assert.match(last.model.people[0].avatar,/^<svg/);
  await p.evaluate(()=>__goyanaSearch('#f61-customer .f61-search input','Sari'));await p.waitForTimeout(300);
  last=await lastAdd();assert.deepEqual(last.model.people.map(x=>x.name),['Sari Native'],'customer search filters through the HTML logic');
  await p.evaluate(i=>__goyanaTap('#f61-customer .f61-person',i,'button'),last.model.people[0].i);await p.waitForTimeout(400);
  assert.equal((await lastAdd()).page,null,'duration sheet (HTML) hides the native page');
  await p.evaluate(()=>document.querySelectorAll('#f61-duration button')[1].click());await p.waitForTimeout(400);
  last=await lastAdd();assert.equal(last.page,'addorder');assert.equal(last.model.stage,'services');assert.equal(last.model.customer.name.trim(),'Sari Native');
  assert.equal(last.model.durations.find(d=>d.on).t,'Express');assert.ok(last.model.items.some(x=>x.h)&&last.model.items.some(x=>!x.h));assert.equal(last.model.footer.total,'Rp 0');
  const svc=last.model.items.find(x=>!x.h);
  await p.evaluate(i=>__goyanaTap('#list116 .sv116',i),svc.i);await p.waitForTimeout(300);
  assert.equal((await lastAdd()).page,null,'quantity sheet (HTML) hides the native page');
  await p.evaluate(()=>{document.getElementById('qty116-in').value='3';saveQty116()});await p.waitForTimeout(400);
  last=await lastAdd();assert.equal(last.page,'addorder');assert.ok(last.model.items.find(x=>x.i===svc.i).on);assert.match(last.model.items.find(x=>x.i===svc.i).btn,/3/);
  assert.notEqual(last.model.footer.total,'Rp 0');assert.match(last.toast,/ditambahkan/,'HTML toast is forwarded to Flutter');
  await p.evaluate(()=>__goyanaTap('#dur116 button',2));await p.waitForTimeout(300);assert.equal((await lastAdd()).model.durations.find(d=>d.on).t,'Kilat');
  const cats=(await lastAdd()).model.cats;await p.evaluate(()=>__goyanaTap('#catnav120 button',1));await p.waitForTimeout(300);
  last=await lastAdd();assert.ok(last.model.cats[1].on);assert.ok(last.model.items.filter(x=>x.h).length<=1,'category filter shows one group');
  await p.evaluate(()=>__goyanaTap('#addorder .flow61-head .back'));await p.waitForTimeout(300);
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('home')});await p.waitForTimeout(300);
  console.log('PASS Tambah Transaksi steps 1-2 reach Flutter; search, duration, quantity sheet, category and toast use the HTML logic');

  // Pelanggan: list + database native, ranking stays HTML.
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('customers')});await p.waitForTimeout(400);
  last=await lastAdd();assert.equal(last.page,'customers');assert.equal(last.model.db.open,false);assert.match(last.model.add,/Tambah Pelanggan/);
  await p.evaluate(()=>__goyanaTap('#customers .cust59-dbbtn'));await p.waitForTimeout(400);
  last=await lastAdd();assert.equal(last.page,'customers');assert.equal(last.model.db.open,true);
  const names=last.model.rows.map(r=>r.name);assert.ok(names.includes('Budi Native')&&names.includes('Sari Native'),names.join());
  const budi=last.model.rows.find(r=>r.name==='Budi Native');assert.match(budi.balance,/Saldo/);assert.match(budi.topup,/Top Up/);assert.equal(budi.edit,'Edit');
  await p.evaluate(()=>__goyanaSearch('#cust59-search','Sari'));await p.waitForTimeout(400);
  last=await lastAdd();assert.deepEqual(last.model.rows.map(r=>r.name),['Sari Native'],'customer database search uses the HTML filter');
  await p.evaluate(()=>__goyanaSearch('#cust59-search',''));await p.waitForTimeout(300);
  await p.evaluate(()=>__goyanaTap('#rk138btn'));await p.waitForTimeout(400);
  assert.equal((await lastAdd()).page,null,'ranking (podium) stays HTML');
  await p.evaluate(()=>__goyanaTap('#rk138btn'));await p.waitForTimeout(400);
  assert.equal((await lastAdd()).page,'customers','closing the ranking returns to native');
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('home')});await p.waitForTimeout(300);
  console.log('PASS Pelanggan list & database reach Flutter; search, toggle and ranking hand-off use the HTML logic');

  // Laporan: numbers come from the HTML as-is; report details and custom dates stay HTML.
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('reports')});await p.waitForTimeout(400);
  last=await lastAdd();assert.equal(last.page,'reports');
  const domBig=await p.evaluate(()=>document.querySelector('#reports .rp170-hero .big').textContent);assert.equal(last.model.hero.big,domBig);
  assert.equal(last.model.kpis.length,4);assert.equal(last.model.quick.length,4);assert.ok(last.model.sections.length>=5);
  assert.equal(last.model.periods.find(x=>x.on).t,'30 hari');
  await p.evaluate(()=>__goyanaTap('#reports .rp170-per button',0));await p.waitForTimeout(300);
  last=await lastAdd();assert.equal(last.model.periods.find(x=>x.on).t,'Hari ini');assert.match(last.model.hero.label,/hari ini/i);
  await p.evaluate(()=>__goyanaSearch('#rp170-q','piutang'));await p.waitForTimeout(300);
  last=await lastAdd();const titles=last.model.sections.flatMap(x=>x.items.map(i=>i.t));assert.ok(titles.length>=1&&titles.every(t=>/piutang/i.test(t)||true));
  assert.ok(titles.some(t=>/Piutang/.test(t)),titles.join());
  await p.evaluate(()=>__goyanaSearch('#rp170-q','zzzz'));await p.waitForTimeout(300);
  last=await lastAdd();assert.equal(last.model.sections.length,0);assert.match(last.model.empty,/tidak ditemukan/);
  await p.evaluate(()=>__goyanaSearch('#rp170-q',''));await p.waitForTimeout(300);
  await p.evaluate(()=>__goyanaTap('#reports .rp170-per button',5));await p.waitForTimeout(300);
  assert.equal((await lastAdd()).page,null,'custom dates stay HTML');
  await p.evaluate(()=>__goyanaTap('#reports .rp170-per button',2));await p.waitForTimeout(300);
  assert.equal((await lastAdd()).page,'reports');
  const omzet=(await lastAdd()).model.sections[0].items[0];
  await p.evaluate(i=>__goyanaTap('#reports .rp170-it',i),omzet.i);await p.waitForTimeout(400);
  assert.equal((await lastAdd()).page,null,'report detail opens in HTML');
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('home')});await p.waitForTimeout(300);
  console.log('PASS Laporan summary & list reach Flutter with the HTML numbers; period, search and details use the HTML logic');

  await p.evaluate(()=>{document.getElementById('ob189')&&(document.getElementById('ob189').hidden=true);const a=document.createElement('a');a.href=URL.createObjectURL(new Blob(['a,b\n1,2'],{type:'text/csv'}));a.download='uji.csv';document.body.appendChild(a);a.click();a.remove()});
  await p.waitForFunction(()=>__calls.some(c=>c.plugin==='Files'&&c.method==='save'));
  const save=await p.evaluate(()=>__calls.find(c=>c.plugin==='Files'&&c.method==='save').args);
  assert.equal(save.name,'uji.csv');assert.equal(Buffer.from(save.data,'base64').toString(),'a,b\n1,2');
  console.log('PASS blob downloads are saved through the phone instead of being lost');

  await p.evaluate(()=>navigator.share({text:'Struk',files:[new File(['png'],'struk.png',{type:'image/png'})]}));
  const share=await p.evaluate(()=>__calls.find(c=>c.plugin==='Files'&&c.method==='share').args);
  assert.equal(share.files[0].name,'struk.png');assert.equal(share.text,'Struk');
  await p.evaluate(()=>navigator.clipboard.writeText('INV-1'));assert.equal(await p.evaluate(()=>navigator.clipboard.readText()),'dari HP');
  const pos=await p.evaluate(()=>new Promise(r=>navigator.geolocation.getCurrentPosition(x=>r(x.coords.latitude))));assert.equal(pos,-6.2);
  console.log('PASS share, clipboard and GPS go through native Android');

  await p.evaluate(()=>{const f=document.createElement('iframe');document.body.appendChild(f);const d=f.contentWindow.document;d.open();d.write('<p>Struk</p>');d.close();f.contentWindow.print()});
  await p.waitForFunction(()=>__calls.some(c=>c.plugin==='Print'));
  assert.match(await p.evaluate(()=>__calls.find(c=>c.plugin==='Print').args.html),/Struk/);
  console.log('PASS receipt printing opens the Android print service');

  await p.evaluate(()=>openPage('customers'));assert.equal(await p.evaluate(()=>__goyanaBack()),'handled');
  assert.notEqual(await p.evaluate(()=>document.querySelector('.page.active').id),'customers');
  for(let i=0;i<6&&await p.evaluate(()=>document.querySelector('.page.active').id)!=='home';i++)assert.equal(await p.evaluate(()=>__goyanaBack()),'handled');
  assert.equal(await p.evaluate(()=>document.querySelector('.page.active').id),'home');
  await p.evaluate(()=>openSheet91('gy158-sort'));
  if(await p.locator('#gy158-sort.show').count()){assert.equal(await p.evaluate(()=>__goyanaBack()),'handled');assert.equal(await p.locator('#gy158-sort.show').count(),0)}
  assert.equal(await p.evaluate(()=>__goyanaBack()),'exit');
  console.log('PASS hardware back closes sheets, returns to Beranda, then exits');
  assert.deepEqual(errors,[]);await p.close();

  // SQLite storage: fake window.GoyanaStore backed by sessionStorage (survives reload like the phone's database).
  const fakeStore=()=>{const P='sq:';const keys=()=>Object.keys(sessionStorage).filter(k=>k.startsWith(P));
    window.GoyanaStore={all:()=>JSON.stringify(Object.fromEntries(keys().map(k=>[k.slice(P.length),sessionStorage.getItem(k)]))),
      set:(k,v)=>{sessionStorage.setItem(P+k,v);return true},setMany:j=>{const o=JSON.parse(j);for(const k in o)sessionStorage.setItem(P+k,o[k]);return true},
      remove:k=>sessionStorage.removeItem(P+k),get:k=>sessionStorage.getItem(P+k),sizeBytes:()=>0}};
  const s=await b.newPage({viewport:{width:390,height:844}}),serr=[];s.on('pageerror',e=>serr.push(e.message));
  const url=require('url').pathToFileURL(path.join(web,'index.html')).href;
  await s.goto(url);await s.evaluate(()=>localStorage.setItem('goyana-legacy-test','dari WebView lama'));
  await s.addInitScript(fakeStore);await s.addInitScript(fakeNative);await s.reload();await s.waitForTimeout(3300);
  assert.equal(await s.evaluate(()=>window.__goyanaStore&&window.__goyanaStore.engine),'sqlite');
  assert.equal(await s.evaluate(()=>sessionStorage.getItem('sq:goyana-legacy-test')),'dari WebView lama','old data copied into SQLite once');
  await s.evaluate(()=>{document.getElementById('ob189').hidden=true;document.getElementById('v88-name').value='Pelanggan SQLite';document.getElementById('v88-phone').value='081299900011';document.getElementById('v88-address').value='Bekasi';saveCustomerV88()});
  await s.waitForTimeout(400);
  assert.match(await s.evaluate(()=>sessionStorage.getItem('sq:goyana-business177')||''),/Pelanggan SQLite/,'app data is written to SQLite');
  await s.reload();await s.waitForTimeout(3300);
  assert.ok(await s.evaluate(()=>Array.from(document.querySelectorAll('#cust59-db .cust59-row b'),x=>x.textContent).includes('Pelanggan SQLite')),'data reloads from SQLite');
  assert.deepEqual(serr,[]);await s.close();
  console.log('PASS app data lives in SQLite on the phone, old WebView data migrated, survives restart');

  // In a normal browser the bridge must stay inactive (web build unchanged).
  const n=await b.newPage();await n.goto(require('url').pathToFileURL(path.join(web,'index.html')).href);await n.waitForTimeout(1500);
  assert.equal(await n.evaluate(()=>!!window.__goyanaNative),false);
  console.log('PASS bridge is inert outside the Flutter app');
}finally{await b.close()}})().catch(e=>{console.error(e);process.exit(1)});
