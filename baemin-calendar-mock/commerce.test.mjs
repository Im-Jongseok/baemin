import test from 'node:test';
import assert from 'node:assert/strict';
import {addCart,cartTotal,EXTRA_MENUS,PRODUCTS} from './catalog.mjs';
import {MENUS,SHOPS,initialState,createOrder,orderEvent,recordDelivery,entriesOn,totalsFor,validateState} from './domain.mjs';
test('catalog items reference shops, with validated food nutrition and explicit missing grocery nutrition',()=>{
 const all=[...MENUS,...PRODUCTS];assert.equal(new Set(all.map(m=>m.id)).size,all.length);assert.equal(MENUS.length,27);assert.equal(PRODUCTS.length,23);
 for(const m of all){assert.ok(SHOPS.some(s=>s.id===m.shopId));assert.ok(m.price>0);if(m.nutrition===null){assert.equal(m.service,'shopping');assert.equal(m.nutritionStatus,'not-provided');}else assert.ok(Object.values(m.nutrition).every(n=>Number.isFinite(n)&&n>=0));}
});
test('cart combines quantities immutably, sums catalog prices and rejects mixed stores',()=>{
 const first=EXTRA_MENUS.find(m=>m.id==='pizza-pepperoni'),second=EXTRA_MENUS.find(m=>m.id==='pizza-cheese');
 let cart=addCart(null,first,1);const original=structuredClone(cart);cart=addCart(cart,first,2);cart=addCart(cart,second,1);
 assert.equal(cartTotal(cart,EXTRA_MENUS),18900*3+16900);assert.deepEqual(original,{shopId:'pizza-club',lines:[{menuId:first.id,quantity:1}]});
 assert.throws(()=>addCart(cart,PRODUCTS[0]),/다른 가게/);assert.throws(()=>addCart(cart,first,10),/10개/);assert.throws(()=>addCart(null,first,0),/수량/);
});
test('multi-item checkout snapshots one shop and rejects empty, mixed and duplicate lines',()=>{
 const start=initialState(),at='2026-10-26T13:00:00+09:00';const next=createOrder(start,{id:'multi',attemptId:'multi-a',items:[{menuId:'bibimbap',quantity:2},{menuId:'salmon',quantity:1}],placedAt:at});
 assert.equal(next.orders[0].items.length,2);assert.equal(next.orders[0].amount.paid,35500);assert.equal(next.orders[0].service,'delivery');assert.equal(validateState(next),true);
 for(const items of [[],[{menuId:'bibimbap',quantity:1},{menuId:'noodles',quantity:1}],[{menuId:'bibimbap',quantity:1},{menuId:'bibimbap',quantity:1}]])assert.throws(()=>createOrder(start,{id:'bad',attemptId:'bad-a',items,placedAt:at}));
});
test('grocery delivery stays in shopping history without creating a consumed meal or calendar entry',()=>{
 const start=initialState();let s=createOrder(start,{id:'grocery',attemptId:'grocery-a',items:[{menuId:'milk',quantity:2},{menuId:'eggs',quantity:1}],placedAt:'2026-10-26T13:00:00+09:00'});
 assert.equal(s.orders[0].amount.paid,8960);assert.equal(s.orders[0].service,'shopping');
 for(let j=0;j<3;j++)s=orderEvent(s,{orderId:'grocery',eventId:'grocery-step-'+j,action:'next',at:`2026-10-26T13:${10+j*10}:00+09:00`});
 assert.equal(s.orders[0].status,'delivered');assert.equal(entriesOn(s,'2026-10-26').some(e=>e.id==='grocery'),false);assert.deepEqual(totalsFor(s,'2026-10-26'),totalsFor(start,'2026-10-26'));
 assert.throws(()=>recordDelivery(s,{orderId:'grocery',recordId:'not-meal',consumedDate:'2026-10-26'}));assert.equal(validateState(s),true);
});
test('pickup retains fulfillment while checkout rejects unknown methods',()=>{
 const params={id:'pickup',attemptId:'pickup-a',menuId:'bibimbap',placedAt:'2026-10-26T13:00:00+09:00',fulfillment:'pickup'};
 assert.equal(createOrder(initialState(),params).orders[0].fulfillment,'pickup');assert.throws(()=>createOrder(initialState(),{...params,fulfillment:'unknown'}));
});

test('Baemin Easy groceries can be ordered without inventing nutrition and stay out of meal reports',()=>{
 const start=initialState();let s=createOrder(start,{id:'easy',attemptId:'easy-a',menuId:'baemin-easy-tofu',quantity:5,couponId:'issued-pb',placedAt:'2026-10-26T13:00:00+09:00'});
 assert.equal(s.orders[0].amount.paid,6900);assert.equal(s.orders[0].items[0].nutrition,null);assert.match(s.orders[0].items[0].image,/baemin-easy-tofu/);assert.equal(s.orders[0].nutritionSource.type,'not-provided');assert.ok(validateState(JSON.parse(JSON.stringify(s))));
 for(let j=0;j<3;j++)s=orderEvent(s,{orderId:'easy',eventId:'easy-step-'+j,action:'next',at:`2026-10-26T13:${10+j*10}:00+09:00`});
 assert.deepEqual(totalsFor(s,'2026-10-26'),totalsFor(start,'2026-10-26'));assert.throws(()=>recordDelivery(s,{orderId:'easy',recordId:'not-meal',consumedDate:'2026-10-26'}));
 const invalid=structuredClone(s);invalid.orders[0].service='delivery';assert.equal(validateState(invalid),false);
});

test('mirroring-observed Baemin Easy SKUs preserve displayed size and price at checkout',()=>{
 const expected=[['milk',1990,'900mL'],['baemin-easy-sundae',5490,'700g'],['baemin-easy-pork-gukbap',5460,'700g']];
 for(const [id,price,unit] of expected){const p=PRODUCTS.find(p=>p.id===id);assert.equal(p.price,price);assert.equal(p.unit,unit);assert.equal(p.priceSource,'mirroring-observed');assert.equal(p.nutrition,null);assert.match(p.image,/assets\/captured\/easy-/);}
 const ordered=createOrder(initialState(),{id:'actual-milk',attemptId:'actual-milk-a',menuId:'milk',placedAt:'2026-10-26T13:00:00+09:00'});assert.equal(ordered.orders[0].amount.paid,1990);assert.equal(ordered.orders[0].items[0].unitPrice,1990);assert.ok(validateState(ordered));
});
