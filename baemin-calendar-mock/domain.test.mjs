import test from 'node:test';
import assert from 'node:assert/strict';
import {normalizeSupplierNutrition} from './supplier.mjs';
import {initialState,validateState,createOrder,orderEvent,recordDelivery,recordPhoto,setFavorite,submitReview,entriesOn,totalsFor,kstDate,hasClubMembership} from './domain.mjs';
const newOrder=s=>createOrder(s,{id:'test-order',attemptId:'test-attempt',menuId:'bibimbap',placedAt:'2026-10-31T23:55:00+09:00'});
const event=(s,action,n)=>orderEvent(s,{orderId:'test-order',eventId:'test-event-'+n,action,at:`2026-11-01T00:${String(n*5).padStart(2,'0')}:00+09:00`});
test('seed data and storage shape validate',()=>assert.equal(validateState(initialState()),true));
test('order lifecycle preserves immutable price snapshot and deduplicates checkout and events',()=>{
 const start=initialState();let s=newOrder(start);assert.equal(s.orders.length,start.orders.length+1);
 assert.equal(newOrder(s),s);assert.equal(s.orders[0].amount.paid,11000);
 s=event(s,'next',1);const again=event(s,'next',1);assert.equal(again,s);
 s=event(s,'next',2);s=event(s,'next',3);
 assert.equal(s.orders[0].status,'delivered');assert.equal(start.orders.some(o=>o.id==='test-order'),false);
 assert.throws(()=>event(s,'next',4),/종료/);
 assert.equal(s.records.length,start.records.length,'delivery completion must not imply consumption');
});
test('cross-midnight order and consumed date differ, portion scales, repeat record is idempotent',()=>{
 let s=newOrder(initialState());for(let n=1;n<=3;n++)s=event(s,'next',n);
 const before=s.records.length;
 s=recordDelivery(s,{orderId:'test-order',recordId:'r-midnight',consumedDate:'2026-11-01',portion:.5});
 assert.equal(s.records.length,before+1);assert.equal(s.records.at(-1).nutrition.calories,310);
 assert.equal(kstDate(s.orders[0].placedAt),'2026-10-31');assert.equal(s.records.at(-1).date,'2026-11-01');
 assert.equal(entriesOn(s,'2026-10-31').some(e=>e.type==='order'&&e.id==='test-order'),true);
 assert.equal(entriesOn(s,'2026-11-01').some(e=>e.type==='record'&&e.record.orderId==='test-order'),true);
 const repeated=recordDelivery(s,{orderId:'test-order',recordId:'duplicate',consumedDate:'2026-11-01'});assert.equal(repeated,s);
});
test('cancelled order remains visible, fully refunds and cannot create meal or review',()=>{
 let s=event(newOrder(initialState()),'cancel',1);const o=s.orders[0];
 assert.equal(o.status,'cancelled');assert.equal(o.amount.refunded,o.amount.paid);
 assert.equal(entriesOn(s,'2026-10-31','cancelled').length,1);
 assert.throws(()=>recordDelivery(s,{orderId:o.id,recordId:'bad',consumedDate:'2026-10-31'}),/완료/);
 assert.throws(()=>submitReview(s,{orderId:o.id,rating:5,text:'x'}),/완료/);
});
test('photo confirmation stores origin, contributes to summary once and survives reload',()=>{
 const s=initialState(),data={id:'photo1',analysisId:'analysis1',date:'2026-10-26',name:'직접 먹은 음식',nutrition:{calories:400,carbs:40,protein:20,fat:10},source:'hf-estimate',modelId:'test-model',ingredients:[]};
 const next=recordPhoto(s,data);assert.equal(totalsFor(next,'2026-10-26').calories,totalsFor(s,'2026-10-26').calories+400);
 assert.equal(recordPhoto(next,{...data,id:'photo2'}),next);
 assert.equal(next.records.at(-1).source,'hf-estimate');assert.equal(validateState(JSON.parse(JSON.stringify(next))),true);
 assert.throws(()=>recordPhoto(s,{...data,nutrition:{...data.nutrition,calories:-1}}));
 assert.throws(()=>recordPhoto(s,{...data,date:'2026-02-30'}));
});
test('linked meal does not duplicate an order in same-day calendar; favorites and reviews share state',()=>{
 let s=initialState();const o=s.orders.find(o=>o.status==='delivered'&&!s.records.some(r=>r.orderId===o.id));
 const date=kstDate(o.placedAt),count=entriesOn(s,date).length;
 s=recordDelivery(s,{orderId:o.id,recordId:'link-new',consumedDate:date});assert.equal(entriesOn(s,date).length,count);
 s=setFavorite(s,'mint-kitchen',false);assert.equal(s.favorites.includes('mint-kitchen'),false);assert.equal(s.orders.some(x=>x.shopId==='mint-kitchen'),true);
 s=submitReview(s,{orderId:o.id,rating:4,text:'테스트'});assert.equal(s.reviews.filter(r=>r.orderId===o.id).length,1);
 assert.equal(submitReview(s,{orderId:o.id,rating:5,text:'중복'}),s);
});
test('reject invalid states, time travel and closed shop orders',()=>{
 assert.equal(validateState({...initialState(),version:100}),false);
 assert.throws(()=>createOrder(initialState(),{id:'x',attemptId:'y',menuId:'chicken',quantity:1,placedAt:'2026-10-26T12:00:00+09:00'}),/주문/);
 assert.throws(()=>orderEvent(newOrder(initialState()),{orderId:'test-order',eventId:'x',action:'next',at:'2020-01-01T00:00:00+09:00'}),/시각/);
});
test('supplier adapter handles units, per-100g serving conversion, missing data and version checks',()=>{
 const feed={menuId:'a',menuVersion:'v1',sourceId:'demo-supplier',origin:'fixture',basis:'per_100g',servingGrams:250,nutrients:Object.fromEntries(Object.entries({calories:100,carbs:15,protein:5,fat:2}).map(([k,value])=>[k,{value,unit:k==='calories'?'kcal':'g'}]))};
 assert.equal(normalizeSupplierNutrition(feed,{menuId:'a',menuVersion:'v1'}).nutrition.calories,250);
 assert.equal(normalizeSupplierNutrition({...feed,nutrients:null}).nutrition,null);
 assert.throws(()=>normalizeSupplierNutrition(feed,{menuId:'wrong'}));
 assert.throws(()=>normalizeSupplierNutrition({...feed,servingGrams:null}));
 assert.throws(()=>normalizeSupplierNutrition({...feed,nutrients:{...feed.nutrients,calories:{value:100,unit:'kJ'}}}));
});
test('calendar filters and confirmed nutrition summaries use the same source scope',()=>{
 let s=recordPhoto(initialState(),{id:'photo-filter',analysisId:'analysis-filter',date:'2026-10-26',name:'식사',nutrition:{calories:400,carbs:40,protein:20,fat:10},source:'manual'});
 assert.equal(entriesOn(s,'2026-10-26','photo').length,1);
 assert.equal(totalsFor(s,'2026-10-26','photo').calories,400);
 assert.equal(totalsFor(s,'2026-10-26','cancelled').calories,0);
 assert.equal(totalsFor(s,'2026-10-26').calories,totalsFor(s,'2026-10-26','photo').calories+totalsFor(s,'2026-10-26','delivery').calories);
});

test('club report access requires an explicit local membership flag and preserves existing meal data',()=>{
 const original=initialState();assert.equal(hasClubMembership(original),false);
 const legacy={...original};delete legacy.membership;assert.ok(validateState(legacy));assert.equal(hasClubMembership(legacy),false);
 const member={...legacy,membership:{baeminClub:true}};assert.equal(hasClubMembership(JSON.parse(JSON.stringify(member))),true);assert.ok(validateState(member));assert.deepEqual(member.orders,original.orders);assert.deepEqual(member.records,original.records);
 assert.equal(hasClubMembership({...legacy,membership:{baeminClub:'true'}}),false);assert.equal(validateState({...legacy,membership:{baeminClub:'true'}}),false);
});
