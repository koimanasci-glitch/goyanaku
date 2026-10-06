// A8 Laporan: HTML adalah oracle. Mencatat data + hasil tiap laporan HTML untuk tiap periode ke fixture Dart.
const fs=require('fs'),path=require('path'),assert=require('assert/strict');
const {spawnSync}=require('child_process'),{chromium}=require('playwright');
const root=path.resolve(__dirname,'../..');
// Daftar laporan yang sudah dipindah dibaca dari sumber Dart supaya satu sumber kebenaran.
const IDS=[...fs.readFileSync(path.join(__dirname,'../../mobile/lib/logic/reports_a8.dart'),'utf8').match(/const reportIdsA8 = \[([\s\S]*?)\];/)[1].matchAll(/'([a-z-]+)'/g)].map(m=>m[1]);
const original=JSON.parse(fs.readFileSync(path.join(root,'mobile/test/fixtures/parity/flows_a4_a5_a7.json'))).steps.find(s=>s.part==='A7');
const KEYS=['today','7','30','month','last'];
function synthetic(){
 const now=Date.parse('2026-10-06T03:00:00Z'),DAY=864e5,names=['Siti Rahma','Budi Santoso','Rina Lestari','Agus','Dewi','Hendra','Maya','Koiman <b>'];
 const sts=['antrian','proses','siap','telat','diambil','batal','diambil'],ms=['Tunai','QRIS','Transfer','Belum','Deposit','Tunai','QRIS'];
 const ord=[];
 for(let i=0;i<44;i++){
  let t=now-((i*7)%75)*DAY-((i*5)%17+1)*36e5+(i%4)*6e4;
  if(i===40)t=Date.parse('2026-10-05T16:59:00Z');if(i===41)t=Date.parse('2026-10-05T17:00:00Z');if(i===42)t=Date.parse('2026-09-30T17:00:00Z');if(i===43)t=ord[0].t0;
  const total=(10+(i*37)%90)*1000+(i%3)*500,st=sts[i%7];let m=st==='batal'?'Batal':ms[(i*3)%7];
  const paid=m==='Batal'||m==='Belum'?0:(i%7===3?Math.round(total/2):total);
  const pay=i%5===1?[{m:'Tunai',a:Math.round(total/3)},{m:'QRIS',a:Math.round(total/3)},{m:'Deposit',a:total-2*Math.round(total/3)}]:[];
  const disc=i%5===0?5000:0,rd=i%4===0?500*((i%3)-1):0;
  ord.push({t0:t,id:'GY-'+String(i).padStart(4,'0'),t,c:names[i%8],f:false,items:[{n:'Cuci',u:'kg',q:3,p:7000,t:21000}],kg:2.5+(i%5)*1.1,sub:total+disc,disc,ong:i%6===0?5000:0,rd,total,paid:m==='Deposit'?total:paid,m,payments178:pay,st,staff:'',antar:i%6===0,dur:['Reguler','Express','Kilat'][i%3],due:t+72*36e5,done:i%9===0?t:t+((i*11)%110)*36e5,pts:Math.floor(paid/1e4)});
  if(i%3===1)ord[ord.length-1].items.push({n:i%2?'Bed Cover':'Setrika',u:i%2?'pcs':'kg',q:1+(i%4)*0.5,p:25000,t:25000*(1+(i%4)*0.5)});
 }
 ord.forEach(o=>{o.t0=undefined});
 const exp=[],ins=[],cats=['Bahan Baku','Sewa','Listrik','Lain-Lain','Bahan Baku'];
 for(let i=0;i<26;i++)exp.push({a:(8+(i*13)%90)*1000,t:cats[i%5],at:now-((i*3)%70)*DAY-(i%3)*36e5});
 exp.push({a:12000,t:'Bahan Baku',at:now-3*DAY},{a:12000,t:'Bahan Baku',at:now-3*DAY});
 for(let i=0;i<8;i++)ins.push({a:(5+i*7)*1000,t:i%2?'Tambah modal':'Jual hanger',at:now-(i*9)*DAY-i*36e5,deposit178:i%3===2});
 const stock=[{n:'Deterjen',now:3,min:5,u:'L',per:0.05,buy:18000},{n:'Pewangi',now:12.5,min:4,u:'L',per:0.03,buy:30000},{n:'Plastik',now:40,min:40,u:'pcs',per:0.4,buy:500}],att=[];
 for(let i=0;i<20;i++)['Rina','Dewi','Andi'].forEach((s,si)=>{if((i+si)%4)att.push({d:now-((i*3)%70)*DAY-(now%DAY)+0,s,in:now-((i*3)%70)*DAY-3*36e5+((i*7+si*11)%90)*6e4,out:now-((i*3)%70)*DAY+5*36e5})});
 return {ord,exp,ins,stock,att};
}
(async()=>{
 const prep=spawnSync('python',[path.join(root,'tools/prepare_flutter_web.py'),root,path.join(root,'tests/node_modules/@zxing/library/umd/index.min.js')],{encoding:'utf8'});assert.equal(prep.status,0,prep.stderr);
 const browser=await chromium.launch({headless:true,executablePath:process.env.GOYANA_BROWSER_EXECUTABLE||undefined,args:['--no-sandbox']});const errors=[],scenarios=[];
 try{
  for(const name of ['seed','synthetic']){
   const page=await browser.newPage({viewport:{width:390,height:844},timezoneId:'Asia/Jakarta'});page.on('pageerror',e=>errors.push(name+': '+e.message));
   await page.clock.install({time:new Date('2026-10-06T03:00:00Z')});
   await page.addInitScript(seed=>{
    if(!sessionStorage.getItem('a8seed')){sessionStorage.setItem('a8seed','1');for(const [k,v] of Object.entries(seed))sessionStorage.setItem('sq:'+k,v)}
    window.GoyanaStore={all:()=>JSON.stringify(Object.fromEntries(Object.keys(sessionStorage).filter(k=>k.startsWith('sq:')).map(k=>[k.slice(3),sessionStorage.getItem(k)]))),set:(k,v)=>{sessionStorage.setItem('sq:'+k,v);return true},setMany:j=>{for(const [k,v] of Object.entries(JSON.parse(j)))sessionStorage.setItem('sq:'+k,v);return true},remove:k=>sessionStorage.removeItem('sq:'+k),get:k=>sessionStorage.getItem('sq:'+k),sizeBytes:()=>0};
    window.GoyanaNative={__events:[],postMessage(raw){if(raw.startsWith('{"event"'))this.__events.push(raw);else{const m=JSON.parse(raw);setTimeout(()=>window.__goyanaNative.finish(m.id,true,{}),5)}}};
   },original.before);
   await page.goto(require('url').pathToFileURL(path.join(root,'mobile/assets/web/index.html')).href);await page.clock.runFor(3500);
   await page.evaluate(()=>{document.getElementById('ob189').hidden=true;openPage('reports')});await page.clock.runFor(300);
   if(name==='synthetic'){
    await page.evaluate(d=>{const R=o=>Object.assign(o,{t:new Date(o.t),due:new Date(o.due),done:new Date(o.done)});KAS137.outs=d.exp;KAS137.ins=d.ins;setReportOrders177(d.ord.map(R));const c=__rep170ctx();c.STOCK.splice(0,c.STOCK.length,...d.stock);c.ATT.splice(0,c.ATT.length,...d.att.map(a=>({d:new Date(a.d),s:a.s,in:new Date(a.in),out:new Date(a.out)})));ORD170.forEach((o,i)=>{o.staff=['Rina','Dewi','Andi','','Rina'][i%5]})},synthetic());
   }
   const out={name,periods:{}};
   for(const k of KEYS){
    const st=await page.evaluate(([k,ids])=>__goyanaReportsA8(k,ids),[k,IDS]);assert.ok(st,'hook');
    if(!out.state)out.state={tz:st.tz,now:st.now,t0:st.t0,ord:st.ord,exp:st.exp,inc:st.inc};
    else assert.deepEqual({tz:st.tz,now:st.now,t0:st.t0,ord:st.ord,exp:st.exp,inc:st.inc},out.state,'state stable');
    out.periods[k]={range:st.range,expected:st.expected};
   }
   scenarios.push(out);await page.close();
  }
  assert.deepEqual(errors,[]);
  assert.ok(scenarios[1].state.ord.length>=40);
  fs.writeFileSync(path.join(root,`mobile/test/fixtures/parity/reports_a8.json`),JSON.stringify({ids:IDS,scenarios})+'\n');
  console.log('PASS A8 '+IDS.length+' laporan, fixtures: '+scenarios.map(s=>s.name+' '+s.state.ord.length+' ord').join(', '));
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
