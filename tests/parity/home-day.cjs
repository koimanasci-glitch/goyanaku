const {chromium}=require('playwright'),assert=require('assert/strict'),fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'../..');
(async()=>{const browser=await chromium.launch({headless:true,args:['--no-sandbox']});try{
 const shots={};
 for(const name of ['home_1.json','home_2.json','home_3.json','home_4.json','home_5.json']){
  const fx=JSON.parse(fs.readFileSync(path.join(root,'mobile/test/fixtures/parity',name))),page=await browser.newPage({viewport:{width:390,height:844},timezoneId:'Asia/Jakarta'});
  await page.clock.install({time:new Date(fx.now)});
  await page.addInitScript(seed=>{
   window.GoyanaStore={all:()=>JSON.stringify(seed),set:(k,v)=>{seed[k]=v;return true},setMany:j=>{Object.assign(seed,JSON.parse(j));return true},remove:k=>delete seed[k]};
   window.GoyanaNative={postMessage(raw){if(raw.startsWith('{"event"'))return;const m=JSON.parse(raw);setTimeout(()=>window.__goyanaNative.finish(m.id,true,{}),5)}};
  },fx.store);
  await page.goto(require('url').pathToFileURL(path.join(root,'mobile/assets/web/index.html')).href);await page.clock.runFor(3500);await page.evaluate(()=>openPage('home'));
  shots[name]=await page.locator('#gy155-today').textContent();await page.close();
 }
 assert.deepEqual(shots,{'home_1.json':'Rp 56.000','home_2.json':'Rp 10.500','home_3.json':'Rp 56.000','home_4.json':'Rp 0','home_5.json':'Rp 7.000'});
 const file=path.join(root,'mobile/test/fixtures/parity/daily_revenue_home.json');
 if(process.argv.includes('--verify-only'))assert.deepEqual(shots,JSON.parse(fs.readFileSync(file)));else fs.writeFileSync(file,JSON.stringify(shots,null,2)+'\n');
 console.log('PASS approved daily home amounts: five historical stores, original fixtures retained');
}finally{await browser.close()}})().catch(e=>{console.error(e);process.exitCode=1});
