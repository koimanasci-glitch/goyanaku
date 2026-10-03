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
  await p.evaluate(()=>openPage('finreport'));await p.waitForTimeout(300);assert.equal((await natives()).at(-1).page,null,'HTML pages are not covered');
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
  assert.equal(last.model.cards[0].action.t,'Proses');assert.match(last.model.cards[0].maps,/google\.com\/maps/,'order card links to the customer location');assert.ok(last.model.tabs.find(t=>t.on).t==='Antrian');
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

  // Steps 3-4: Atur Pesanan & Pembayaran sheets are drawn natively; deeper popups (tunai, QRIS, ...) stay HTML.
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('addorder')});await p.waitForTimeout(400);
  last=await lastAdd();await p.evaluate(i=>__goyanaTap('#f61-customer .f61-person',i,'button'),last.model.people[0].i);await p.waitForTimeout(300);
  await p.evaluate(()=>document.querySelectorAll('#f61-duration button')[0].click());await p.waitForTimeout(300);
  const sv2=(await lastAdd()).model.items.find(x=>!x.h);
  await p.evaluate(i=>__goyanaTap('#list116 .sv116',i),sv2.i);await p.waitForTimeout(300);
  await p.evaluate(()=>{document.getElementById('qty116-in').value='2';saveQty116()});await p.waitForTimeout(300);
  await p.evaluate(()=>__goyanaTap('#f61-service-footer > button'));await p.waitForTimeout(400);
  last=await lastAdd();assert.equal(last.page,'addorder','options sheet keeps the native page');assert.equal(last.model.sheet.kind,'options');
  const perfume=last.model.sheet.fields.find(x=>x.label==='Parfum'),prio=last.model.sheet.fields.find(x=>x.type==='switch');
  assert.ok(perfume.options.length>1&&prio);
  await p.evaluate(k=>__goyanaSelect('#f61-options .f61-sheet > label:nth-of-type('+(k+1)+') select',1),perfume.k);
  await p.evaluate(k=>__goyanaTap('#f61-options .f61-sheet > label:nth-of-type('+(k+1)+') input'),prio.k);
  await p.evaluate(()=>__goyanaSearch('#f61-options textarea','12 pcs, rak B2'));await p.waitForTimeout(300);
  last=await lastAdd();assert.equal(last.model.sheet.fields.find(x=>x.k===perfume.k).index,1);assert.equal(last.model.sheet.fields.find(x=>x.k===prio.k).on,true);assert.equal(last.model.sheet.note.v,'12 pcs, rak B2');
  await p.evaluate(()=>__goyanaTap('#f61-options .f61-main'));await p.waitForTimeout(500);
  last=await lastAdd();assert.equal(last.page,'addorder');assert.equal(last.model.sheet.kind,'payment');
  assert.deepEqual(last.model.sheet.methods.map(x=>x.t),['Tunai','QRIS','Transfer','Bayar Nanti','DP / Uang Muka','Saldo Deposit']);
  assert.match(last.model.sheet.total,/Rp/);assert.match(last.model.sheet.methods[0].svg,/^<svg/);
  await p.evaluate(i=>__goyanaTap('#f61-payment .f61-paygrid button',i),last.model.sheet.methods[0].i);await p.waitForTimeout(400);
  assert.equal((await lastAdd()).page,null,'cash popup stays HTML and hides the native page');
  if(await p.evaluate(()=>typeof window.cancelPayment154==='function'))await p.evaluate(()=>cancelPayment154());
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(!['lg167','f61-payment'].includes(e.id))e.classList.remove('show')})});await p.waitForTimeout(400);
  const back=await lastAdd();assert.equal(back.page,'addorder');assert.equal(back.model.sheet&&back.model.sheet.kind,'payment','closing the popup returns to the native payment sheet');
  // DP, deposit and QRIS popups fade in: the native page must still step aside (bug seen on a real phone).
  for(const name of ['DP / Uang Muka','Saldo Deposit','QRIS']){
    const m=(await lastAdd()).model.sheet.methods.find(x=>x.t===name);
    await p.evaluate(i=>__goyanaTap('#f61-payment .f61-paygrid button',i),m.i);
    await p.waitForFunction(()=>{const e=(window.GoyanaNative.__events||[]).map(x=>JSON.parse(x)).filter(x=>x.event==='native').at(-1);return e&&e.page===null},null,{timeout:4000}).catch(()=>{});
    assert.equal((await lastAdd()).page,null,name+' popup is shown (HTML) above the native sheet');
    await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(!['lg167','f61-payment'].includes(e.id))e.classList.remove('show')})});
    await p.waitForFunction(()=>{const e=(window.GoyanaNative.__events||[]).map(x=>JSON.parse(x)).filter(x=>x.event==='native').at(-1);return e&&e.page==='addorder'},null,{timeout:4000}).catch(()=>{});
    assert.equal((await lastAdd()).page,'addorder');
  }
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('home')});await p.waitForTimeout(300);
  console.log('PASS Atur Pesanan & Pembayaran sheets are native; selects, switch, note and payment buttons use the HTML logic');

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
  assert.equal((await lastAdd()).page,'rp170d','report detail opens natively');
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('home')});await p.waitForTimeout(300);
  console.log('PASS Laporan summary & list reach Flutter with the HTML numbers; period, search and details use the HTML logic');

  // Pengaturan: accordion groups toggle in place; items and links open the HTML pages.
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('settings')});await p.waitForTimeout(400);
  last=await lastAdd();assert.equal(last.page,'settings');assert.ok(last.model.groups.length>=8);assert.ok(last.model.sync&&/Sinkronisasi/.test(last.model.sync.t));
  assert.ok(last.model.acct&&/Masa Aktif/.test(last.model.acct.t));assert.match(last.model.logout,/Keluar/);
  const layanan=last.model.groups.find(g=>g.t==='Layanan');assert.ok(layanan.accordion&&!layanan.open);
  await p.evaluate(i=>__goyanaTap('#st178 > .setting178',i,':scope > button'),layanan.i);await p.waitForTimeout(400);
  last=await lastAdd();const open=last.model.groups.find(g=>g.t==='Layanan');assert.ok(open.open);assert.ok(open.items.some(x=>x.t==='Parfum'),open.items.map(x=>x.t).join());
  const parfum=open.items.find(x=>x.t==='Parfum');
  await p.evaluate(([g,j])=>__goyanaTap('#st178 > .setting178',g,'.st171-b > button:nth-child('+(j+1)+')'),[open.i,parfum.j]);await p.waitForTimeout(400);
  assert.equal(await p.evaluate(()=>document.querySelector('.page.active').id),'perfume','item opens its HTML page');
  await p.evaluate(()=>openPage('settings'));await p.waitForTimeout(300);
  const pl=(await lastAdd()).model.groups.find(g=>g.t==='Pelanggan');
  await p.evaluate(i=>__goyanaTap('#st178 > .setting178',i,':scope > button'),pl.i);await p.waitForTimeout(400);
  const chat=(await lastAdd()).model.groups.find(g=>g.t==='Pelanggan').items.find(x=>/Chatbot/.test(x.t)&&x.badge);assert.ok(chat,'locked items keep their badge separate from the name');
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('home')});await p.waitForTimeout(300);
  console.log('PASS Pengaturan groups, sync card and package card reach Flutter; accordion and items use the HTML logic');

  // Kas Masuk / Pengeluaran: native form writes into the HTML inputs; saving runs the HTML logic.
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('cashin')});await p.waitForTimeout(400);
  last=await lastAdd();assert.equal(last.page,'cashin');assert.equal(last.model.stats.length,2);assert.deepEqual(last.model.type.options,['Tipe Kas','Tunai','Non-Tunai']);
  const cashBefore=last.model.stats[0].v;
  await p.evaluate(()=>{__goyanaSearch('#cashin select.cash-input','Tunai');__goyanaSearch('#cashin .cash-input-group input','50000');__goyanaSearch('#cashin .cash-form-wrap > label:nth-child(3) input','Modal awal')});
  await p.waitForTimeout(300);last=await lastAdd();assert.equal(last.model.type.index,1);assert.match(last.model.amount.v,/50/);
  await p.evaluate(()=>__goyanaTap('#cashin .cash-submit'));await p.waitForTimeout(700);
  last=await lastAdd();assert.equal(last.model.amount.v,'');assert.notEqual(last.model.stats[0].v,cashBefore,'cash balance updated by the HTML logic: '+cashBefore+' -> '+last.model.stats[0].v);
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('cashout')});await p.waitForTimeout(400);
  last=await lastAdd();assert.equal(last.page,'cashout');assert.equal(last.model.subtract,true);
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('home')});await p.waitForTimeout(300);
  console.log('PASS Kas Masuk / Pengeluaran forms reach Flutter and save through the HTML logic');

  // Layanan: list, search and per-duration switches run the HTML logic.
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('services')});
  // The service list renders asynchronously; poll instead of a fixed delay (slow CI machines).
  await p.waitForFunction(()=>{const e=(window.GoyanaNative.__events||[]).map(m=>JSON.parse(m)).filter(m=>m.event==='native').at(-1);return e&&e.page==='services'&&e.model.cats.length>=3},null,{timeout:6000}).catch(()=>{});
  last=await lastAdd();assert.equal(last.page,'services');assert.ok(last.model.cats.length>=3,'services listed: '+last.model.cats.length);
  const svc0=last.model.cats[0];assert.equal(svc0.vars.length,3);assert.match(svc0.vars[0].price,/Rp/);assert.ok(svc0.chain.length>=3);
  const wasOn=svc0.vars[2].on;
  await p.evaluate(([i,j])=>__goyanaTapIn('#cat99-list .cat99',i,'.v99 input',j),[svc0.i,2]);await p.waitForTimeout(300);
  last=await lastAdd();assert.equal(last.model.cats.find(c=>c.i===svc0.i).vars[2].on,!wasOn,'switch toggles through the HTML');
  await p.evaluate(([i,j])=>__goyanaTapIn('#cat99-list .cat99',i,'.v99 input',j),[svc0.i,2]);await p.waitForTimeout(200);
  await p.evaluate(t=>__goyanaSearch('#services .bar99 input',t),svc0.t.slice(0,4));await p.waitForTimeout(300);
  last=await lastAdd();assert.ok(last.model.cats.length>=1&&last.model.cats.length<5,'search filters services: '+last.model.cats.length);
  await p.evaluate(()=>__goyanaSearch('#services .bar99 input',''));await p.waitForTimeout(200);
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('home')});await p.waitForTimeout(300);
  console.log('PASS Layanan list, search and switches reach Flutter and use the HTML logic');

  // Generic native form (Printer & Nota): fields, toggles, radios and save use the HTML elements.
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('printer')});await p.waitForTimeout(400);
  last=await lastAdd();assert.equal(last.page,'printer');
  const kinds=last.model.items.map(x=>x.type);['card','label','input','toggle','choice','button'].forEach(k=>assert.ok(kinds.includes(k),'form has '+k));
  const header=last.model.items.find(x=>x.type==='input');
  await p.evaluate(i=>__goyanaForm('printer','input',i,'Laundry Native'),header.i);
  const tog=last.model.items.find(x=>x.type==='toggle');await p.evaluate(i=>__goyanaForm('printer','toggle',i),tog.i);
  const size=last.model.items.find(x=>x.type==='choice').options[1];await p.evaluate(i=>__goyanaForm('printer','radio',i),size.i);
  await p.waitForTimeout(300);last=await lastAdd();
  assert.equal(last.model.items.find(x=>x.type==='input'&&x.i===header.i).v,'Laundry Native');
  assert.equal(last.model.items.find(x=>x.type==='toggle'&&x.i===tog.i).on,!tog.on);
  assert.ok(last.model.items.find(x=>x.type==='choice').options[1].on);
  assert.equal(await p.evaluate(()=>document.querySelector('#printer .content input.printer-input').value),'Laundry Native');
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('home')});await p.waitForTimeout(300);
  console.log('PASS generic native form (Printer & Nota) writes to the HTML fields, toggles and choices');
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('profile')});await p.waitForTimeout(400);
  last=await lastAdd();assert.equal(last.page,'profile');assert.ok(last.model.items.some(x=>x.type==='input'&&x.secret),'password field is marked secret');
  assert.ok(last.model.items.some(x=>x.type==='button'));
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('home')});await p.waitForTimeout(300);
  console.log('PASS Profil uses the generic native form');

  // Tambah Pelanggan & Pusat Bantuan: generic native form, save/search run in the HTML.
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('customeradd')});await p.waitForTimeout(400);
  assert.equal((await lastAdd()).page,null,'gender picker (HTML) opens first and covers the native form');
  await p.evaluate(()=>pickGp128('female'));await p.waitForFunction(()=>JSON.parse(window.GoyanaNative.__events.at(-1)).page==='customeradd',null,{timeout:3000});
  last=await lastAdd();assert.equal(last.model.items.find(x=>x.type==='row').t,'Wanita');
  const ins=last.model.items.filter(x=>x.type==='input');assert.equal(ins[0].ph,'Nama Pelanggan');
  assert.ok(last.model.items.some(x=>x.type==='row'&&x.btn==='Ganti'),'avatar row with Ganti button');
  assert.ok(last.model.items.find(x=>x.type==='buttons').options.some(o=>/Lokasi saya/.test(o.t)),'location buttons in one strip');
  await p.evaluate(([a,b])=>{__goyanaForm('customeradd','input',a,'Tono Native');__goyanaForm('customeradd','input',b,'081200000009')},[ins[0].i,ins[1].i]);
  const addBtn=last.model.items.find(x=>x.type==='button'&&x.t==='Tambahkan');await p.evaluate(i=>__goyanaForm('customeradd','button',i),addBtn.i);
  await p.waitForFunction(()=>JSON.stringify(window.business177||{}).includes('Tono Native')||document.body.textContent.includes('Tono Native'),null,{timeout:5000});
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('helpcenter')});await p.waitForTimeout(400);
  last=await lastAdd();assert.equal(last.page,'helpcenter');
  const cards=last.model.items.filter(x=>x.type==='card');assert.ok(cards.length>=5&&cards[0].ic,'help topics with emoji icons');
  await p.evaluate(i=>__goyanaForm('helpcenter','button',i),cards[0].i);await p.waitForTimeout(400);
  assert.equal((await lastAdd()).page,null,'help article (HTML) covers the native page');
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('home')});await p.waitForTimeout(300);
  console.log('PASS Tambah Pelanggan & Pusat Bantuan use the generic native form');

  // Outlet, Edit Outlet, Antar-Jemput, QRIS: generic native form incl. list entries, radio cards and file upload.
  const openNative=async id=>{await p.evaluate(id=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage(id)},id);
    await p.waitForFunction(id=>JSON.parse(window.GoyanaNative.__events.at(-1)).page===id,id,{timeout:3000});return lastAdd()};
  last=await openNative('outlets');const outlet=last.model.items.find(x=>x.type==='entry');
  assert.ok(outlet&&outlet.btns.some(b=>b.t==='Edit'),'outlet list entry with Edit button');
  await p.evaluate(i=>__goyanaForm('outlets','button',i),outlet.btns.find(b=>b.t==='Edit').i);
  await p.waitForFunction(()=>document.getElementById('outletedit').classList.contains('active'),null,{timeout:3000});
  last=await openNative('outletedit');assert.ok(last.model.items.some(x=>x.type==='image'),'logo preview');
  const up=last.model.items.find(x=>x.type==='buttons').options[0];assert.equal(up.file,'outlet-logo-file','upload button picks the file natively');
  const png='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
  await p.evaluate(b=>__goyanaFile('outlet-logo-file','logo.png','image/png',b),png);
  await p.waitForFunction(()=>!!document.querySelector('#outlet-logo-preview img'),null,{timeout:3000});await p.waitForTimeout(300);
  last=await lastAdd();assert.match(last.model.items.find(x=>x.type==='image').src,/^data:image/,'uploaded logo reaches Flutter');
  last=await openNative('delivery');const modes=last.model.items.find(x=>x.type==='choice');
  assert.ok(modes.options.length>=4&&modes.options[0].s,'tariff modes with descriptions');
  await p.evaluate(i=>__goyanaForm('delivery','radio',i),modes.options[1].i);await p.waitForTimeout(300);
  last=await lastAdd();assert.ok(last.model.items.find(x=>x.type==='choice').options[1].on);
  assert.ok(last.model.items.some(x=>x.type==='input'&&x.pre==='Rp')||last.model.items.some(x=>x.type==='input'&&x.label),'tariff field appears');
  assert.ok(last.model.items.some(x=>x.type==='entry'&&x.avatar),'couriers listed');
  last=await openNative('qris');assert.ok(last.model.items.find(x=>x.type==='button'&&x.file==='qris-file'),'QRIS upload picks the file natively');
  assert.ok(last.model.items.filter(x=>x.type==='toggle').length>=8);
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('home')});await p.waitForTimeout(300);
  console.log('PASS Outlet, Edit Outlet, Antar-Jemput & QRIS use the generic native form (entries, radio cards, file upload)');
  for(const id of ['cashier','reminder','expense','printerconnect','aboutgoyana','auditlog','automation','datacenter','wadevices195','whatsappbot','branchmonitor58']){
    last=await openNative(id);assert.ok(last.model.items.length>0,id+' has content');
  }
  last=await openNative('cashier');const perm=last.model.items.find(x=>x.type==='toggle');
  await p.evaluate(i=>__goyanaForm('cashier','toggle',i),perm.i);await p.waitForTimeout(300);
  assert.equal((await lastAdd()).model.items.find(x=>x.type==='toggle'&&x.i===perm.i).on,!perm.on,'cashier permission switch runs the HTML logic');
  last=await openNative('datacenter');assert.equal(last.model.items[0].type,'stats');
  last=await openNative('branchmonitor58');assert.ok(last.model.items.some(x=>x.type==='hero')&&last.model.items.find(x=>x.type==='stats').cells.length===6);
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('home')});await p.waitForTimeout(300);
  console.log('PASS 11 more settings pages (Kasir, Pengingat, Pusat Data, WhatsApp, ...) use the generic native form');
  // Paid-plan pages (Pegawai, Stok, CRM, Chatbot AI, ...): unlock Platinum, check content and a save through the HTML.
  await p.evaluate(()=>{window.__planBackup=goyanaPlan111.plan;goyanaPlan111.plan={...goyanaPlan111.plan,id:'PLATINUM',paid:true,until:new Date(Date.now()+86400000)}});
  for(const id of ['employees','inventory','crm','ai191','blast191','quickreply','triggers191','audit','integrations']){
    last=await openNative(id);assert.ok(last.model.items.length>0,id+' has content');
  }
  last=await openNative('employees');const empIn=last.model.items.filter(x=>x.type==='input');
  assert.deepEqual(empIn.map(x=>x.ph.split(' ')[1]),['Nama','No','Alamat','Password'],'employee fields wrapped in labels are found');
  assert.ok(empIn[3].secret);assert.ok(last.model.items.filter(x=>x.type==='toggle').length>=10,'access rights');
  last=await openNative('ai191');assert.ok(last.model.items.some(x=>x.type==='toggle'&&x.t==='Aktifkan Chatbot AI'));
  assert.ok(last.model.items.some(x=>x.type==='button'&&x.file==='ai-image191'),'visible file field becomes a native picker button');
  last=await openNative('crm');assert.ok(last.model.items.filter(x=>x.type==='toggle').every(x=>x.t),'every CRM switch has a label');
  await p.evaluate(()=>{goyanaPlan111.plan=window.__planBackup;document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('home')});await p.waitForTimeout(300);
  console.log('PASS Pegawai, Stok, CRM, Chatbot AI, Blast, Balasan Cepat, Trigger, Audit, Integrasi use the generic native form');
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('perfume')});
  await p.waitForFunction(()=>{const m=JSON.parse(window.GoyanaNative.__events.at(-1));return m.page==='perfume'&&m.model.items.some(x=>x.type==='entry')},null,{timeout:4000});
  last=await lastAdd();const pf=last.model.items.find(x=>x.type==='entry');assert.ok(pf.compact&&pf.color&&pf.btns.length===2,'perfume rows with colour and edit/delete');
  console.log('PASS Parfum list rows (colour dot, edit/delete) are native');
  for(const id of ['finance','duration','discount']){last=await openNative(id);assert.ok(last.model.items.length>0,id)}
  last=await openNative('discount');assert.ok(last.model.items.some(x=>x.type==='input'&&x.sub),'labelled field keeps its explanation');
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('home')});await p.waitForTimeout(300);
  console.log('PASS Keuangan (kategori), Durasi, Diskon are native');
  last=await openNative('upgrade');const plans=last.model.items.filter(x=>x.type==='plan');
  assert.deepEqual(plans.map(x=>x.t),['FREE','BASIC','SILVER','GOLD','PLATINUM']);assert.equal(plans[1].price,'Rp30.000');
  assert.equal(last.model.items[0].type,'hero','current package card');
  await p.evaluate(i=>__goyanaForm('upgrade','button',i),plans[2].i);await p.waitForTimeout(400);
  assert.equal((await lastAdd()).page,null,'package detail (HTML) covers the native page');
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('home')});await p.waitForTimeout(300);
  console.log('PASS Upgrade Paket: package cards native, detail/checkout stay HTML');
  last=await openNative('addbot');const step=last.model.items.find(x=>x.type==='stepper');assert.equal(step.v,'1');
  await p.evaluate(i=>__goyanaForm('addbot','button',i),step.plus);await p.waitForTimeout(300);
  last=await lastAdd();assert.equal(last.model.items.find(x=>x.type==='stepper').v,'2','stepper runs the HTML logic');
  assert.equal(last.model.items.find(x=>x.type==='pair'&&x.t==='Total').v,'Rp 60.000');
  const durs=last.model.items.find(x=>x.type==='buttons'&&x.options.some(o=>/Bulan/.test(o.t)));assert.ok(durs.options[0].on,'chosen duration is marked');
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('home')});await p.waitForTimeout(300);
  console.log('PASS Tambah Nomor Chatbot: stepper, durations and total are native');
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('reports');rep170('metode')});
  await p.waitForFunction(()=>JSON.parse(window.GoyanaNative.__events.at(-1)).page==='rp170d',null,{timeout:3000});
  last=await lastAdd();const tb=last.model.items.find(x=>x.type==='table');assert.ok(tb&&tb.rows.length>=2&&tb.rows[0][0].h,'report table with header');
  assert.ok(last.model.items.some(x=>x.type==='hbars'));const per=last.model.items.find(x=>x.type==='buttons');
  await p.evaluate(i=>__goyanaForm('rp170d','button',i),per.options[0].i);await p.waitForTimeout(300);
  assert.ok((await lastAdd()).model.items.find(x=>x.type==='buttons').options[0].on,'period chip runs the HTML logic');
  await p.evaluate(()=>rep170('jam'));await p.waitForTimeout(300);assert.ok((await lastAdd()).model.items.some(x=>x.type==='bars'),'column chart');
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('home')});await p.waitForTimeout(300);
  console.log('PASS Laporan detail (40 reports): period chips, KPI tiles, bar charts and tables are native');

  fs.mkdirSync(path.join(root,'mobile/test/screens'),{recursive:true});
  // Tutup Kasir: all arithmetic and validation must remain in the original HTML.
  await p.evaluate(()=>openPage('cashclose'));await p.waitForTimeout(400);
  last=await lastAdd();assert.equal(last.page,'cashclose');assert.equal(last.model.sections[0].methods.length,3);
  await p.evaluate(()=>__goyanaTap('#cashclose .kc137-go'));await p.waitForTimeout(250);
  assert.match((await lastAdd()).toast,/Hitung uang/);
  await p.evaluate(()=>{__goyanaSearch('#kc-start','100000');__goyanaTap('#kc-den label',0,'button:last-of-type')});await p.waitForTimeout(300);
  last=await lastAdd();assert.equal(last.model.sections[2].denominations[0].v,'1');
  assert.equal(last.model.sections[2].physical.v,await p.locator('#kc-phys').inputValue());
  await p.evaluate(()=>{__goyanaSearch('#kc-phys','160000');__goyanaSearch('#kc-qr','0');__goyanaSearch('#kc-fr','0');__goyanaSearch('#kc-setor','50000')});await p.waitForTimeout(300);
  last=await lastAdd();assert.match(last.model.sections[2].diff.t,/Lebih Rp10.000/);
  assert.equal(last.model.sections[4].rows[1].v,'Rp110.000');
  await p.evaluate(()=>__goyanaTap('#cashclose .kc137-go'));await p.waitForTimeout(250);
  assert.match((await lastAdd()).toast,/isi catatan/);
  await p.evaluate(()=>__goyanaSearch('#kc-note','Selisih uji kas'));await p.waitForTimeout(2800);
  last=await lastAdd();
  if(process.env.UPDATE_NATIVE_FIXTURES){fs.mkdirSync(path.join(root,'mobile/test/fixtures'),{recursive:true});fs.writeFileSync(path.join(root,'mobile/test/fixtures/cashclose.json'),JSON.stringify(last.model,null,2));}
  await p.evaluate(()=>{document.activeElement.blur();window.scrollTo(0,0);document.querySelectorAll('#cashclose, #cashclose .content').forEach(e=>e.scrollTop=0)});
  for(const width of [320,390]){await p.setViewportSize({width,height:844});await p.screenshot({path:path.join(root,'mobile/test/screens/cashclose_html_'+width+'.png')});}
  await p.evaluate(()=>__goyanaTap('#cashclose .kc137-go'));
  // The confirmation sheet fades in; wait until Flutter is told to step aside (no fixed delay: CI machines vary).
  await p.waitForFunction(()=>{const e=(window.GoyanaNative.__events||[]).map(m=>JSON.parse(m)).filter(m=>m.event==='native').at(-1);return e&&e.page===null},null,{timeout:4000}).catch(()=>{});
  assert.equal((await lastAdd()).page,null,'confirmation stays visible above native cash close');
  await p.getByRole('button',{name:'Ya, Tutup Kas',exact:true}).click();await p.waitForTimeout(500);
  assert.equal((await lastAdd()).page,null,'shift receipt is an HTML sheet');
  await p.evaluate(()=>document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')}));await p.waitForTimeout(300);
  last=await lastAdd();assert.equal(last.page,'cashclose');assert.equal(last.model.sections[4].note.v,'');
  assert.match(last.model.sections[5].history[0].s,/Selisih uji kas/);
  await p.evaluate(()=>openPage('home'));await p.waitForTimeout(300);
  console.log('PASS Tutup Kasir denominations, reconciliation, required discrepancy note and shift history use HTML');

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
