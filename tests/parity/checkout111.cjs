// B8 visual fixtures. Production openPage/placeOrder guards are never replaced.
// Only this isolated browser page manually exposes the dormant checkout DOM.
const assert=require('assert/strict'),fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'../..');
module.exports=async function captureCheckout(browser,write=false){
  const cases=[];
  const p=await browser.newPage({viewport:{width:390,height:844},timezoneId:'Asia/Jakarta'});
  try{
    for(const width of [390,320]){
      await p.setViewportSize({width,height:844});
      await p.clock.install({time:new Date('2026-10-05T01:00:00Z')});
      await p.addInitScript(()=>{window.GoyanaNative={__events:[],postMessage(raw){if(raw.startsWith('{"event"')){this.__events.push(raw);return}const m=JSON.parse(raw);setTimeout(()=>__goyanaNative.finish(m.id,true,m.method==='insets'?{top:31}:{}),5)}}});
      await p.goto(require('url').pathToFileURL(path.join(root,'mobile/assets/web/index.html')).href);await p.clock.runFor(3500);
      // Match Flutter's bundled Poppins; avoid host-dependent fallback font widths.
      await p.evaluate(async faces=>{
        for(const face of faces){const font=new FontFace('Poppins','url(data:font/ttf;base64,'+face.data+')',{weight:face.weight});document.fonts.add(await font.load())}
        await document.fonts.ready;
      },[['Regular','400'],['Medium','500'],['SemiBold','600']].map(([name,weight])=>({weight,data:fs.readFileSync(path.join(root,'mobile/assets/fonts/Poppins-'+name+'.ttf')).toString('base64')})));
      await p.evaluate(()=>{document.getElementById('ob189').hidden=true;document.querySelectorAll('.show').forEach(e=>e.classList.remove('show'));openPlan111(0,1);goCheckout111()});await p.clock.runFor(400);
      assert.notEqual(await p.evaluate(()=>document.querySelector('.page.active').id),'checkout111','checkout remains blocked in production');
      const expose=async()=>{await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>e.classList.remove('show'));document.querySelectorAll('.page').forEach(e=>e.classList.toggle('active',e.id==='checkout111'));document.getElementById('toast90').classList.remove('show')});await p.clock.runFor(400)};
      const snapshot=async(name)=>{
        await expose();
        const result=await p.evaluate(()=>{
          const event=GoyanaNative.__events.map(JSON.parse).filter(e=>e.page==='checkout111').at(-1);
          const host=document.getElementById('checkout111');
          return {model:event.model.mirror,buttons:[...host.querySelectorAll('button')].map((b,i)=>({i,t:b.textContent.trim(),visible:getComputedStyle(b).display!=='none'&&!!b.getClientRects().length,disabled:b.disabled})),inputs:[...host.querySelectorAll('input')].map((b,i)=>({i,id:b.id}))};
        });
        cases.push({name,width,...result});
      };
      await snapshot('plan');
      await p.evaluate(()=>__goyanaMirror('checkout111','button',4));await p.clock.runFor(300);
      assert.equal(await p.locator('#ck111-cab strong').textContent(),'1');
      await p.evaluate(()=>__goyanaMirror('checkout111','button',3));await p.clock.runFor(300);
      assert.equal(await p.locator('#ck111-cab strong').textContent(),'0');
      await p.evaluate(()=>__goyanaMirror('checkout111','input',1,'uji'));
      assert.equal(await p.locator('#ck111-promoin').inputValue(),'UJI');
      await p.evaluate(()=>__goyanaMirror('checkout111','input',1,''));
      await p.evaluate(()=>{dur111(12);goCheckout111();cabs111(1);bots111(1);pickPay111('bca')});await snapshot('addons');
      await p.evaluate(()=>{document.getElementById('ck111-promoin').value='HEMAT12';applyPromo111()});await snapshot('promo');
      await p.evaluate(()=>{clearPromo111();document.getElementById('ck111-promoin').value='SALAH';applyPromo111()});await snapshot('promo_error');
      await p.evaluate(()=>pickPay111('code'));await snapshot('activation');
      // The final subscription patch disables both standalone add-on purchases.
      for(const name of ['buyCab111','buyBot96']){
        await p.evaluate(name=>window[name](),name);await p.clock.runFor(300);
        assert.match(await p.locator('#toast90').textContent(),/Paket belum diaktifkan/);
      }
      const before=await p.evaluate(()=>JSON.stringify(localStorage));
      await p.evaluate(()=>__goyanaMirror('checkout111','button',document.querySelectorAll('#checkout111 button').length-1));await p.clock.runFor(300);
      assert.equal(await p.evaluate(()=>JSON.stringify(localStorage)),before,'blocked purchase does not mutate storage');
      assert.match(await p.locator('#toast90').textContent(),/Pembayaran Google Play dan verifikasi server belum terhubung\. Paket belum diaktifkan\./);
    }
  }finally{await p.close()}
  const dir=path.join(root,'mobile/test/fixtures/mirror_pages');
  if(write){fs.writeFileSync(path.join(dir,'checkout111.json'),JSON.stringify(cases[0].model,null,2)+'\n');fs.writeFileSync(path.join(dir,'checkout111_cases.json'),JSON.stringify(cases)+'\n')}
  return cases;
};
if(require.main===module)(async()=>{
  const {chromium}=require('playwright');
  const b=await chromium.launch({headless:true,args:['--no-sandbox','--single-process','--no-zygote']});
  try{const cases=await module.exports(b,true);console.log('Captured B8:',cases.map(c=>c.name+'@'+c.width).join(', '))}finally{await b.close()}
})().catch(e=>{console.error(e);process.exit(1)});
