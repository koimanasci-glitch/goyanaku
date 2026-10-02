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

  // Native Beranda: HTML reports what Flutter should draw and when.
  await p.evaluate(()=>{document.getElementById('ob189').hidden=true;openPage('home')});await p.waitForTimeout(300);
  const homes=()=>p.evaluate(()=>{const raw=window.GoyanaNative.__events||[];return raw.map(m=>JSON.parse(m)).filter(m=>m.event==='home')});
  let last=(await homes()).at(-1);assert.equal(last.visible,true);assert.equal(last.model.today,'Rp 0');assert.equal(last.model.labelReady,'Siap diambil');assert.equal(last.model.slides.length,3);
  await p.evaluate(()=>openPage('orders'));await p.waitForTimeout(300);assert.equal((await homes()).at(-1).visible,false);
  await p.evaluate(()=>__goyanaTap('#nav-home'));await p.waitForTimeout(300);assert.equal((await homes()).at(-1).visible,true);
  await p.evaluate(()=>__goyanaTap('#home .gy155-receipt-wrap button'));await p.waitForTimeout(400);
  assert.equal((await homes()).at(-1).visible,false,'a sheet opened from Beranda hides the native page');
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});openPage('home')});
  console.log('PASS Beranda data and visibility are reported to Flutter; native taps run the HTML actions');

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
