/* GOYANA v183: dynamic pickup/delivery timeline, owner transport tariff, transport accounting, UI leak cleanup */
(()=>{'use strict';
if(window.GY183)return;window.GY183=1;
const $=id=>document.getElementById(id),qa=(s,r=document)=>[...r.querySelectorAll(s)];
const toast=s=>window.toast90?window.toast90(s):alert(s);
const rd=(k,d)=>{try{const v=localStorage.getItem(k);return v==null?d:JSON.parse(v)}catch(e){return d}};
const wr=(k,v)=>{try{localStorage.setItem(k,JSON.stringify(v));return true}catch(e){toast('Penyimpanan perangkat penuh');return false}};
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const rp=n=>'Rp'+Math.round(+n||0).toLocaleString('id-ID');
const cards=()=>qa('#orders .g62-ordercard');
const oid=c=>(c?.querySelector('.g62-order-top b')?.textContent||'').trim();
const outlet=()=>{let a=rd('goyana-outlets180',[]);if(!Array.isArray(a))a=[];const id=rd('goyana-active-outlet180','')||a[0]?.id||'default';return{id,name:a.find(x=>x.id===id)?.name||a[0]?.name||'Outlet Aktif'}};
const KEY='goyana-transport183';
function allCfg(){const x=rd(KEY,{});return x&&typeof x==='object'?x:{}}
function cfg(){const o=outlet(),all=allCfg(),x=all[o.id]||{};return Object.assign({mode:'free',fixed:0,pickup:0,delivery:0,roundtrip:0,perKm:0,freeRadius:0,manual:false},x)}
function saveCfg(v){const o=outlet(),all=allCfg();all[o.id]=v;wr(KEY,all)}
function handover(){return String($('f61-handover')?.value||'')}
function tripType(h){h=String(h||'');const pick=/jemput/i.test(h),del=/antar|diantar/i.test(h);if(pick&&del)return'roundtrip';if(pick)return'pickup';if(del)return'delivery';return'none'}
function feeFor(h){const t=tripType(h),s=cfg();if(t==='none'||s.mode==='free')return 0;if(s.mode==='fixed')return Math.max(0,+s.fixed||0);if(s.mode==='split')return t==='pickup'?Math.max(0,+s.pickup||0):t==='delivery'?Math.max(0,+s.delivery||0):Math.max(0,(+s.pickup||0)+(+s.delivery||0));if(s.mode==='roundtrip')return t==='roundtrip'?Math.max(0,+s.roundtrip||0):t==='pickup'?Math.max(0,+s.pickup||0):Math.max(0,+s.delivery||0);return 0}

const css=document.createElement('style');css.id='gy183-css';css.textContent=`
#steps91.g183-six{display:grid!important;grid-template-columns:repeat(6,minmax(0,1fr))!important;gap:0!important}
#steps91.g183-six>div{min-width:0!important;text-align:center!important;padding:0 2px!important}
#steps91.g183-six>div span,#steps91.g183-six>div small,#steps91.g183-six>div b{font-size:9px!important;white-space:normal!important;line-height:1.15!important}
#steps91.g183-six>div:before{transform:scale(.86)}
.g183-transport-line{display:flex;justify-content:space-between;gap:12px;padding:10px 0;border-top:1px solid #edf0f3;font-size:12px}
.g183-transport-line span{color:#9299a6}.g183-transport-line b{color:#20242b}
.g183-owner-note{font-size:9px;color:#7f8793;line-height:1.4;background:#f7f8fa;border-radius:11px;padding:9px;margin:8px 0 12px}
.g183-radio{display:flex;gap:9px;align-items:flex-start;padding:11px 0;border-bottom:1px solid #edf0f3}.g183-radio input{margin-top:2px}.g183-radio b,.g183-radio small{display:block}.g183-radio small{font-size:9px;color:#9098a5;margin-top:3px}
.g183-two{display:grid;grid-template-columns:1fr 1fr;gap:8px}.g183-field label{display:block;font-size:9px;color:#8c94a0;margin:8px 0 4px}.g183-field input{width:100%;box-sizing:border-box;border:1px solid #dfe3e8;border-radius:10px;padding:10px;font:inherit}
.g183-switch{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:11px 0}.g183-switch small{display:block;color:#929aa7;font-size:9px;margin-top:3px}
#transport183 .primary{margin-top:12px}
`;document.head.appendChild(css);

function ensurePage(){if($('transport183'))return;const sec=document.createElement('section');sec.id='transport183';sec.className='page';sec.innerHTML=`<div class="subhead"><button class="back" type="button">‹</button><b>TARIF TRANSPORTASI</b></div><div class="content" style="padding-bottom:110px"><div class="g183-owner-note">Tarif ini diatur oleh owner per outlet. Pilihan pertama selalu <b>Gratis Transportasi</b>. Kasir hanya mengikuti pengaturan owner.</div><div id="g183-modes"></div><div id="g183-fields"></div><div class="g183-switch"><div><b>Izinkan kasir ubah ongkir manual</b><small>Jika aktif, perubahan wajib masuk Audit Log saat backend tersedia.</small></div><input id="g183-manual" type="checkbox"></div><button id="g183-save" class="primary" type="button">SIMPAN TARIF</button></div>`;document.querySelector('main.app')?.appendChild(sec);sec.querySelector('.back').onclick=()=>openPage('settings');$('g183-save').onclick=saveTransport;}
function modes(){return[
 ['free','Gratis Transportasi','Default. Tidak ada biaya jemput/antar.'],
 ['fixed','Tarif Tetap','Satu nominal transportasi per order antar/jemput.'],
 ['split','Jemput & Antar Terpisah','Owner menentukan tarif jemput dan tarif antar secara terpisah.'],
 ['roundtrip','Tarif Pulang-Pergi','Satu tarif khusus jika order menggunakan jemput + antar.'],
 ['distance','Tarif per Jarak','Disiapkan untuk Maps API/Laravel. Belum dihitung otomatis di prototype offline.']
]}
function paintSettings(){ensurePage();const s=cfg(),m=$('g183-modes');m.innerHTML=modes().map((x,i)=>`<label class="g183-radio"><input type="radio" name="g183-mode" value="${x[0]}" ${s.mode===x[0]?'checked':''}><div><b>${i===0?'1. ':''}${x[1]}</b><small>${x[2]}</small></div></label>`).join('');qa('input[name="g183-mode"]',m).forEach(x=>x.onchange=()=>paintFields(x.value,s));$('g183-manual').checked=!!s.manual;paintFields(s.mode,s)}
function field(id,label,val){return`<div class="g183-field"><label for="${id}">${label}</label><input id="${id}" type="number" min="0" inputmode="numeric" value="${Math.max(0,+val||0)}"></div>`}
function paintFields(mode,s=cfg()){const f=$('g183-fields');if(mode==='free')f.innerHTML='<div class="g183-owner-note">Order antar/jemput tidak menambah biaya transportasi.</div>';else if(mode==='fixed')f.innerHTML=field('g183-fixed','Tarif transportasi per order',s.fixed);else if(mode==='split')f.innerHTML='<div class="g183-two">'+field('g183-pickup','Tarif jemput',s.pickup)+field('g183-delivery','Tarif antar',s.delivery)+'</div>';else if(mode==='roundtrip')f.innerHTML=field('g183-roundtrip','Tarif jemput + antar (pulang-pergi)',s.roundtrip)+'<div class="g183-two">'+field('g183-pickup','Jika hanya jemput',s.pickup)+field('g183-delivery','Jika hanya antar',s.delivery)+'</div>';else f.innerHTML='<div class="g183-two">'+field('g183-perkm','Tarif per km',s.perKm)+field('g183-radius','Radius gratis (km)',s.freeRadius)+'</div><div class="g183-owner-note">Mode per jarak baru dihitung otomatis setelah Maps API dan Laravel aktif. Untuk prototype, biaya otomatis Rp0 agar tidak menagih jarak secara salah.</div>'}
function val(id){return Math.max(0,Number($(id)?.value)||0)}
function saveTransport(){const mode=document.querySelector('input[name="g183-mode"]:checked')?.value||'free',s=cfg();Object.assign(s,{mode,manual:$('g183-manual').checked,fixed:val('g183-fixed'),pickup:val('g183-pickup'),delivery:val('g183-delivery'),roundtrip:val('g183-roundtrip'),perKm:val('g183-perkm'),freeRadius:val('g183-radius')});saveCfg(s);toast(mode==='free'?'Transportasi diset GRATIS':'Tarif transportasi tersimpan');openPage('settings')}
window.openTransport183=()=>{ensurePage();paintSettings();openPage('transport183')};
function addMenu(){const root=$('settings');if(!root||root.querySelector('[data-g183-transport]'))return;const candidates=qa('button',root);let anchor=candidates.find(b=>/antar.?jemput/i.test(b.textContent));const b=document.createElement('button');b.type='button';b.dataset.g183Transport='1';b.innerHTML='<span>🚚</span><div><b>Tarif Transportasi</b><small>Gratis, tarif tetap, jemput/antar, pulang-pergi</small></div><i>›</i>';b.onclick=()=>openTransport183();if(anchor?.parentElement)anchor.after(b);else{const box=root.querySelector('.st171-b')||root.querySelector('.content');box?.appendChild(b)}}

function hookPayment(){if(!window.f61Payment||window.f61Payment.g183)return;const old=window.f61Payment;const fn=function(){try{const cur=Number(window.f61?.total)||0,prev=Number(window.f61?._transport183)||0,prevBase=Number(window.f61?._transportBase183);let base=cur;if(Number.isFinite(prevBase)&&Math.abs(cur-(prevBase+prev))<1)base=prevBase;const h=handover(),fee=feeFor(h);if(window.f61){f61._transportBase183=base;f61._transport183=fee;f61._transportType183=tripType(h);f61.total=base+fee}}catch(e){}return old.apply(this,arguments)};fn.g183=1;window.f61Payment=fn}
function hookFinish(){if(!window.f61Finish||window.f61Finish.g183)return;const old=window.f61Finish;const fn=function(){const before=new Set(cards()),h=handover(),fee=Number(window.f61?._transport183)||feeFor(h),type=tripType(h),res=old.apply(this,arguments),c=cards().find(x=>!before.has(x));if(c&&type!=='none'){c.dataset.antar='1';c.dataset.transport183=String(fee);c.dataset.transportType183=type;if(/jemput/i.test(h)){c.dataset.st='jemput';const tg=c.querySelector('.g62-order-top i');if(tg){tg.textContent='Penjemputan';tg.className='jemput'}const nx=c.querySelector('.next91');if(nx)nx.textContent='Sudah Dijemput ›'}try{const id=oid(c),o=window.orderData177?.[id];if(o)o.ongkir=fee}catch(e){}window.paint108?.(c);window.counts108?.();window.apply108?.();window.flushTransactions177?.()}return res};fn.g183=1;window.f61Finish=fn}

let current=null;
document.addEventListener('click',e=>{const c=e.target.closest?.('.g62-ordercard');if(c)current=c},true);
function stepHTML(labels){return labels.map((x,i)=>`<div data-g183-step="${i}"><i>${i+1}</i><span>${x}</span></div>`).join('')}
function stateIndex(st){if(st==='jemput')return 0;if(st==='antrian')return 1;if(/^(cuci|kering|setrika|packing|proses)$/.test(st))return 2;if(st==='siap'||st==='telat')return 3;if(st==='diantar')return 4;if(st==='diambil')return 5;return 0}
function renderTimeline(){const p=$('steps91');if(!p||!current)return;const antar=current.dataset.antar==='1';if(!antar){if(p.dataset.g183==='1'){p.classList.remove('g183-six');p.dataset.g183='0';p.innerHTML=stepHTML(['Diterima','Proses','Siap Ambil','Diambil'])}return}const labels=['Penjemputan','Diterima Outlet','Proses','Siap','Pengantaran','Diterima Pelanggan'];if(p.dataset.g183!=='1'){p.dataset.g183='1';p.classList.add('g183-six');p.innerHTML=stepHTML(labels)}const idx=stateIndex(current.dataset.st);qa(':scope>div',p).forEach((d,i)=>{d.className=i<idx?'done':i===idx?'on':''});const status=$('od91-status');if(status){const names={jemput:'Penjemputan',antrian:'Antrian Outlet',cuci:'Proses · Cuci',kering:'Proses · Kering',setrika:'Proses · Setrika',packing:'Proses · Packing',siap:'Siap Diantar',telat:'Siap Diantar',diantar:'Pengantaran',diambil:'Diterima Pelanggan'};status.textContent=names[current.dataset.st]||status.textContent}renderTransportDetail()}
function renderTransportDetail(){if(!current)return;const fee=Number(current.dataset.transport183)||0,type=current.dataset.transportType183||'roundtrip';let host=$('orderdetail')?.querySelector('.g62-detailrows')||document.querySelector('#orderdetail .g62-detailrows')||document.querySelector('.g62-detailrows');if(!host)return;let row=host.querySelector('.g183-transport-line');if(!row){row=document.createElement('div');row.className='g183-transport-line';host.appendChild(row)}const lbl=type==='pickup'?'Transportasi Jemput':type==='delivery'?'Transportasi Antar':'Transportasi Jemput + Antar';row.innerHTML=`<span>${lbl}</span><b>${fee?rp(fee):'GRATIS'}</b>`;try{const o=window.orderData177?.[oid(current)];if(o)o.ongkir=fee}catch(e){}}
const obs=new MutationObserver(()=>{if(document.querySelector('#orderdetail.active,#orderdetail.page.active')||$('steps91'))setTimeout(renderTimeline,0);addMenu();cleanLeaks()});obs.observe(document.body,{subtree:true,childList:true,attributes:true,attributeFilter:['class','data-st']});

function cleanLeaks(){const root=document.body;if(!root)return;const tw=document.createTreeWalker(root,NodeFilter.SHOW_TEXT);const bad=[];let n;while(n=tw.nextNode()){const t=n.nodeValue||'';if(t.length>120&&(/sendReceiptWA106\s*=\s*function/.test(t)||/contentWindow\.print\(\)/.test(t)&&/doc\.close/.test(t)||/navigator\.canShare\s*\(\{files/.test(t)))bad.push(n)}bad.forEach(x=>x.nodeValue='')}

function boot(){ensurePage();addMenu();hookPayment();hookFinish();cleanLeaks();setTimeout(()=>{addMenu();hookPayment();hookFinish();cleanLeaks()},700)}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot);else boot();
})();
