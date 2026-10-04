// Capture Tambah Transaksi 3b from the real HTML runtime. This file does not calculate expected amounts.
module.exports=async function captureAddOrder3b(p){
  const out=[];
  await p.evaluate(()=>{document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});document.getElementById('v88-name').value='Paritas Transaksi';document.getElementById('v88-phone').value='081200000099';document.getElementById('v88-address').value='Jakarta';saveCustomerV88();});
  async function settle(){await p.clock.runFor(450)}
  async function capture(name){
    await settle();
    out.push(await p.evaluate(name=>{
      const event=GoyanaNative.__events.map(JSON.parse).filter(e=>e.page==='addorder').at(-1);
      if(!event?.model?.sheet||event.model.sheet.kind!=='payment')throw Error('payment model missing: '+name);
      const store={};for(let i=0;i<localStorage.length;i++){const k=localStorage.key(i);if(k.startsWith('goyana-'))store[k]=localStorage.getItem(k)}
      const ds=document.querySelectorAll('#f61-options select')[2];
      return {name,now:new Date().toISOString(),store,draft:{cart:JSON.parse(JSON.stringify(f61.cart||[])),duration:f61.dur,handover:String(document.getElementById('f61-handover')?.value||''),discount:{value:String(ds?.value||''),manual:String(ds?.dataset.manual||''),definitions:JSON.parse(JSON.stringify(window.DISC127||[]))}},htmlModel:{total:event.model.sheet.total,discount:window.disc127?{amt:Number(disc127.amt)||0,pct:Number(disc127.pct)||0,name:String(disc127.name||'')}:null,transport:{fee:Number(f61._transport183)||0,type:String(f61._transportType183||'none')}}};
    },name));
  }
  async function run(s){
    await p.evaluate(s=>{
      document.querySelectorAll('.show').forEach(e=>{if(e.id!=='lg167')e.classList.remove('show')});
      window.DISC127?.splice(0,window.DISC127.length);
      if(s.discount?.kind==='defined')window.DISC127.push({id:901,name:s.discount.name,type:s.discount.type,val:s.discount.val,scope:s.discount.scope,min:0,until:'',on:true});
      let outlets=[];try{outlets=JSON.parse(localStorage.getItem('goyana-outlets180')||'[]')}catch(e){}
      let active='';try{active=JSON.parse(localStorage.getItem('goyana-active-outlet180')||'""')}catch(e){}
      active=active||(outlets[0]?.id)||'default';
      const cfg={};cfg[active]=Object.assign({mode:'free',fixed:0,pickup:0,delivery:0,roundtrip:0,perKm:0,freeRadius:0,manual:false},s.transport||{});localStorage.setItem('goyana-transport183',JSON.stringify(cfg));
      openPage('addorder');delete f61._transport183;delete f61._transportBase183;delete f61._transportType183;
      const person=[...document.querySelectorAll('#f61-customer .f61-person')].find(e=>e.textContent.includes('Paritas Transaksi'));if(!person)throw Error('customer missing');person.querySelector('button').click();f61ChooseDuration('Reguler');
      const flat=catalog158.flatMap(c=>c.items);function add(unit,qty){const item=flat.find(x=>x.unit===unit);if(!item)throw Error('service missing '+unit);openQty116(item.id);document.getElementById('qty116-in').value=String(qty);saveQty116()}add('kg',2);if(s.mixed)add('pcs',1);
      f61OrderOptions();document.getElementById('f61-handover').value=s.handover;
      const ds=document.querySelectorAll('#f61-options select')[2];if(s.discount?.kind==='defined')ds.value='d901';else if(s.discount?.kind==='manual'){ds.value='manual';ds.dataset.manual=String(s.discount.val)}else ds.value='';f61Payment();
    },s);
    await capture(s.name);
  }
  const scenarios=[
    {name:'direct_free_none',handover:'Datang Langsung',transport:{mode:'free'}},
    {name:'delivery_fixed_none',handover:'Antar ke Pelanggan',transport:{mode:'fixed',fixed:5000}},
    {name:'roundtrip_split_none',handover:'Jemput & Antar',transport:{mode:'split',pickup:3000,delivery:4000}},
    {name:'roundtrip_tariff_none',handover:'Jemput & Antar',transport:{mode:'roundtrip',roundtrip:9000,pickup:3000,delivery:4000}},
    {name:'delivery_distance_zero',handover:'Antar ke Pelanggan',transport:{mode:'distance',perKm:2500,freeRadius:2}},
    {name:'discount_all_percent',handover:'Datang Langsung',transport:{mode:'free'},discount:{kind:'defined',name:'Promo 10',type:'p',val:10,scope:'Semua layanan'}},
    {name:'discount_all_nominal_with_fixed',handover:'Antar ke Pelanggan',transport:{mode:'fixed',fixed:6000},discount:{kind:'defined',name:'Potong 5000',type:'n',val:5000,scope:'Semua layanan'}},
    {name:'discount_all_percent_with_fixed',handover:'Antar ke Pelanggan',transport:{mode:'fixed',fixed:6000},discount:{kind:'defined',name:'Promo 10',type:'p',val:10,scope:'Semua layanan'}},
    {name:'discount_kilo_percent_mixed_with_fixed',handover:'Antar ke Pelanggan',mixed:true,transport:{mode:'fixed',fixed:6000},discount:{kind:'defined',name:'Kilo 50',type:'p',val:50,scope:'Kiloan'}},
    {name:'discount_satuan_nominal_cap_roundtrip',handover:'Jemput & Antar',mixed:true,transport:{mode:'roundtrip',roundtrip:9000,pickup:3000,delivery:4000},discount:{kind:'defined',name:'Satuan 20000',type:'n',val:20000,scope:'Satuan'}},
    {name:'discount_manual_with_fixed',handover:'Antar ke Pelanggan',transport:{mode:'fixed',fixed:6000},discount:{kind:'manual',val:5000}}
  ];
  for(const s of scenarios)await run(s);
  return out;
};
