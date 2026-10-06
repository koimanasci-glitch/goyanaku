// Antar Jemput: permintaan jemput tanpa berat, tugaskan kurir, Sampai Lokasi -> Tambah Transaksi.
const {chromium}=require('playwright');const assert=require('assert/strict');
const fs=require('fs'),os=require('os'),path=require('path'),{spawnSync}=require('child_process');
const root=path.resolve(__dirname,'..');const web=fs.mkdtempSync(path.join(os.tmpdir(),'goyana-jemput-'));
const build=spawnSync('python',[path.join(root,'tools/prepare_web.py'),root,web],{encoding:'utf8'});if(build.status)throw Error(build.stderr);
fs.copyFileSync(require.resolve('@zxing/library/umd/index.min.js'),path.join(web,'zxing.min.js'));
fs.copyFileSync(path.join(path.dirname(require.resolve('@capacitor/core/package.json')),'dist/capacitor.js'),path.join(web,'capacitor.js'));
(async()=>{
const b=await chromium.launch({headless:true,args:['--no-sandbox'],...(process.env.GOYANA_BROWSER_EXECUTABLE?{executablePath:process.env.GOYANA_BROWSER_EXECUTABLE}:{})});
const p=await b.newPage({viewport:{width:390,height:844}});const errors=[];p.on('pageerror',e=>errors.push(e.message));
await p.goto(require('url').pathToFileURL(path.join(web,'index.html')).href);await p.waitForTimeout(3300);
await p.evaluate(()=>{document.getElementById('ob189').hidden=true;window.__opened=[];window.open=u=>{__opened.push(String(u));return null}});
const run=async(name,fn)=>{await fn();console.log('PASS',name)};
await run('module loads and home tile replaces Cari Transaksi',async()=>{
  assert.equal(await p.evaluate(()=>window.GY202),1);
  assert.deepEqual(await p.locator('#home .gy155-grid > button').allTextContents(),['TambahTransaksi','🛵AntarJemput','🚚Kurir','👥Pelanggan','📅Hari Ini0','🤖Chatbot']);
});
await run('tile opens the Antar Jemput page, empty at first',async()=>{
  await p.locator('#jemput202-shortcut').click();await p.waitForTimeout(150);
  assert.equal(await p.evaluate(()=>document.querySelector('.page.active').id),'jemput202');
  assert.match(await p.locator('#jm202-body').innerText(),/Belum ada penjemputan aktif/);
});
await run('creating a pickup needs name and address, saves without weight or price',async()=>{
  await p.locator('#jm202-add').click();await p.waitForTimeout(100);
  assert.equal(await p.evaluate(()=>document.querySelector('.page.active').id),'jemputnew202');
  await p.locator('#jm202-save').click();
  assert.equal(await p.evaluate(()=>GY202api.list().length),0,'empty form saves nothing');
  await p.locator('#jm202-name').fill('Bu Sari');await p.locator('#jm202-save').click();
  assert.equal(await p.evaluate(()=>GY202api.list().length),0,'address is required');
  await p.locator('#jm202-phone').fill('081234567000');await p.locator('#jm202-addr').fill('Jl. Melati 5, Cikarang');
  await p.locator('#jm202-when').selectOption('Besok · pagi');await p.locator('#jm202-whennote').fill('08.30');await p.locator('#jm202-note').fill('Lantai 2');
  await p.locator('#jm202-save').click();await p.waitForTimeout(150);
  const l=await p.evaluate(()=>GY202api.list());
  assert.equal(l.length,1);assert.equal(l[0].status,'baru');assert.equal(l[0].name,'Bu Sari');
  assert.ok(!('kg' in l[0])&&!('total' in l[0]),'no weight or price');
  assert.equal(await p.evaluate(()=>document.querySelector('.page.active').id),'jemput202');
  const t=await p.locator('#jm202-body').innerText();assert.match(t,/Bu Sari/);assert.match(t,/Menunggu kurir/);assert.match(t,/Besok · pagi · 08\.30/);
});
await run('new customer is added to the customer list once',async()=>{
  assert.equal(await p.locator('#cust59-db .cust59-row').filter({hasText:'Bu Sari'}).count(),1);
});
await run('navigation and WhatsApp use the address and phone',async()=>{
  await p.evaluate(()=>{__opened.length=0});
  await p.locator('[data-a=map]').click();await p.locator('[data-a=wa]').click();
  const o=await p.evaluate(()=>__opened);
  assert.match(o[0],/google\.com\/maps\/search\/\?api=1&query=Jl\.%20Melati%205%2C%20Cikarang/);
  assert.equal(o[1],'https://wa.me/6281234567000');
});
await run('assign needs a courier, then can send the task by WhatsApp',async()=>{
  await p.locator('[data-a=assign]').click();
  assert.equal(await p.evaluate(()=>GY202api.list()[0].status),'baru','no courier chosen: nothing happens but a message');
  await p.evaluate(()=>localStorage.setItem('goyana-couriers181',JSON.stringify([{id:'k1',name:'Budi',phone:'081311112222',active:true,outlets:[]}])));
  await p.evaluate(()=>GY202api.render());
  await p.locator('.jm202-csel').selectOption('k1');
  await p.locator('[data-a=assign]').click();await p.waitForTimeout(100);
  assert.equal(await p.evaluate(()=>GY202api.list()[0].status),'ditugaskan');
  assert.match(await p.locator('#jm202-body').innerText(),/Kurir: Budi/);
  await p.evaluate(()=>{__opened.length=0});await p.locator('[data-a=send]').click();
  const u=await p.evaluate(()=>__opened[0]);assert.match(u,/^https:\/\/wa\.me\/6281311112222\?text=/);
  const text=decodeURIComponent(u.split('text=')[1]);assert.match(text,/Bu Sari/);assert.match(text,/Jl\. Melati 5/);assert.match(text,/Timbang di lokasi/);
});
await run('Kurir page shows how many pickups are waiting',async()=>{
  await p.evaluate(()=>openCourier181('task'));await p.waitForTimeout(250);
  assert.equal(await p.locator('#jm202-note-card').count(),1);
  assert.match(await p.locator('#jm202-note-card').innerText(),/1 penjemputan menunggu/);
  await p.locator('#jm202-open').click();await p.waitForTimeout(100);
  assert.equal(await p.evaluate(()=>document.querySelector('.page.active').id),'jemput202');
});
await run('Sampai Lokasi opens Tambah Transaksi and the finished order closes the pickup',async()=>{
  await p.locator('[data-a=arrive]').click();await p.waitForTimeout(1500);
  assert.equal(await p.evaluate(()=>GY202api.list()[0].status),'sampai');
  assert.equal(await p.evaluate(()=>document.querySelector('.page.active').id),'addorder');
  assert.equal(await p.evaluate(()=>localStorage.getItem('goyana-pickup202-active')),JSON.stringify(await p.evaluate(()=>GY202api.list()[0].id)));
  await p.evaluate(()=>{document.querySelector('#f61-services .f61-customerbar div b').textContent='Bu Sari';window.pickedName136='Bu Sari';f61.cart=[{id:'t',n:'Cuci Baju',name:'Cuci Baju',ic:'Kiloan',unit:'kg',price:7000,qty:3}];f61.total=21000;f61.dur='Reguler';document.getElementById('f61-handover').value='Jemput & Antar';f61Payment();f61Finish('Bayar Nanti')});
  await p.waitForTimeout(600);
  const l=await p.evaluate(()=>GY202api.list()[0]);
  assert.equal(l.status,'selesai');assert.match(l.orderId,/^GY-/);
  const card=p.locator('#orders .g62-ordercard').first();
  assert.equal(await card.getAttribute('data-st'),'antrian','laundry is already picked up, so it starts in Antrian');
  assert.equal(await p.evaluate(()=>localStorage.getItem('goyana-pickup202-active')),null);
});
await run('finished pickups move to the Selesai tab with their order number',async()=>{
  await p.evaluate(()=>openPage('jemput202'));await p.waitForTimeout(100);
  assert.match(await p.locator('#jm202-body').innerText(),/Belum ada penjemputan aktif/);
  await p.locator('[data-f=selesai]').click();
  const t=await p.locator('#jm202-body').innerText();assert.match(t,/Bu Sari/);assert.match(t,/Transaksi: GY-/);
});
await run('cancel marks a pickup as cancelled',async()=>{
  await p.evaluate(()=>{const r=GY202api.create;document.getElementById('jm202-name').value='Pak Joko';document.getElementById('jm202-addr').value='Jl. Kenanga 2';r()});
  await p.waitForTimeout(100);
  await p.locator('[data-f=aktif]').click();
  await p.locator('[data-a=cancel]').click();await p.waitForTimeout(100);
  assert.equal(await p.evaluate(()=>GY202api.list().find(x=>x.name==='Pak Joko').status),'batal');
});
await run('data survives reload and no script errors',async()=>{
  await p.reload();await p.waitForTimeout(3300);
  assert.equal(await p.evaluate(()=>GY202api.list().length),2);
  assert.deepEqual(errors,[]);
});
await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
