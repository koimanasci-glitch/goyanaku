// HTML is the oracle. No expected amount is calculated in this script.
module.exports=async function captureAddOrder(p){
  const shots=[];
  async function settle(){await p.clock.runFor(400)}
  async function shot(name){await settle();shots.push(await p.evaluate(name=>{
    const event=GoyanaNative.__events.map(JSON.parse).filter(e=>e.page==='addorder').at(-1);
    if(!event||event.model.stage!=='services')throw Error('Missing services model: '+name);
    const store={};for(let i=0;i<localStorage.length;i++){const k=localStorage.key(i);if(k.startsWith('goyana-'))store[k]=localStorage.getItem(k)}
    return {name,now:new Date().toISOString(),store,draft:{cart:JSON.parse(JSON.stringify(f61.cart||[])),catalog:JSON.parse(JSON.stringify(catalog158)),duration:f61.dur},htmlModel:event.model};
  },name))}
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>e.classList.remove('show'));document.getElementById('v88-name').value='Paritas Transaksi';document.getElementById('v88-phone').value='081200000099';document.getElementById('v88-address').value='Jakarta';saveCustomerV88();openPage('addorder');const people=[...document.querySelectorAll('#f61-customer .f61-person')];people.find(e=>e.textContent.includes('Paritas Transaksi')).querySelector('button').click();f61ChooseDuration('Reguler')});
  await shot('empty');
  async function quantity(unit,text){return p.evaluate(([unit,text])=>{const item=catalog158.flatMap(c=>c.items).find(it=>it.unit===unit);if(!item)throw Error('No service '+unit);openQty116(item.id);const field=document.getElementById('qty116-in');field.value=text;field.dispatchEvent(new Event('input',{bubbles:true}));const subtotal=document.getElementById('qty116-sub').textContent;saveQty116();const rejected=document.getElementById('qty116').classList.contains('show');const toast=document.getElementById('toast90').textContent;if(rejected)closeQty116();return {input:text,price:Number(item.prices158[f61.dur]),unit,subtotal,rejected,toast};},[unit,text])}
  const quantities=[];
  for(const [unit,input] of [['kg','2,5'],['kg','2.675'],['pcs','1.5'],['pcs','2'],['m','3,25'],['kg','0'],['kg','1000'],['kg','abc'],['kg','1,2,3'],['kg','999'],['kg','0.01'],['kg','999.995'],['kg','.5'],['kg','-2,5']]){quantities.push(await quantity(unit,input));await shot(unit+'_'+input)}
  for(const dur of ['Express','Kilat','Reguler']){await p.evaluate(d=>setDur116(d),dur);await shot('duration_'+dur)}
  await p.evaluate(()=>{const id=f61.cart[0].id;openQty116(id);delQty116()});await shot('removed');
  await p.evaluate(()=>{const items=catalog158.flatMap(c=>c.items).filter(i=>i.unit==='kg');for(const item of items){openQty116(item.id);document.getElementById('qty116-in').value='999';saveQty116()}});await shot('combined_thousands');
  return {shots,quantities};
};
