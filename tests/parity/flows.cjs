// Patokan HTML untuk A4 (Rincian Pesanan), A5 (Pembayaran pesanan), A7 (Kas & Tutup Kasir).
// Setiap langkah menyimpan: aksi, isi penyimpanan SEBELUM dan SESUDAH, serta model layar HTML terkait.
// Dart harus menghasilkan penyimpanan SESUDAH yang sama dari SEBELUM + aksi (kecuali aturan yang diputuskan Koko).
// Pakai: GOYANA_BROWSER_EXECUTABLE=... NODE_PATH=tests/node_modules node tests/parity/flows.cjs
const fs=require('fs'),path=require('path'),{spawnSync}=require('child_process'),{chromium}=require('playwright');
const root=path.resolve(__dirname,'../..');
const corrected=process.argv.includes('--a5-corrected');
const extra=process.argv.includes('--a5-extra')||corrected;
const out=path.join(root,'mobile/test/fixtures/parity/'+(corrected?'payments_a5_corrected.json':extra?'payments_a5_extra.json':'flows_a4_a5_a7.json'));
(async()=>{
 const prep=spawnSync('python',[path.join(root,'tools/prepare_flutter_web.py'),root,path.join(root,'tests/node_modules/@zxing/library/umd/index.min.js')],{encoding:'utf8'});
 if(prep.status)throw Error(prep.stderr||prep.stdout);
 const b=await chromium.launch({headless:true,args:['--no-sandbox'],...(process.env.GOYANA_BROWSER_EXECUTABLE?{executablePath:process.env.GOYANA_BROWSER_EXECUTABLE}:{})});
 const ctx=await b.newContext({viewport:{width:390,height:844},timezoneId:'Asia/Jakarta'}),p=await ctx.newPage();
 const errors=[];p.on('pageerror',e=>errors.push(e.message));
 await p.clock.install({time:new Date('2026-10-04T03:00:00Z')});
 await p.addInitScript(()=>{window.GoyanaNative={__events:[],postMessage(raw){if(raw.startsWith('{"event"')){this.__events.push(raw);return}const m=JSON.parse(raw);setTimeout(()=>window.__goyanaNative.finish(m.id,true,{}),5)}}});
 await p.goto(require('url').pathToFileURL(path.join(root,'mobile/assets/web/index.html')).href);await p.clock.runFor(3500);
 const closeAll=()=>p.evaluate(()=>document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')}));
 await p.evaluate(()=>{document.getElementById('ob189').hidden=true;openPage('home');document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});
  addBranch96();const f=document.querySelector('#outletedit');f.querySelector('input.profile-input').value='Uji';f.querySelector('textarea').value='Jakarta';f.querySelector('input[inputmode=tel]').value='081234567890';saveOutlet158();});
 await p.clock.runFor(500);await closeAll();
 const store=()=>p.evaluate(()=>{if(window.flushTransactions177)flushTransactions177();const s={};for(let i=0;i<localStorage.length;i++){const k=localStorage.key(i);if(k.startsWith('goyana-'))s[k]=localStorage.getItem(k)}return s});
 const lastModel=page=>p.evaluate(page=>{const e=GoyanaNative.__events.map(JSON.parse).filter(x=>x.page===page&&x.model);return e.length?e.at(-1).model:null},page);
 const detailModel=()=>p.evaluate(()=>{const e=GoyanaNative.__events.map(JSON.parse).filter(x=>x.sheet&&x.sheet.id==='g62-order-detail');return e.length?e.at(-1).sheet:null});
 // Pola mk() dari capture.cjs: pelanggan diisi langsung, tidak dipilih dari daftar.
 const mk=async(name,phone,qty,method,dur)=>{await p.evaluate(([n,ph,q,m,d])=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});
   document.getElementById('v88-name').value=n;document.getElementById('v88-phone').value=ph;document.getElementById('v88-address').value='Jakarta';saveCustomerV88();
   document.querySelector('#f61-services .f61-customerbar div b').textContent=n;window.pickedName136=n;
   f61.cart=[{id:'t',n:'Cuci Baju',name:'Cuci Baju',ic:'Kiloan',unit:'kg',price:7000,qty:q}];f61.total=7000*q;f61.dur=d||'Reguler';
   document.getElementById('f61-duration-label').textContent=f61.dur;document.getElementById('f61-handover').selectedIndex=0;f61Payment();f61Finish(m);
   document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});},[name,phone,qty,method,dur]);await p.clock.runFor(800);};
 const openDetail=async name=>{await p.evaluate(()=>openPage('orders'));await p.clock.runFor(400);
   await p.evaluate(n=>{const c=[...document.querySelectorAll('#orders .g62-ordercard')].find(c=>(c.querySelector('.g62-order-body div b')||{}).textContent===n);if(!c)throw Error('kartu tidak ada: '+n);c.click()},name);await p.clock.runFor(600);};
 const steps=[];
 const step=async(part,name,action,js,after)=>{
   const before=await store();
   if(js)await p.evaluate(js);else await action.run();
   await p.clock.runFor(900);
   if(corrected){await p.evaluate(()=>{f61Close('f61-payment');if(api115.cur()&&document.getElementById('g62-order-detail').classList.contains('show'))api115.render();__goyanaHomeRefresh()});await p.clock.runFor(400);await p.waitForTimeout(50);}
   const rec={part,name,action:action.desc,now:new Date(await p.evaluate(()=>Date.now())).toISOString(),before,after:await store(),orders:await lastModel('orders'),home:null,detail:await detailModel()};
   if(after)Object.assign(rec,await after());
   steps.push(rec);await closeAll();await p.clock.runFor(300);
 };
 if(extra){
 if(corrected){
 await mk('Hana Cash','081200000008',4,'Bayar Nanti','Reguler');await openDetail('Hana Cash');
 await step('A5','fresh_dp50_tunai',{desc:'DP 50 persen Tunai'},()=>{openPay115();payQuick115(.5);document.querySelector('#pay115-m button').click();savePay115()});
 await openDetail('Hana Cash');
 await step('A5','fresh_settle_transfer',{desc:'Pelunasan Transfer setelah DP'},()=>{openPay115();payQuick115(1);[...document.querySelectorAll('#pay115-m button')].find(b=>b.textContent.trim()==='Transfer').click();savePay115()});
 await mk('Intan QRIS','081200000009',2.5,'Bayar Nanti','Kilat');await openDetail('Intan QRIS');
 await step('A5','fresh_full_qris',{desc:'Pelunasan QRIS'},()=>{openPay115();payQuick115(1);[...document.querySelectorAll('#pay115-m button')].find(b=>b.textContent.trim()==='QRIS').click();savePay115()});
 }
 await mk('Fina Deposit','081200000006',4,'Bayar Nanti','Reguler');
 await p.evaluate(()=>{openDeposits178();const sel=document.getElementById('deposits178-customer');sel.value=[...sel.options].find(o=>o.textContent.startsWith('Fina Deposit')).value;sel.dispatchEvent(new Event('change'))});
 await step('A5','deposit_topup_transfer',{desc:'Tambah saldo Transfer Rp50000'},()=>{document.getElementById('deposits178-amount').value='50000';document.getElementById('deposits178-method').value='Transfer';document.getElementById('deposits178-save').click()});
 await openDetail('Fina Deposit');
 await step('A5','deposit_partial',{desc:'Bayar deposit Rp10000'},()=>{openPay115();document.getElementById('pay115-amt').value='10000';[...document.querySelectorAll('#pay115-m button')].find(b=>b.textContent.trim()==='Deposit').click();savePay115()});
 await openDetail('Fina Deposit');
 await step('A5','deposit_full',{desc:'Lunasi sisa Rp18000 dengan deposit'},()=>{openPay115();payDeposit91();document.getElementById('depositpay178-save').click()});
 await mk('Gina DP','081200000007',4,'Bayar Nanti','Reguler');
 await openDetail('Gina DP');
 await step('A5','dp_transfer',{desc:'DP Transfer Rp5000'},()=>{openPay115();openDp91();document.getElementById('dp178-amount').value='5000';document.getElementById('dp178-method').value='Transfer';document.getElementById('dp178-save').click()});
 await openDetail('Gina DP');
 await p.evaluate(()=>ralatPay139(null,api115.cur().id));
 await step(corrected?'A5':'A5-audit','ralat_method',{desc:'Ralat Transfer menjadi Tunai'},()=>{[...document.querySelectorAll('#rs139-m button')].find(b=>b.textContent==='Tunai').click();document.querySelector('#rs139-ch button').click();rsSave139()});
 await openDetail('Fina Deposit');
 await p.evaluate(()=>ralatPay139(null,api115.cur().id));
 await step(corrected?'A5':'A5-audit','void_deposit',{desc:'Batalkan pembayaran deposit terakhir'},()=>{document.querySelector('#rs139-ch button').click();rsVoid139()});
 if(corrected){
 await step('A5-rejected','void_deposit_twice',{desc:'Tekan ulang pembatalan deposit yang sama: tidak boleh refund dua kali'},()=>rsVoid139());
 await openDetail('Gina DP');await p.evaluate(()=>ralatPay139(null,api115.cur().id));
 await step('A5','ralat_amount',{desc:'Ralat pembayaran Tunai menjadi Rp9000'},()=>{document.getElementById('rs139-a').value='9000';document.querySelector('#rs139-ch button').click();rsSave139()});
 await openDetail('Gina DP');await p.evaluate(()=>ralatPay139(null,api115.cur().id));
 await step('A5-rejected','ralat_over_bill',{desc:'Tolak ralat Rp28001 melebihi total Rp28000'},()=>{document.getElementById('rs139-a').value='28001';document.querySelector('#rs139-ch button').click();rsSave139()});
 for(const [name,raw] of [['ralat_negative','-5000'],['ralat_fraction','5,5']]){
 await openDetail('Gina DP');await p.evaluate(()=>ralatPay139(null,api115.cur().id));
 await step('A5-rejected',name,{desc:'Tolak nominal '+raw,run:()=>p.evaluate(v=>{document.getElementById('rs139-a').value=v;document.querySelector('#rs139-ch button').click();rsSave139()},raw)},null);
 }
 await openDetail('Gina DP');await p.evaluate(()=>ralatPay139(null,api115.cur().id));
 await step('A5-rejected','ralat_disk_failure',{desc:'Gagal penyimpanan: seluruh perubahan harus rollback'},()=>{document.getElementById('rs139-a').value='10000';document.querySelector('#rs139-ch button').click();const f=window.flushTransactions177;window.flushTransactions177=()=>false;rsSave139();window.flushTransactions177=f});
 await openDetail('Fina Deposit');await p.evaluate(()=>ralatPay139(null,api115.cur().id));
 await step('A5-rejected','deposit_refund_disk_failure',{desc:'Refund deposit gagal tersimpan: saldo dan pembayaran harus rollback'},()=>{document.querySelector('#rs139-ch button').click();const f=window.flushTransactions177;window.flushTransactions177=()=>false;rsVoid139();window.flushTransactions177=f});
 await openDetail('Fina Deposit');await p.evaluate(()=>ralatPay139(null,api115.cur().id));
 await step('A5','deposit_to_cash',{desc:'Ganti pembayaran deposit Rp10000 menjadi Tunai; saldo kembali Rp50000'},()=>{document.querySelector('#rs139-m button').click();document.querySelector('#rs139-ch button').click();rsSave139()});
 await openDetail('Gina DP');await p.evaluate(()=>{KAS137.sales.length=0;flushTransactions177();ralatPay139(null,api115.cur().id)});
 await step('A5','legacy_ralat',{desc:'Ralat pembayaran shift sebelumnya menjadi Transfer Rp7000'},()=>{[...document.querySelectorAll('#rs139-m button')].find(b=>b.textContent==='Transfer').click();document.getElementById('rs139-a').value='7000';document.querySelector('#rs139-ch button').click();rsSave139()});
 await openDetail('Gina DP');await p.evaluate(()=>{KAS137.sales.length=0;flushTransactions177();ralatPay139(null,api115.cur().id)});
 await step('A5','legacy_void',{desc:'Batalkan pembayaran shift sebelumnya'},()=>{document.querySelector('#rs139-ch button').click();rsVoid139()});
 await p.reload();await p.clock.runFor(3500);await openDetail('Fina Deposit');
 const reloaded=JSON.parse((await store())['goyana-business177']);
 if(reloaded.deposits178['phone:6281200000006'].balance!==50000)throw Error('Refund tidak bertahan setelah reload');
 }
 }else{
 // ---------- A4: Rincian Pesanan (status, batal) ----------
 await mk('Ani Status','081200000001',3,'Bayar Nanti','Reguler');
 for(const [i,label] of ['proses','siap','diambil'].entries()){
   await openDetail('Ani Status');
   await step('A4','status_'+(i+1)+'_'+label,{desc:'Rincian Pesanan Ani Status: tekan tombol status utama (advanceDetail91), langkah '+(i+1)},()=>advanceDetail91());
 }
 await mk('Budi Batal','081200000002',2,'Bayar Nanti','Express');
 await openDetail('Budi Batal');
 await step('A4','batal_pelanggan',{desc:'Rincian Pesanan Budi Batal: Batalkan Pesanan, alasan "Pelanggan membatalkan"'},()=>{openSheet91('cancel91');const r=document.getElementById('cancel91-reason');r.selectedIndex=1;confirmCancel91()});
 // ---------- A5: Pembayaran pesanan yang belum lunas ----------
 await mk('Citra Bayar','081200000003',4,'Bayar Nanti','Reguler');
 await openDetail('Citra Bayar');
 await step('A5','dp50_tunai',{desc:'Citra Bayar (Rp28.000, belum bayar): Bayar → DP 50% → Tunai → Simpan'},()=>{openPay115();payQuick115(.5);const m=[...document.querySelectorAll('#pay115 button')].find(b=>b.textContent.trim()==='Tunai');m&&m.click();savePay115()});
 await openDetail('Citra Bayar');
 await step('A5','pelunasan_transfer',{desc:'Citra Bayar (sudah DP): Bayar → Lunas → Transfer → Simpan'},()=>{openPay115();payQuick115(1);const m=[...document.querySelectorAll('#pay115 button')].find(b=>b.textContent.trim()==='Transfer');m&&m.click();savePay115()});
 await mk('Dewi Qris','081200000004',2.5,'Bayar Nanti','Kilat');
 await openDetail('Dewi Qris');
 await step('A5','lunas_qris',{desc:'Dewi Qris (belum bayar, Kilat): Bayar → Lunas → QRIS → Simpan'},()=>{openPay115();payQuick115(1);const m=[...document.querySelectorAll('#pay115 button')].find(b=>b.textContent.trim()==='QRIS');m&&m.click();savePay115()});
 await mk('Eko Tunai','081200000005',5,'Tunai','Reguler');
 // ---------- A7: Kas & Tutup Kasir ----------
 await p.evaluate(()=>openPage('home'));await p.clock.runFor(500);
 const homeBefore=await lastModel('home');
 await p.evaluate(()=>openPage('cashclose'));await p.clock.runFor(500);
 const ccBefore=await lastModel('cashclose');
 await step('A7','tutup_kasir',{desc:'Tutup Kasir: modal awal 100000, uang fisik 160000, QRIS 0, transfer 0, setor 50000, catatan "Uji tutup kas", lalu Ya, Tutup Kas'},()=>{
   const set=(id,v)=>{const e=document.getElementById(id);e.value=v;['input','keyup','change'].forEach(t=>e.dispatchEvent(new Event(t,{bubbles:true})))};
   set('kc-start','100000');set('kc-phys','160000');set('kc-qr','0');set('kc-fr','0');set('kc-setor','50000');set('kc-note','Uji tutup kas');
   document.querySelector('#cashclose .kc137-go').click();
 },async()=>{await p.clock.runFor(800);
   await p.evaluate(()=>{const b=[...document.querySelectorAll('button')].find(x=>x.textContent.trim()==='Ya, Tutup Kas'&&x.offsetParent);if(b)b.click()});await p.clock.runFor(900);
   await p.clock.runFor(2000);await closeAll();await p.evaluate(()=>openPage('cashclose'));await p.clock.runFor(500);const ccAfter=await lastModel('cashclose');
   await p.evaluate(()=>openPage('home'));await p.clock.runFor(800);
   return {after:await store(),cashcloseBefore:ccBefore,cashcloseAfter:ccAfter,homeBefore,homeAfter:await lastModel('home')};});
 }
 await b.close();
 if(errors.length)throw Error('page errors: '+errors.slice(0,5).join('; '));
 const assert=require('assert/strict');
 if(corrected){for(const c of steps){if(c.part==='A5-rejected')assert.deepEqual(c.after,c.before,c.name);const b=JSON.parse(c.after['goyana-business177']);for(const card of b.orders){const id=card.fields[1][0],o=b.details[id],entries=JSON.parse(card.dataset.payments178||'[]');assert.equal(entries.reduce((n,e)=>n+e.a,0),o.paid,c.name+' history');assert.equal(Number(card.dataset.paid177),o.paid,c.name+' paid dataset')}}const refunded=JSON.parse(steps.find(c=>c.name==='void_deposit').after['goyana-business177']);assert.equal(refunded.deposits178['phone:6281200000006'].balance,40000);}
 if(!process.argv.includes('--verify-only'))fs.writeFileSync(out,JSON.stringify({note:corrected?'Patokan A5 dengan koreksi keuangan disetujui Paduka 6 Okt 2026; before -> aksi -> after.':extra?'Patokan tambahan A5 ditangkap GPT Work sesuai GOYANA-SAMPAI-SELESAI.md; A5-audit menunjukkan kasus ralat yang perlu keputusan.':'Patokan HTML A4/A5/A7. Setiap langkah: before -> aksi -> after. Ditangkap Claude.',steps}));
 console.log('Captured',steps.length,'steps ->',path.relative(root,out));
})().catch(e=>{console.error(e);process.exitCode=1});
