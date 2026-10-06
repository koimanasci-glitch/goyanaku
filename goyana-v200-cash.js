/* Daily revenue uses dated receipts, never the date a shift was closed. */
(function(root){
  'use strict';
  function day(value){var d=new Date(value);if(!Number.isFinite(d.getTime()))return '';return new Date(d.getTime()+7*3600000).toISOString().slice(0,10)}
  function entries(x){return Array.isArray(x)?x:[]}
  function key(s){var at=new Date(s.at).getTime();return JSON.stringify([s.m,Number(s.a)||0,Number.isFinite(at)?at:null])}
  function revenue(k,now,business){
    var today=day(now),sum=0,known=new Map(),legacyUntil=-Infinity;
    function add(s,fallback){if(!s||!['Tunai','QRIS','Transfer','Deposit'].includes(s.m))return;var d=day(s.at);if(d===today||(!d&&fallback))sum+=Number(s.a)||0;var id=key(s);known.set(id,(known.get(id)||0)+1)}
    entries(k.sales).forEach(function(s){add(s,true)});
    entries(k.hist).forEach(function(h){if(Array.isArray(h.ledgerSales))h.ledgerSales.forEach(function(s){add(s,false)});else {var at=new Date(h.d||h.at).getTime();if(Number.isFinite(at))legacyUntil=Math.max(legacyUntil,at)}});
    // Legacy aggregate histories can only be recovered from dated order receipts.
    if(Number.isFinite(legacyUntil))entries((business||{}).orders).forEach(function(o){var receipts=[];try{receipts=JSON.parse((o.dataset||{}).payments178||'[]')}catch(_){}entries(receipts).forEach(function(s){var at=new Date(s.at).getTime();if(!Number.isFinite(at)||at>legacyUntil)return;var id=key(s),count=known.get(id)||0;if(count){known.set(id,count-1);return}if(day(s.at)===today&&['Tunai','QRIS','Transfer','Deposit'].includes(s.m))sum+=Number(s.a)||0})});
    return Math.round(sum);
  }
  root.cashDayRevenue200=function(k,now,business){if(!business&&typeof localStorage!=='undefined'){try{business=JSON.parse(localStorage.getItem('goyana-business177')||'{}')}catch(_){}}return revenue(k,now,business)};
  if(typeof window!=='undefined')window.addEventListener('click',function(event){
    var button=event.target.closest&&event.target.closest('#cashout .cash-submit');
    if(!button)return;
    var form=button.closest('#cashout'),method=form.querySelector('select.cash-input');
    if(!method||method.value!=='Non-Tunai')return;
    var before=JSON.parse(JSON.stringify(window.KAS137)),fields=Array.from(form.querySelectorAll('input,select')).map(function(e){return [e,e.value]});
    queueMicrotask(function(){
      if(window.flushTransactions177&& !window.flushTransactions177()){
        Object.assign(window.KAS137,before);
        ['sales','ins','outs','hist'].forEach(function(k){entries(window.KAS137[k]).forEach(function(x){['at','d','voidAt'].forEach(function(f){if(x[f])x[f]=new Date(x[f])})})});
        fields.forEach(function(x){x[0].value=x[1]});
        if(window.toast90)toast90('Pengeluaran belum tersimpan. Coba lagi.');
      }
    });
  },true);
  if(typeof module!=='undefined')module.exports={revenue:revenue,day:day};
})(typeof window!=='undefined'?window:globalThis);
