/* Antar Jemput: permintaan jemput tanpa berat. Berat dan item ditimbang di lokasi lewat Tambah Transaksi.
   Data disimpan sendiri (goyana-pickup202); transaksi asli tetap dibuat oleh alur Tambah Transaksi. */
(()=>{
'use strict';
if(window.GY202)return;window.GY202=1;
const KEY='goyana-pickup202',ACTIVE='goyana-pickup202-active',CK='goyana-couriers181';
const $=id=>document.getElementById(id),qa=(s,r=document)=>[...r.querySelectorAll(s)];
const rd=(k,d)=>{try{const v=JSON.parse(localStorage.getItem(k));return v==null?d:v}catch(_){return d}};
const wr=(k,v)=>{try{localStorage.setItem(k,JSON.stringify(v))}catch(_){}};
const esc=s=>String(s==null?'':s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const toast=m=>{try{window.toast90&&window.toast90(m)}catch(_){}};
const uid=()=>'jm'+Date.now().toString(36)+Math.random().toString(36).slice(2,6);
const STATUS={baru:'Menunggu kurir',ditugaskan:'Ditugaskan',sampai:'Sudah sampai',selesai:'Selesai',batal:'Dibatalkan'};
const WHEN=['Secepatnya','Hari ini · pagi','Hari ini · siang','Hari ini · sore','Besok · pagi','Besok · siang','Besok · sore'];
let list=rd(KEY,[]);
let filter='aktif';
const save=()=>wr(KEY,list);
const outletId=()=>{try{return JSON.parse(localStorage.getItem('goyana-active-outlet180')||'""')}catch(_){return ''}};
const couriers=()=>rd(CK,[]).filter(c=>!c.deleted&&c.active!==false);
const phoneWa=p=>{let d=String(p||'').replace(/\D/g,'');if(d.startsWith('0'))d='62'+d.slice(1);return d};
const mapUrl=r=>{const m=String(r.maps||'').trim();if(/^https?:\/\//i.test(m))return m;const q=m||r.address||'';return q?'https://www.google.com/maps/search/?api=1&query='+encodeURIComponent(q):''};
const open=u=>{try{window.open(u,'_blank')}catch(_){}};
const visible=r=>!outletId()||!r.outlet||r.outlet===outletId();

/* ---------- halaman ---------- */
function ensure(){
  const host=document.querySelector('main.app')||document.querySelector('main');if(!host)return false;
  if(!$('jemput202')){
    const s=document.createElement('section');s.id='jemput202';s.className='page';
    s.innerHTML='<div class="subhead"><button class="back" type="button" onclick="openPage(\'home\')">‹</button><b>ANTAR JEMPUT</b></div><div class="content"><div id="jm202-body"></div></div>';
    host.appendChild(s);
    s.addEventListener('click',onListClick);
    s.addEventListener('change',e=>{const sel=e.target.closest('.jm202-csel');if(!sel)return;const r=list.find(x=>x.id===sel.dataset.id);if(r){r.courierId=sel.value;save()}});
  }
  if(!$('jemputnew202')){
    const s=document.createElement('section');s.id='jemputnew202';s.className='page';
    s.innerHTML='<div class="subhead"><button class="back" type="button" onclick="openPage(\'jemput202\')">‹</button><b>PENJEMPUTAN BARU</b></div><div class="content">'+
      '<div class="g181-note">Berat dan item tidak diisi di sini. Kurir menimbangnya di lokasi, lalu transaksi dibuat saat tombol Sampai Lokasi ditekan.</div>'+
      '<input id="jm202-name" class="g181-input" placeholder="Nama pelanggan" autocomplete="off">'+
      '<input id="jm202-phone" class="g181-input" placeholder="No WhatsApp pelanggan" inputmode="tel" autocomplete="off">'+
      '<input id="jm202-addr" class="g181-input" placeholder="Alamat penjemputan" autocomplete="off">'+
      '<input id="jm202-maps" class="g181-input" placeholder="Link Google Maps (opsional)" autocomplete="off">'+
      '<select id="jm202-when" class="g181-input">'+WHEN.map(w=>'<option>'+w+'</option>').join('')+'</select>'+
      '<input id="jm202-whennote" class="g181-input" placeholder="Jam tertentu, misalnya 15.30 (opsional)" autocomplete="off">'+
      '<input id="jm202-svc" class="g181-input" placeholder="Layanan yang diinginkan (opsional)" autocomplete="off">'+
      '<input id="jm202-note" class="g181-input" placeholder="Catatan untuk kurir (opsional)" autocomplete="off">'+
      '<button id="jm202-save" class="g181-tab on" type="button">Buat Penjemputan</button></div>';
    host.appendChild(s);
    $('jm202-save').onclick=create;
  }
  return true;
}
function whenText(r){return [r.when,r.whenNote].filter(Boolean).join(' · ')}
function render(){
  if(!ensure())return;
  list=rd(KEY,list);
  const body=$('jm202-body');
  const done=r=>r.status==='selesai'||r.status==='batal';
  const rows=list.filter(visible).filter(r=>filter==='aktif'?!done(r):done(r)).sort((a,b)=>(b.createdAt||0)-(a.createdAt||0));
  const cs=couriers();
  body.innerHTML='<div class="g181-addrow"><button id="jm202-add" class="g181-tab on" type="button">+ Buat Penjemputan</button></div>'+
    '<div class="g181-tabs"><button class="g181-tab'+(filter==='aktif'?' on':'')+'" data-f="aktif" type="button">Aktif</button><button class="g181-tab'+(filter==='selesai'?' on':'')+'" data-f="selesai" type="button">Selesai</button></div>'+
    (rows.length?rows.map(r=>card(r,cs)).join(''):'<div class="g181-note">'+(filter==='aktif'?'Belum ada penjemputan aktif. Tekan + Buat Penjemputan.':'Belum ada penjemputan selesai.')+'</div>');
}
function card(r,cs){
  const k=cs.find(c=>c.id===r.courierId)||rd(CK,[]).find(c=>c.id===r.courierId);
  const head=(r.status==='sampai'?'📍 ':r.status==='selesai'?'✅ ':r.status==='batal'?'✖ ':'🛵 ')+esc(r.name);
  const opts=cs.map(c=>'<option value="'+esc(c.id)+'"'+(c.id===r.courierId?' selected':'')+'>'+esc(c.name)+'</option>').join('');
  const act=[];
  if(r.status!=='selesai'&&r.status!=='batal'){
    act.push('<button type="button" data-a="map">Navigasi</button>');
    if(r.phone)act.push('<button type="button" data-a="wa">WhatsApp</button>');
    if(r.status==='baru'||r.status==='ditugaskan')act.push('<button type="button" data-a="assign">Tugaskan</button>');
    if(r.status==='ditugaskan'&&k&&k.phone)act.push('<button type="button" data-a="send">Kirim ke Kurir</button>');
    act.push('<button type="button" class="main" data-a="arrive">'+(r.status==='sampai'?'Lanjut Transaksi':'Sampai Lokasi')+'</button>');
    act.push('<button type="button" data-a="cancel">Batalkan</button>');
  }
  return '<div class="g181-card" data-id="'+esc(r.id)+'"><b>'+head+'</b>'+
    '<small>'+esc(whenText(r))+' · '+esc(STATUS[r.status]||r.status)+'</small>'+
    '<small>'+esc(r.address||'Alamat belum diisi')+'</small>'+
    (r.service?'<small>Layanan: '+esc(r.service)+'</small>':'')+
    (r.note?'<small>Catatan: '+esc(r.note)+'</small>':'')+
    (k?'<small>Kurir: '+esc(k.name)+'</small>':'')+
    (r.orderId?'<small>Transaksi: '+esc(r.orderId)+'</small>':'')+
    (r.status==='baru'||r.status==='ditugaskan'?'<select class="g181-input jm202-csel" data-id="'+esc(r.id)+'"><option value="">Pilih kurir</option>'+opts+'</select>':'')+
    (act.length?'<div class="g181-actions">'+act.join('')+'</div>':'')+'</div>';
}

/* ---------- aksi ---------- */
function create(){
  const v=id=>($(id)?.value||'').trim();
  const name=v('jm202-name'),phone=v('jm202-phone'),addr=v('jm202-addr');
  if(!name)return toast('Isi nama pelanggan'),false;
  if(!addr&&!v('jm202-maps'))return toast('Isi alamat atau link Maps'),false;
  const r={id:uid(),name,phone,address:addr,maps:v('jm202-maps'),when:$('jm202-when').value,whenNote:v('jm202-whennote'),service:v('jm202-svc'),note:v('jm202-note'),status:'baru',createdAt:Date.now(),outlet:outletId()};
  list=rd(KEY,list);list.push(r);save();
  ['jm202-name','jm202-phone','jm202-addr','jm202-maps','jm202-whennote','jm202-svc','jm202-note'].forEach(id=>{$(id).value=''});
  $('jm202-when').selectedIndex=0;
  ensureCustomer(r);
  filter='aktif';window.openPage('jemput202');render();toast('Penjemputan dibuat');
  return true;
}
/* Pelanggan baru ikut masuk daftar pelanggan lewat alur yang sudah ada (butuh nama dan no HP). */
function ensureCustomer(r){
  try{
    const exists=qa('#cust59-db .cust59-row').some(x=>(x.querySelector('b')?.textContent||'').trim().toLowerCase()===r.name.toLowerCase());
    if(exists||String(r.phone).replace(/\D/g,'').length<9||!$('v88-name')||typeof window.saveCustomerV88!=='function')return;
    $('v88-name').value=r.name;$('v88-phone').value=r.phone;if($('v88-address'))$('v88-address').value=r.address||'';
    window.saveCustomerV88();
    const row=qa('#cust59-db .cust59-row').find(x=>(x.querySelector('b')?.textContent||'').trim().toLowerCase()===r.name.toLowerCase());
    if(row&&r.maps)row.dataset.maps=r.maps;
    if(row&&r.phone)row.dataset.phone=r.phone;
  }catch(e){console.warn('GY202 customer',e)}
}
function setStatus(r,s){r.status=s;r[s+'At']=Date.now();save();render()}
function taskText(r,k){
  return ['Jemput cucian','Pelanggan: '+r.name+(r.phone?' ('+r.phone+')':''),'Alamat: '+(r.address||'-'),'Maps: '+(mapUrl(r)||'-'),'Waktu: '+(whenText(r)||'-'),r.service?'Layanan: '+r.service:'',r.note?'Catatan: '+r.note:'','Timbang di lokasi, lalu isi berat di aplikasi.'].filter(Boolean).join('\n')+'\n\nSalam, '+(k?k.name:'')
}
function onListClick(e){
  const tab=e.target.closest('[data-f]');if(tab){filter=tab.dataset.f;render();return}
  if(e.target.closest('#jm202-add')){ensure();window.openPage('jemputnew202');return}
  const b=e.target.closest('[data-a]');if(!b)return;
  const el=b.closest('[data-id]');const r=list.find(x=>x.id===el.dataset.id);if(!r)return;
  const a=b.dataset.a,cs=rd(CK,[]);
  if(a==='map'){const u=mapUrl(r);return u?open(u):toast('Alamat belum diisi')}
  if(a==='wa'){const p=phoneWa(r.phone);return p?open('https://wa.me/'+p):toast('Nomor WhatsApp belum ada')}
  if(a==='assign'){
    const sel=el.querySelector('.jm202-csel');const id=sel?sel.value:r.courierId;
    if(!id)return toast('Pilih kurir dulu');
    r.courierId=id;r.status='ditugaskan';r.ditugaskanAt=Date.now();save();render();
    const k=cs.find(c=>c.id===id);toast('Ditugaskan ke '+(k?k.name:'kurir')+(k&&k.phone?' · tekan Kirim ke Kurir untuk mengabari lewat WhatsApp':''));return;
  }
  if(a==='send'){
    const k=cs.find(c=>c.id===r.courierId);const p=k&&phoneWa(k.phone);
    return p?open('https://wa.me/'+p+'?text='+encodeURIComponent(taskText(r,k))):toast('Nomor WhatsApp kurir belum ada');
  }
  if(a==='arrive'){
    if(r.status!=='sampai'){r.status='sampai';r.sampaiAt=Date.now();save()}
    return startOrder(r);
  }
  if(a==='cancel'){
    setStatus(r,'batal');toast('Penjemputan dibatalkan');
  }
}

/* ---------- Sampai Lokasi: Tambah Transaksi untuk pelanggan ini ---------- */
function startOrder(r){
  wr(ACTIVE,r.id);
  window.openPage('addorder');
  let tries=0;
  const pick=()=>{
    const rows=qa('#f61-customer .f61-person');
    const row=rows.find(x=>(x.querySelector('div b')?.textContent||'').trim().toLowerCase()===r.name.toLowerCase());
    if(row){const btn=row.querySelector('button');if(btn){btn.click();toast('Timbang barang, lalu pilih ongkos kirim di opsi pesanan');return}}
    if(++tries<8)return setTimeout(pick,150);
    toast('Pilih atau tambahkan pelanggan "'+r.name+'", lalu timbang barang');
  };
  setTimeout(pick,200);
}
/* Transaksi selesai dibuat: penjemputan ditandai selesai, pesanan masuk Antrian (barang sudah dibawa). */
function hookFinish(){
  const old=window.f61Finish;if(typeof old!=='function'||old.g202)return;
  const fn=function(){
    const id=rd(ACTIVE,'');
    const before=new Set(qa('#orders .g62-ordercard'));
    const result=old.apply(this,arguments);
    if(!id)return result;
    setTimeout(()=>{
      const c=qa('#orders .g62-ordercard').find(x=>!before.has(x));
      const r=(list=rd(KEY,list)).find(x=>x.id===id);if(!c||!r)return;
      if(c.dataset.st==='jemput'){
        c.dataset.st='antrian';c.dataset.ts133=String(Date.now());c.dataset.picked='1';
        try{window.paint108&&window.paint108(c);window.counts108&&window.counts108();window.apply108&&window.apply108();window.flushTransactions177&&window.flushTransactions177()}catch(_){}
      }
      r.status='selesai';r.selesaiAt=Date.now();r.orderId=(c.querySelector('.g62-order-top b')?.textContent||'').trim();
      save();try{localStorage.removeItem(ACTIVE)}catch(_){}
      render();
    },150);
    return result;
  };
  fn.g202=1;window.f61Finish=fn;
}

/* ---------- beranda, Kurir, navigasi ---------- */
function home(){
  const g=document.querySelector('#home .gy155-grid');if(!g||g.dataset.g202)return;
  const kids=[...g.children];if(kids.length<2)return;g.dataset.g202='1';
  const b=document.createElement('button');b.type='button';b.id='jemput202-shortcut';
  b.innerHTML='<span class="gy155-icon" style="font-size:30px">🛵</span><span>Antar<br>Jemput</span>';
  b.onclick=()=>{ensure();window.openPage('jemput202')};
  g.replaceChild(b,kids[1]);
}
function courierNote(){
  const body=$('courier181-body');if(!body||body.querySelector('#jm202-note-card'))return;
  list=rd(KEY,list);const n=list.filter(visible).filter(r=>r.status!=='selesai'&&r.status!=='batal').length;if(!n)return;
  const d=document.createElement('div');d.id='jm202-note-card';d.className='g181-card';
  d.innerHTML='<b>🛵 '+n+' penjemputan menunggu</b><small>Buka daftar Antar Jemput untuk menugaskan kurir atau menimbang di lokasi.</small><div class="g181-actions"><button type="button" class="main" id="jm202-open">Buka Antar Jemput</button></div>';
  body.insertBefore(d,body.firstChild);
  d.querySelector('#jm202-open').onclick=()=>{ensure();window.openPage('jemput202')};
}
function boot(){
  home();ensure();hookFinish();
  const open0=window.openPage;
  if(typeof open0==='function'&&!open0.g202){
    const f=function(id){const r=open0.apply(this,arguments);if(id==='jemput202')render();return r};
    f.g202=1;window.openPage=f;
  }
  const mo=new MutationObserver(()=>{courierNote()});
  const start=()=>{const cp=$('courier181');if(cp)mo.observe(cp,{childList:true,subtree:true});else setTimeout(start,1500)};
  start();
  window.GY202api={render,list:()=>rd(KEY,[]),create};
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot);else boot();
})();
