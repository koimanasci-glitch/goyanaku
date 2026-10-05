const fs=require('fs'),path=require('path'),assert=require('assert/strict');
const root=path.resolve(__dirname,'../..');
const ids=['f61-print','hist115','photo115','wa131','wa138','rm138s','rs139','contacts178','guide135','api135','pay111','upgrade-pay-modal','g181-modal','td175'];
module.exports=async function capture(browser,write=false){
 const cases=[],p=await browser.newPage({viewport:{width:390,height:844},timezoneId:'Asia/Jakarta'});
 try{
  await p.clock.install({time:new Date('2026-10-05T01:00:00Z')});
  await p.addInitScript(()=>{localStorage.clear();Math.random=()=>0.25;window.open=()=>null;
   window.GoyanaNative={__events:[],postMessage(raw){if(raw.startsWith('{"event"')){this.__events.push(JSON.parse(raw));return}const m=JSON.parse(raw);
    const data=m.method==='insets'?{top:31}:m.method==='requestAccess'?{granted:true}:m.method==='contacts'?{contacts:[{name:'Budi Uji',phone:'081234000001'},{name:'Sari Uji',phone:'081234000002'}]}:{};
    setTimeout(()=>__goyanaNative.finish(m.id,true,data),5)}}});
  for(const id of ids)for(const width of [390,320]){
   await p.setViewportSize({width,height:844});await p.goto(require('url').pathToFileURL(path.join(root,'mobile/assets/web/index.html')).href);await p.clock.setFixedTime(new Date('2026-10-05T01:00:00Z'));await p.clock.runFor(3500);
   await p.evaluate(async faces=>{for(const face of faces){const f=new FontFace('Poppins','url(data:font/ttf;base64,'+face.data+')',{weight:face.weight});document.fonts.add(await f.load())}await document.fonts.ready},[['Regular','400'],['Medium','500'],['SemiBold','600']].map(([n,weight])=>({weight,data:fs.readFileSync(path.join(root,'mobile/assets/fonts/Poppins-'+n+'.ttf')).toString('base64')})));
   await p.evaluate(id=>{document.getElementById('ob189').hidden=true;openPage('home');
    goyanaPlan111.plan={...goyanaPlan111.plan,id:'PLATINUM',paid:true,until:'2027-01-01T00:00:00Z'};
    if(['f61-print','hist115','photo115','wa131','wa138','rm138s','rs139'].includes(id)){
     addBranch96();const f=document.querySelector('#outletedit');f.querySelector('input.profile-input').value='Uji B12';f.querySelector('textarea').value='Jakarta';f.querySelector('input[inputmode=tel]').value='081234000000';saveOutlet158();
     document.getElementById('v88-name').value='Budi Uji';document.getElementById('v88-phone').value='081234000001';document.getElementById('v88-address').value='Jakarta';saveCustomerV88();
     document.querySelector('#f61-services .f61-customerbar div b').textContent='Budi Uji';window.pickedName136='Budi Uji';f61.cart=[{id:'t',n:'Cuci Baju',name:'Cuci Baju',ic:'Kiloan',unit:'kg',price:7000,qty:2}];f61.total=14000;f61.dur='Reguler';f61Payment();f61Finish(id==='rs139'?'Tunai':'Bayar Nanti');
    }
   },id);await p.clock.runFor(900);
   await p.evaluate(id=>{document.querySelectorAll('.show').forEach(e=>e.classList.remove('show'));
    if(['hist115','photo115','wa131','wa138','rm138s','rs139'].includes(id)){openPage('orders');document.querySelector('#orders .g62-ordercard').click()}
   },id);await p.clock.runFor(600);
   await p.evaluate(async id=>{
    if(id==='f61-print'){openPage('addorder');document.getElementById(id).classList.add('show')}
    else if(id==='hist115')openHist115();
    else if(id==='photo115')openPhoto115();
    else if(id==='wa131'){openReceipt106('detail');closeSheet91('rc106');sendReceiptWA106()}
    else if(id==='wa138'){const c=document.querySelector('#orders .g62-ordercard');c.dataset.st='siap';c.dataset.siap138=String(Date.now()-8*86400000);remSend138(c.querySelector('.g62-order-top b').textContent.trim())}
    else if(id==='rm138s'){const c=document.querySelector('#orders .g62-ordercard');c.dataset.st='siap';c.dataset.siap138=String(Date.now()-8*86400000);openRemind138()}
    else if(id==='rs139')ralatPay139(null,api115.cur().id);
    else if(id==='contacts178')await importContacts178();
    else if(id==='guide135'){openPage('helpcenter');document.querySelector('#helpcenter .v50list button').click()}
    else if(id==='api135'){openPage('integrations');[...document.querySelectorAll('#integrations .row')].find(r=>r.textContent.includes('API Goyana')).click()}
    else if(id==='pay111'){openPage('checkout111');openSheet91(id)}
    else if(id==='upgrade-pay-modal'){openPage('upgrade');document.getElementById(id).classList.add('show')}
    else if(id==='g181-modal'){openPage('inventory');[...document.querySelectorAll('#inventory button')].find(b=>b.textContent.includes('Tambah Bahan')).click()}
    else if(id==='td175'){openPage('adm175');openSheet91(id)}
   },id);await p.clock.runFor(800);
   if(id==='rm138s'){await p.evaluate(()=>{const c=document.querySelector('#orders .g62-ordercard');c.dataset.siap138=String(Date.now()-8*86400000);openRemind138()});await p.clock.runFor(200)}
   // Isolate the already-populated target for capture, without changing production routing.
   await p.evaluate(id=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!==id)e.classList.remove('show')});document.getElementById(id).classList.add('show');__goyanaHomeRefresh()},id);await p.clock.runFor(500);
   const record=async state=>{
    const event=await p.evaluate(id=>GoyanaNative.__events.filter(e=>e.sheet?.id===id).at(-1),id);
    assert.ok(event?.sheet?.mirror,id+' '+width+' '+state+' mirror');
    const actions=await p.evaluate(id=>{const e=document.getElementById(id);return {buttons:[...e.querySelectorAll('button')].filter(b=>b.type!=='file').map((b,i)=>({i,t:b.textContent.trim()})),inputs:[...e.querySelectorAll('input:not([type=file]):not([type=checkbox]):not([type=radio]),textarea,select')].map((v,i)=>({i,v:v.tagName==='SELECT'?v.selectedIndex:v.value}))}},id);
    function check(n){if(!n||typeof n!=='object')return;if(typeof n.b==='number')assert.ok(n.b>=0&&n.b<actions.buttons.length,id+' button index');if(n.input&&n.input.i>=0)assert.ok(n.input.i<actions.inputs.length,id+' input index');for(const c of n.ch||[])check(c);for(const c of n.spans||[])check(c)}check(event.sheet.mirror.box);
    cases.push({id,width,state,model:event.sheet.mirror,...actions});
   };
   await record('current');
   if(id==='photo115'){
    await p.evaluate(()=>{api115.cur().photos.in=['data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4////fwAJ+wP9KobjigAAAABJRU5ErkJggg=='];openPhoto115()});await p.clock.runFor(400);await record('photo');
   }
   if(id==='g181-modal'){
    await p.evaluate(()=>{document.getElementById('s181-n').value='Detergen Uji';document.getElementById('s181-q').value='10';document.getElementById('s181-u').value='liter';document.getElementById('s181-m').value='2';document.getElementById('s181-c').value='5000';document.getElementById('g181-ms').click()});await p.clock.runFor(400);
    for(const tool of ['move','op','sup','buy','tr']){
     await p.evaluate(()=>{closeSheet91('g181-modal');openPage('inventory')});await p.clock.runFor(250);
     await p.evaluate(tool=>document.querySelector('#inventory [data-st='+tool+']').click(),tool);await p.clock.runFor(400);await record(tool);
    }
    await p.evaluate(()=>{closeSheet91('g181-modal');openCourier181('manage');[...document.querySelectorAll('#courier181 button')].find(b=>b.textContent.includes('Tambah Kurir')).click()});await p.clock.runFor(500);await record('courier');
   }
   const before=await p.evaluate(()=>JSON.stringify(localStorage));
   await p.evaluate(id=>__goyanaForm(id,'close',0),id);await p.clock.runFor(300);
   assert.equal(await p.locator('#'+id).isVisible(),false,id+' closes');assert.equal(await p.evaluate(()=>JSON.stringify(localStorage)),before,id+' close does not save');
  }
 }finally{await p.close()}
 if(write)fs.writeFileSync(path.join(root,'mobile/test/fixtures/parity/remaining_popups.json'),JSON.stringify(cases)+'\n');return cases;
};
if(require.main===module)(async()=>{const {chromium}=require('playwright');const b=await chromium.launch({headless:true,args:['--no-sandbox','--single-process','--no-zygote']});try{console.log((await module.exports(b,true)).map(c=>[c.id,c.width,c.state]))}finally{await b.close()}})().catch(e=>{console.error(e);process.exit(1)});
