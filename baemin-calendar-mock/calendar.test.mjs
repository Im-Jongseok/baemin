import test from 'node:test';
import assert from 'node:assert/strict';
import {calendarBenefits,dailyMeals,claimCalendarCoupon,pointsBalance,orderRewards,visibleCalendarBenefits,benefitOffer} from './calendar.mjs';
import {initialState,createOrder,orderEvent,recordDelivery,validateState} from './domain.mjs';
import {quoteCoupon} from './insights.mjs';
const blank=()=>({...initialState(),orders:[],records:[],events:[],pointLedger:[],coupons:[]});
function order(s,day,id='o',fulfillment='delivery',menuId='bibimbap'){
 return createOrder(s,{id,attemptId:id,menuId,placedAt:`2026-10-${day}T12:00:00+09:00`,fulfillment});
}
function finish(s,id,day){for(let i=0;i<3;i++)s=orderEvent(s,{orderId:id,eventId:id+'-'+i,action:'next',at:`2026-10-${day}T12:0${i+1}:00+09:00`});return s;}
test('photo calendar counts confirmed meals by consumed date, filters sources and excludes cancelled linked records',()=>{
 let s=finish(order(blank(),'26'),'o','26');s=recordDelivery(s,{orderId:'o',recordId:'r',consumedDate:'2026-10-27',portion:.5});
 assert.equal(dailyMeals(s,'2026-10-26').records.length,0);
 assert.equal(dailyMeals(s,'2026-10-27').calories,310);
 s.records.push({id:'photo',date:'2026-10-27',confirmed:true,name:'사과',nutrition:{calories:100},orderId:null});
 assert.equal(dailyMeals(s,'2026-10-27').calories,410);
 assert.equal(dailyMeals(s,'2026-10-27','photo').calories,100);
 assert.equal(dailyMeals(s,'2026-10-27','delivery').calories,310);
 s.orders[0].status='cancelled';assert.equal(dailyMeals(s,'2026-10-27').calories,100);
});
test('campaign points credit only on completion, survive serialization and do not credit twice per day',()=>{
 let s=order(blank(),'26');assert.equal(pointsBalance(s),0);s=finish(s,'o','26');
 assert.equal(pointsBalance(s),500);assert.equal(pointsBalance(JSON.parse(JSON.stringify(s))),500);
 s=finish(order(s,'26','second'),'second','26');assert.equal(pointsBalance(s),500);
 assert.ok(validateState(s));
});
test('pickup benefit requires eligible day, amount and pickup; cancellation and grocery do not earn food points',()=>{
 assert.equal(pointsBalance(finish(order(blank(),'30','pickup','pickup'),'pickup','30')),1000);
 assert.equal(pointsBalance(finish(order(blank(),'30','delivery'),'delivery','30')),0);
 assert.equal(pointsBalance(finish(order(blank(),'30','low','pickup','noodles'),'low','30')),1000);
 assert.equal(pointsBalance(finish(order(blank(),'27'),'o','27')),0);
 let s=order(blank(),'26');s=orderEvent(s,{orderId:'o',eventId:'cancel',action:'cancel',at:'2026-10-26T12:01:00+09:00'});assert.equal(pointsBalance(s),0);
 s=createOrder(blank(),{id:'grocery',attemptId:'grocery',items:[{menuId:'pb-eggs',quantity:3}],placedAt:'2026-10-26T12:00:00+09:00'});assert.equal(pointsBalance(finish(s,'grocery','26')),0);
});
test('calendar coupon can be claimed only on campaign day, once, and its same-day checkout rules apply',()=>{
 const s=blank();assert.throws(()=>claimCalendarCoupon(s,'2026-10-29','2026-10-28'));
 assert.throws(()=>claimCalendarCoupon(s,'2026-10-29','2026-10-30'));
 const next=claimCalendarCoupon(s,'2026-10-29','2026-10-29');assert.equal(s.coupons.length,0);
 assert.equal(claimCalendarCoupon(next,'2026-10-29','2026-10-29'),next);
 const c=next.coupons[0],input={date:'2026-10-29',shopId:'bmart',service:'shopping',items:[{menuId:'pb-eggs',unitPrice:4490,quantity:3}]};
 assert.equal(quoteCoupon(c,input).discount,3000);
 assert.equal(quoteCoupon(c,{...input,date:'2026-10-30'}).eligible,false);
 assert.equal(quoteCoupon(c,{...input,shopId:'fresh-market'}).eligible,false);
 assert.ok(validateState(next));
});
test('minimum spend is checked for both order and pickup bonuses',()=>{
 const base={id:'preview',service:'delivery',fulfillment:'delivery',placedAt:'2026-10-26T12:00:00+09:00',amount:{subtotal:9999}};
 assert.equal(orderRewards(blank(),base).length,0);
 assert.equal(orderRewards(blank(),{...base,amount:{subtotal:10000}}).length,1);
 assert.equal(orderRewards(blank(),{...base,placedAt:'2026-10-30T12:00:00+09:00',fulfillment:'pickup',amount:{subtotal:8999}}).length,0);
});
test('campaign ids include year and month so monthly benefits do not collide',()=>{
 assert.notEqual(calendarBenefits('2026-10-26')[0].id,calendarBenefits('2026-11-26')[0].id);
});

test('visible benefit offers omit expired dates and reveal upcoming conditions without issuing coupons or points',()=>{
 const s=blank(),before=JSON.stringify(s);assert.deepEqual(visibleCalendarBenefits('2026-10-19','2026-10-26'),[]);
 const coupon=calendarBenefits('2026-10-29')[0],offer=benefitOffer(s,'2026-10-29',coupon.id,'2026-10-26');
 assert.equal(offer.phase,'upcoming');assert.equal(offer.destination,'bmart');assert.equal(JSON.stringify(s),before);
 assert.equal(benefitOffer(s,'2026-10-19','order-points-2026-10-19','2026-10-26'),null);
 assert.equal(benefitOffer(s,'2026-10-30','pickup-points-2026-10-30','2026-10-26').destination,'pickup');
});
test('an earned or claimed benefit is identified without promising a second award',()=>{
 let s=finish(order(blank(),'26'),'o','26');assert.equal(benefitOffer(s,'2026-10-26','order-points-2026-10-26','2026-10-26').phase,'earned');
 s=claimCalendarCoupon(s,'2026-10-29','2026-10-29');const id='market-coupon-2026-10-29';assert.equal(benefitOffer(s,'2026-10-29',id,'2026-10-29').phase,'claimed');
 s.coupons.find(c=>c.id===id).usedAt='2026-10-29T12:00:00+09:00';assert.equal(benefitOffer(s,'2026-10-29',id,'2026-10-29').phase,'used');
});
