const assert=require('assert/strict'),fs=require('fs'),path=require('path');
const {revenue}=require('../../goyana-v200-cash.js');
const now='2026-11-01T01:00:00Z';
const receipt=(m,a,at)=>({m,a,at});
const prior=receipt('Tunai',10000,'2026-10-31T16:59:59Z'),today=receipt('Deposit',28000,'2026-10-31T17:00:00Z'),refund=receipt('Tunai',-3000,'2026-11-01T00:00:00Z');
const shots=[
 {name:'WIB midnight and month boundary',now,kas:{sales:[prior,today],ins:[{a:50000,deposit178:true}],hist:[]},expected:28000},
 {name:'multiple closed shifts and signed refund',now,kas:{sales:[refund],hist:[{d:now,ledgerSales:[today]},{d:now,ledgerSales:[prior]}]},expected:25000},
 {name:'aggregate date is not receipt date',now,kas:{sales:[],hist:[{d:now,omset:10000}]},business:{orders:[{dataset:{payments178:JSON.stringify([prior])}}]},expected:0},
 {name:'legacy dated receipts with archive and active dedup',now,kas:{sales:[refund],hist:[{d:now,omset:38000},{d:now,ledgerSales:[today]}]},business:{orders:[{dataset:{payments178:JSON.stringify([prior,today,refund])}}]},expected:25000},
 {name:'identical receipts remain separate transactions',now,kas:{sales:[],hist:[{d:now,omset:56000},{d:now,ledgerSales:[today]}]},business:{orders:[{dataset:{payments178:JSON.stringify([today,today])}}]},expected:56000},
 {name:'topup alone is not revenue',now,kas:{sales:[],hist:[],ins:[{a:50000,deposit178:true}]},expected:0},
 {name:'reload preserves dated archives',now,kas:JSON.parse(JSON.stringify({sales:[refund],hist:[{d:now,ledgerSales:[today,prior]}]})),expected:25000}
];
for(const s of shots){assert.equal(revenue(s.kas,new Date(s.now),s.business),s.expected,s.name);console.log('PASS daily revenue '+s.name)}
const file=path.resolve(__dirname,'../../mobile/test/fixtures/parity/cash_day.json');
if(process.argv.includes('--verify-only'))assert.deepEqual(shots,JSON.parse(fs.readFileSync(file)).shots);else fs.writeFileSync(file,JSON.stringify({shots},null,2)+'\n');
