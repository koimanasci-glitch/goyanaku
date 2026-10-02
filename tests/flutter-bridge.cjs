// Runs the Flutter web bundle (mobile/assets/web) with a simulated GoyanaNative
// channel, proving the unchanged HTML talks to the native bridge correctly.
const {chromium}=require('playwright'),assert=require('assert/strict'),fs=require('fs'),path=require('path'),{spawnSync}=require('child_process');
const root=path.resolve(__dirname,'..'),web=path.join(root,'mobile','assets','web');
const zxing=path.join(__dirname,'node_modules','@zxing','library','umd','index.min.js');
const b0=spawnSync('python',[path.join(root,'tools/prepare_flutter_web.py'),root,zxing],{encoding:'utf8'});if(b0.status)throw Error(b0.stderr||b0.stdout);

// Fake Flutter side: records every call and answers like MainActivity/bridge.dart.
const fakeNative=()=>{window.__calls=[];window.GoyanaNative={postMessage(raw){const m=JSON.parse(raw);window.__calls.push(m);const key=m.plugin+'.'+m.method;
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

  // In a normal browser the bridge must stay inactive (web build unchanged).
  const n=await b.newPage();await n.goto(require('url').pathToFileURL(path.join(web,'index.html')).href);await n.waitForTimeout(1500);
  assert.equal(await n.evaluate(()=>!!window.__goyanaNative),false);
  console.log('PASS bridge is inert outside the Flutter app');
}finally{await b.close()}})().catch(e=>{console.error(e);process.exit(1)});
