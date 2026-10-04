const assert = require('node:assert/strict');
const path = require('node:path');
const {pathToFileURL} = require('node:url');

module.exports = async function(browser) {
  const url = pathToFileURL(path.join(__dirname, '../web/customer-status.html')).href;
  const page = await browser.newPage({viewport:{width:390,height:844}});
  const errors=[]; page.on('pageerror',e=>errors.push(String(e)));
  try {
    await page.goto(url);
    assert.equal(await page.locator('#empty').isVisible(),true);
    assert.equal(await page.locator('#order').isVisible(),false);
    assert.equal(await page.locator('#preview').isVisible(),false);
    for(const width of [390,320]) {
      await page.setViewportSize({width,height:844});
      await page.goto(url+'?preview=1');
      await page.evaluate(()=>document.fonts.ready);
      assert.equal(await page.locator('#preview').isVisible(),true);
      assert.equal(await page.locator('#order-id').textContent(),'GY-261005-0133');
      assert.equal(await page.locator('#status-title').textContent(),'Sedang disetrika');
      assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
      await page.screenshot({path:path.join(__dirname, '../mobile/test/screens/customer_status_'+width+'.png'),fullPage:true});
    }
    for(const status of ['jemput','antrian','cuci','kering','setrika','packing','siap','diambil','batal','unknown','__proto__']) {
      await page.evaluate(status=>GoyanaCustomerStatus.render({id:'GY-TEST-1',status}),status);
      assert.equal(await page.locator('#order-id').textContent(),'GY-TEST-1');
      assert.equal(await page.locator('#progress-card').isVisible(),!['batal','unknown','__proto__'].includes(status));
      assert.equal(await page.locator('#contact').isVisible(),false);
    }
    await page.evaluate(()=>GoyanaCustomerStatus.render({id:'<img src=x onerror=alert(1)>',status:'siap',outlet:{name:'<script>bad()</script>',phone:'javascript:alert(1)'},total:-1,remaining:NaN,estimated_at:'invalid',services:['<img src=x>'],payment_status:'Lunas'}));
    assert.equal(await page.locator('#order img, #order script').count(),0);
    assert.equal(await page.locator('#total-row').isVisible(),false);
    assert.equal(await page.locator('#estimate').isVisible(),false);
    assert.equal(await page.locator('#contact').getAttribute('href'),null);
    for(const data of [null,{},[],{id:42}]) {
      await page.evaluate(data=>GoyanaCustomerStatus.render(data),data);
      assert.equal(await page.locator('#empty').isVisible(),true);
      assert.equal(await page.locator('#order').isVisible(),false);
    }
    assert.deepEqual(errors,[]);
    console.log('PASS customer status web: 390/320, explicit preview, empty data, every status and escaped payload');
  } finally { await page.close(); }
};
