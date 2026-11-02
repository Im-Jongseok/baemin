import test from 'node:test';
import assert from 'node:assert/strict';
import {issueDemoCoupons,couponStatus,quoteCoupon,markCouponsSeen,buildReport,demoReportState,dayOffset,reportWindow,calendarReportWindow,mealSuggestion,mealSuggestions,nutritionBalance,NUTRITION_REFERENCE,baeminEasySelection,RECIPES,recipeQuote} from './insights.mjs';
import {initialState,createOrder,orderEvent,validateState,MENUS,SHOPS} from './domain.mjs';
import {PRODUCTS} from './catalog.mjs';
const DATE='2026-10-26',AT=DATE+'T12:00:00+09:00';
const fresh=()=>({...initialState(),coupons:issueDemoCoupons(DATE)});
const nutrients=calories=>({calories,carbs:40,protein:20,fat:10});
test('coupon eligibility checks issue/expiry, shop, target menus, minimum and PB requirement',()=>{
 const coupons=issueDemoCoupons(DATE),green=coupons[0],pb=coupons[1];
 const input={shopId:'mint-kitchen',service:'delivery',date:DATE,items:[{menuId:'salmon',unitPrice:13500,quantity:1}]};
 assert.equal(quoteCoupon(green,input).discount,2000);
 assert.equal(quoteCoupon(green,{...input,date:dayOffset(green.expiresAt,1)}).eligible,false);
 assert.equal(quoteCoupon(green,{...input,shopId:'pizza-club'}).eligible,false);
 assert.equal(quoteCoupon(green,{...input,items:[{menuId:'noodles',unitPrice:13500,quantity:1}]}).eligible,false);
 assert.equal(quoteCoupon(green,{...input,items:[{menuId:'salmon',unitPrice:9000,quantity:1}]}).eligible,false);
 assert.equal(quoteCoupon(pb,{shopId:'bmart',service:'shopping',date:DATE,items:[{menuId:'apple',unitPrice:6900,quantity:2}]}).eligible,false);
 assert.equal(couponStatus(green,dayOffset(green.issuedAt,-1)),'not-issued');
 assert.equal(quoteCoupon({...green,discount:20000},input).discount,13500);
});
test('PB recipe prices reflect package quantities and the already-issued coupon',()=>{
 const q=recipeQuote(RECIPES[0],[...MENUS,...PRODUCTS],issueDemoCoupons(DATE),DATE);
 assert.equal(q.subtotal,9960);assert.equal(q.discount,3000);assert.equal(q.total,6960);
 const used=issueDemoCoupons(DATE).map(c=>({...c,usedAt:AT}));
 assert.equal(recipeQuote(RECIPES[0],[...MENUS,...PRODUCTS],used,DATE).discount,0);
});
test('checkout atomically consumes coupon, preserves paid snapshot, is idempotent and rejects reuse',()=>{
 const original=fresh(),params={id:'green-order',attemptId:'green-attempt',menuId:'salad-poke',couponId:'issued-greens',placedAt:AT};
 const s=createOrder(original,params);assert.equal(s.orders[0].amount.subtotal,12500);assert.equal(s.orders[0].amount.discount,2000);assert.equal(s.orders[0].amount.paid,10500);
 assert.equal(s.coupons[0].usedOrderId,'green-order');assert.equal(original.coupons[0].usedAt,null);assert.equal(createOrder(s,params),s);assert.equal(validateState(s),true);
 assert.throws(()=>createOrder(s,{...params,id:'again',attemptId:'again-attempt'}),/쿠폰/);
});
test('full cancellation refunds discounted paid amount and restores coupon without extending expiry',()=>{
 let s=createOrder(fresh(),{id:'cancel-coupon',attemptId:'cancel-a',menuId:'salmon',couponId:'issued-greens',placedAt:AT});
 const expires=s.coupons[0].expiresAt;
 s=orderEvent(s,{orderId:'cancel-coupon',eventId:'cancel-event',action:'cancel',at:DATE+'T12:05:00+09:00'});
 assert.equal(s.orders[0].amount.refunded,11500);assert.equal(s.coupons[0].usedAt,null);assert.equal(s.coupons[0].expiresAt,expires);
 assert.equal(couponStatus(s.coupons[0],dayOffset(expires,1)),'expired');
});
test('viewing wallet marks existing available coupons seen without issuing new coupons',()=>{
 const s=fresh(),next=markCouponsSeen(s,DATE);assert.equal(next.coupons.length,s.coupons.length);assert.ok(next.coupons.every(c=>c.seenAt===DATE));assert.ok(s.coupons.every(c=>c.seenAt===null));
 const legacy={...s};delete legacy.coupons;assert.equal(validateState(legacy),true);
 assert.equal(validateState({...s,coupons:[s.coupons[0],s.coupons[0]]}),false);
});
test('report separates completed orders from consumed dates, excludes shopping and leaves absent days unknown',()=>{
 const o=(id,status,service,placedAt)=>({id,status,service,placedAt,shopId:'mint-kitchen',items:[{menuId:'salmon'}]});
 const s={orders:[o('old','delivered','delivery','2026-10-10T23:00:00+09:00'),o('today','delivered','delivery',AT),o('grocery','delivered','shopping',AT),o('cancel','cancelled','delivery',AT),o('pending','preparing','delivery',AT)],records:[{id:'old-meal',orderId:'old',confirmed:true,date:'2026-10-21',nutrition:nutrients(500)},{id:'direct',orderId:null,confirmed:true,date:DATE,nutrition:nutrients(300)},{id:'not-meal',orderId:'grocery',confirmed:true,date:DATE,nutrition:nutrients(900)},{id:'cancelled-meal',orderId:'cancel',confirmed:true,date:DATE,nutrition:nutrients(2000)}]};
 const r=buildReport(s,{endDate:DATE,shops:SHOPS});assert.equal(r.completed,1);assert.equal(r.records,2);assert.equal(r.totals.calories,800);assert.equal(r.recordDays,2);assert.equal(r.missingDays,5);assert.equal(r.sources.delivery,1);assert.equal(r.sources.direct,1);assert.equal(r.unconfirmedOrders,1);assert.equal(r.averageCalories,400);
 assert.equal(r.days.find(d=>d.date==='2026-10-22').count,0);
});
test('delivery-heavy preview is explicit derived data and does not modify stored orders or meal history',()=>{
 const original=fresh(),before=JSON.stringify(original),example=demoReportState(original,DATE);
 const r=buildReport(example.state,{endDate:DATE,shops:example.shops});assert.equal(r.pattern,'frequent-delivery');assert.equal(r.delivery,5);assert.equal(r.deliveryDays,5);assert.equal(JSON.stringify(original),before);
 const empty=buildReport({orders:[],records:[]},{endDate:DATE});assert.equal(empty.pattern,'insufficient');assert.equal(empty.averageCalories,null);assert.equal(empty.missingDays,7);
 assert.equal(reportWindow(DATE,'month').dates.length,26);assert.equal(dayOffset('2026-10-31',1),'2026-11-01');
});

test('habit summary uses consumed meals for delivery share and macros, completed delivery orders for menu concentration',()=>{
 const s={orders:[{id:'food',status:'delivered',service:'delivery',fulfillment:'delivery',placedAt:AT,shopId:'mint-kitchen',items:[{menuId:'salmon'}]},{id:'pickup',status:'delivered',service:'delivery',fulfillment:'pickup',placedAt:AT,shopId:'noodle-house',items:[{menuId:'noodles'}]}],records:[{id:'a',orderId:'food',confirmed:true,date:DATE,nutrition:{calories:500,carbs:50,protein:30,fat:20}},{id:'b',orderId:null,confirmed:true,date:DATE,nutrition:{calories:200,carbs:20,protein:10,fat:0}},{id:'c',orderId:'pickup',confirmed:true,date:DATE,nutrition:{calories:300,carbs:30,protein:10,fat:5}}]};
 const r=buildReport(s,{endDate:DATE,shops:SHOPS});assert.equal(r.habits.deliveryShare,33);assert.equal(r.averageCalories,333);assert.deepEqual(r.habits.dominantCategory,{name:'한식',share:100});assert.equal(Object.values(r.habits.macroShares).reduce((n,v)=>n+v,0),100);
 assert.equal(r.habits.macroShares.carbs,49);assert.equal(r.habits.macroShares.protein,24);assert.equal(r.habits.macroShares.fat,27);
});
test('habit summary leaves absent and zero-energy data unknown instead of inventing a healthy score',()=>{
 const r=buildReport({orders:[],records:[]},{endDate:DATE});assert.equal(r.habits.deliveryShare,null);assert.equal(r.habits.macroShares,null);assert.equal(r.habits.dominantCategory,null);
 const zero=buildReport({orders:[],records:[{id:'zero',orderId:null,date:DATE,confirmed:true,nutrition:{calories:0,carbs:0,protein:0,fat:0}}]},{endDate:DATE});assert.equal(zero.habits.deliveryShare,0);assert.equal(zero.habits.macroShares,null);
 const rounding=buildReport({orders:[],records:[{id:'round',orderId:null,date:DATE,confirmed:true,nutrition:{calories:32,carbs:1,protein:7,fat:0}}]},{endDate:DATE});assert.equal(rounding.habits.macroShares.fat,0);assert.equal(Object.values(rounding.habits.macroShares).reduce((n,v)=>n+v,0),100);
});

test('calendar report periods match the whole displayed month and Sunday-to-Saturday week across year boundaries',()=>{
 assert.deepEqual(calendarReportWindow({month:'2026-09',selectedDate:'2026-09-21',view:'month'}),{start:'2026-09-01',end:'2026-09-30',mode:'month',label:'2026년 9월 월간'});
 const leap=calendarReportWindow({month:'2028-02',selectedDate:'2028-02-14',view:'month'});assert.equal(leap.end,'2028-02-29');
 const week=calendarReportWindow({month:'2026-10',selectedDate:'2026-10-26',view:'week'});assert.equal(week.start,'2026-10-25');assert.equal(week.end,'2026-10-31');
 const cross=calendarReportWindow({month:'2027-01',selectedDate:'2027-01-01',view:'week'});assert.equal(cross.start,'2026-12-27');assert.equal(cross.end,'2027-01-02');
});
test('report aggregates use the exact selected calendar range rather than a trailing week or current month',()=>{
 const state={orders:[],records:['2026-09-01','2026-09-30','2026-10-24','2026-10-25','2026-10-31','2026-11-01'].map((date,i)=>({id:'meal-'+i,confirmed:true,date,orderId:null,nutrition:nutrients(100)}))};
 const month=calendarReportWindow({month:'2026-09',selectedDate:'2026-09-21',view:'month'}),mr=buildReport(state,{startDate:month.start,endDate:month.end,mode:month.mode});assert.equal(mr.records,2);assert.equal(mr.totals.calories,200);assert.equal(mr.window.dates.length,30);
 const week=calendarReportWindow({month:'2026-10',selectedDate:'2026-10-26',view:'week'}),wr=buildReport(state,{startDate:week.start,endDate:week.end,mode:week.mode});assert.equal(wr.records,2);assert.equal(wr.totals.calories,200);assert.equal(wr.window.dates.length,7);
});

test('delivery-frequency threshold scales with the selected report length',()=>{
 const example=demoReportState(fresh(),DATE);
 assert.equal(buildReport(example.state,{startDate:'2026-10-20',endDate:'2026-10-26',shops:example.shops}).pattern,'frequent-delivery');
 assert.notEqual(buildReport(example.state,{startDate:'2026-10-01',endDate:'2026-10-31',mode:'month',shops:example.shops}).pattern,'frequent-delivery');
});


const reportWithShares=(carbs,protein,fat)=>({records:4,recordDays:1,delivery:5,sources:{delivery:3,pickup:0,direct:1},totals:{calories:1000,carbs:carbs*2.5,protein:protein*2.5,fat:fat*10/9},menuChoices:[{menuId:'bibimbap',name:'채소 비빔밥',count:3}],habits:{deliveryShare:75}});
const distance=b=>b.flags.reduce((n,f)=>n+f.gap,0);
test('2025 adult macro reference includes its boundaries and only measures confirmed meal energy composition',()=>{
 assert.deepEqual(NUTRITION_REFERENCE.ranges,{carbs:[50,65],protein:[10,20],fat:[15,30]});
 for(const shares of [[65,20,15],[50,20,30],[60,10,30]])assert.equal(nutritionBalance(reportWithShares(...shares)).status,'balanced');
 const above=nutritionBalance(reportWithShares(65.1,10,24.9));assert.equal(above.status,'adjust');assert.equal(above.primary.key,'carbs');assert.equal(above.primary.direction,'high');
});
test('balanced nutrients remain positive despite repeated vegetable bowls and frequent delivery',()=>{
 const r=reportWithShares(61,14,25),saved=JSON.stringify(r),rows=mealSuggestions(r,MENUS,SHOPS);
 assert.equal(rows[0].balanceStatus,'balanced');assert.equal(rows[0].tone,'positive');assert.match(rows[0].title,/参考|참고 범위/);assert.match(rows[0].reason,/현재의 구성/);assert.doesNotMatch(rows[0].reason,/고기를|부족|결핍|배달로/);assert.ok(rows[0].menuId);assert.equal(JSON.stringify(r),saved);
 const m=MENUS.find(m=>m.id===rows[0].menuId);assert.equal(nutritionBalance({...r,totals:m.nutrition,records:1}).status,'balanced');
});
test('menus must reduce both total imbalance and the main nutrient deviation using actual catalog grams',()=>{
 for(const values of [[76,7,17],[40,18,42],[48,35,17],[70,9,21]]){
  const r=reportWithShares(...values),before=nutritionBalance(r),rows=mealSuggestions(r,MENUS,SHOPS),chosen=rows.find(s=>s.target==='menu');assert.ok(chosen,values.join('/'));
  const m=MENUS.find(m=>m.id===chosen.menuId);const after=nutritionBalance({...r,totals:Object.fromEntries(['carbs','protein','fat'].map(k=>[k,r.totals[k]+m.nutrition[k]]))});assert.ok(distance(after)<distance(before));
  assert.equal(chosen.metric.value,before.primary.share);assert.match(chosen.evidence,/탄수화물/);assert.match(chosen.evidence,/단백질/);assert.match(chosen.evidence,/지방/);
 }
});
test('delivery, menu titles and order frequency cannot replace missing nutrient data',()=>{
 const r={...reportWithShares(61,14,25),totals:undefined};const unknown=mealSuggestions(r,MENUS,SHOPS);assert.equal(unknown[0].target,'record');assert.equal(nutritionBalance(r).status,'unknown');
 assert.equal(nutritionBalance({...r,totals:{carbs:0,protein:0,fat:0}}).status,'unknown');assert.equal(nutritionBalance({...r,records:0,totals:{carbs:100,protein:20,fat:10}}).status,'unknown');
 const original=reportWithShares(61,14,25),changed={...original,menuChoices:[{menuId:'chicken',name:'치킨',count:99}],habits:{deliveryShare:100}};assert.deepEqual(nutritionBalance(original),nutritionBalance(changed));assert.equal(mealSuggestions(changed,MENUS,SHOPS)[0].balanceStatus,'balanced');
});
test('single-day meal data is usable and recipe portions respond to the nutrient direction',()=>{
 const highCarb=mealSuggestions(reportWithShares(76,7,17),MENUS,SHOPS),recipe=highCarb.find(s=>s.target==='recipe');assert.ok(recipe);assert.equal(recipe.recipeAdjustment.rice,'밥 반 공기');assert.match(recipe.reason,/달걀 2개/);assert.ok(highCarb.every(s=>s.target!=='record'));
 const lowProtein=mealSuggestions(reportWithShares(61,8,31),MENUS,SHOPS).find(s=>s.target==='recipe');assert.ok(lowProtein);assert.equal(lowProtein.recipeAdjustment,null);assert.match(lowProtein.reason,/단백질 식품/);
 const highProtein=mealSuggestions(reportWithShares(48,35,17),MENUS,SHOPS);assert.ok(highProtein.every(s=>s.target!=='recipe'));
});
test('ranking excludes shopping, closed shops and invalid nutrient data before considering coupons',()=>{
 const r=reportWithShares(61,14,25),catalog=[...MENUS,...PRODUCTS,{id:'invalid',shopId:'mint-kitchen',name:'Invalid',nutrition:{carbs:NaN,protein:0,fat:0}}];
 const rows=mealSuggestions(r,catalog,SHOPS);rows.filter(s=>s.target==='menu').forEach(s=>{const m=catalog.find(m=>m.id===s.menuId);assert.notEqual(m.service,'shopping');assert.ok(SHOPS.find(shop=>shop.id===m.shopId).open);assert.notEqual(m.id,'invalid');});
});
test('nutrition guidance follows selected calendar periods and does not turn missing days into zero intake',()=>{
 const state={orders:[],records:[{id:'a',confirmed:true,date:'2026-10-20',nutrition:{calories:1000,carbs:190,protein:17.5,fat:170/9}},{id:'b',confirmed:true,date:'2026-10-26',nutrition:{calories:1000,carbs:152.5,protein:35,fat:250/9}}]};
 const first=buildReport(state,{startDate:'2026-10-18',endDate:'2026-10-24'}),second=buildReport(state,{startDate:'2026-10-25',endDate:'2026-10-31'}),empty=buildReport(state,{startDate:'2026-11-01',endDate:'2026-11-07'});
 assert.equal(nutritionBalance(first).status,'adjust');assert.equal(nutritionBalance(second).status,'balanced');assert.equal(nutritionBalance(empty).status,'unknown');assert.equal(second.missingDays,6);
});

test('Baemin Easy is a grocery discovery route, not a fabricated nutrient-ranking candidate',()=>{
 const all=[...MENUS,...PRODUCTS],r=reportWithShares(76,7,17),selection=baeminEasySelection(r,all);
 assert.deepEqual(selection.products.map(p=>p.id),['milk','baemin-easy-sundae','baemin-easy-pork-gukbap','baemin-easy-tofu']);assert.match(selection.title,/배민이지/);assert.ok(selection.products.every(p=>p.nutrition===null));assert.ok(mealSuggestions(r,all,SHOPS).every(s=>!selection.products.some(p=>p.id===s.menuId)));
 const highProtein=baeminEasySelection(reportWithShares(70,25,5),all);assert.doesNotMatch(highProtein.title,/단백질 식품/);
 const legacy=issueDemoCoupons(DATE).find(c=>c.id==='issued-pb');legacy.requiredMenuIds=['pb-eggs','pb-vegetables'];assert.equal(quoteCoupon(legacy,{shopId:'bmart',service:'shopping',date:DATE,items:[{menuId:'baemin-easy-tofu',quantity:5,unitPrice:1980}]}).discount,3000);
});


test('Baemin Easy gukbap is an explicit grocery suggestion without fabricated nutrient ranking',()=>{
 const catalog=[...MENUS,...PRODUCTS];
 for(const values of [[61,14,25],[76,7,17],[40,18,42]]){
  const report=reportWithShares(...values),before=JSON.stringify(report),rows=mealSuggestions(report,catalog,SHOPS),grocery=rows.filter(s=>s.target==='product');
  assert.equal(grocery.length,1);assert.equal(grocery[0].productId,'baemin-easy-pork-gukbap');assert.equal(grocery[0].nutritionStatus,'not-provided');assert.equal(grocery[0].menuNutrition,undefined);assert.equal(grocery[0].metric.value,700);assert.equal(grocery[0].metric.unit,'g');assert.match(grocery[0].metric.label,/판매 용량/);assert.match(grocery[0].evidence,/채소/);assert.equal(JSON.stringify(report),before);
  const related=baeminEasySelection(report,catalog,{suggestion:grocery[0],relatedOnly:true});assert.deepEqual(related.products.map(p=>p.id),['baemin-easy-pork-gukbap']);assert.equal(related.products[0].nutrition,null);
 }
 const closed=SHOPS.map(s=>s.id==='bmart'?{...s,open:false}:s);assert.ok(mealSuggestions(reportWithShares(61,14,25),catalog,closed).every(s=>s.target!=='product'));
});
