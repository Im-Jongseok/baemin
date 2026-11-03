// Local presentation campaigns. No real Baemin benefit is issued.
const dateOf=iso=>new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Seoul',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date(iso));
export function calendarBenefits(date){
 const day=Number(date.slice(8)),items=[];
 if([18,19,26,28].includes(day))items.push({id:'order-points-'+date,type:'points',date,title:'주문하면 500P',description:'음식배달·픽업 10,000원 이상 주문 완료 시 500P',points:500,minOrder:10000,asset:'points'});
 if([22,23,29].includes(day))items.push({id:'market-coupon-'+date,type:'coupon',date,title:'B마트 3,000원',description:'당일 쿠폰 받기 · B마트 9,000원 이상 장보기 시 3,000원 할인',discount:3000,minOrder:9000,asset:'coupon'});
 if([20,25,30].includes(day))items.push({id:'pickup-points-'+date,type:'pickup',date,title:'픽업하면 1,000P',description:'픽업 9,000원 이상 주문 완료 시 추가 1,000P',points:1000,minOrder:9000,asset:'pickup'});
 return items;
}
export const visibleCalendarBenefits=(date,today)=>date>=today?calendarBenefits(date):[];
export function benefitOffer(state,date,benefitId,today){
 const benefit=visibleCalendarBenefits(date,today).find(b=>b.id===benefitId);
 if(!benefit)return null;
 const coupon=(state.coupons||[]).find(c=>c.id===benefit.id),earned=(state.pointLedger||[]).some(p=>p.benefitId===benefit.id);
 const phase=earned?'earned':coupon?.usedAt?'used':coupon?'claimed':date>today?'upcoming':'available';
 return {...benefit,phase,destination:benefit.type==='coupon'?'bmart':benefit.type==='pickup'?'pickup':'delivery'};
}
export function dailyMeals(state,date,filter='all'){
 const byOrder=new Map(state.orders.map(o=>[o.id,o]));
 const records=state.records.filter(r=>{
  const order=byOrder.get(r.orderId);
  if(!r.confirmed||r.date!==date||order&&(order.status!=='delivered'||order.service==='shopping'))return false;
  if(filter==='photo')return !r.orderId;
  if(filter==='delivery')return !!order;
  return filter==='all'||order?.status===filter;
 });
 return {records,calories:Math.round(records.reduce((sum,r)=>sum+r.nutrition.calories,0)),names:records.map(r=>r.name),cover:records[0]||null};
}
export function orderRewards(state,order){
 if(order.service==='shopping'||order.status==='cancelled')return [];
 const date=dateOf(order.placedAt);
 return calendarBenefits(date).filter(b=>b.points&&order.amount.subtotal>=b.minOrder&&(b.type!=='pickup'||order.fulfillment==='pickup')&&!(state.pointLedger||[]).some(p=>p.benefitId===b.id&&p.orderId!==order.id));
}
export function awardOrderRewards(state,order){
 if(order.status!=='delivered')return;
 state.pointLedger??=[];
 for(const benefit of orderRewards(state,order))if(!state.pointLedger.some(p=>p.benefitId===benefit.id))state.pointLedger.push({id:benefit.id,benefitId:benefit.id,orderId:order.id,points:benefit.points,title:benefit.title,at:order.completedAt,source:'fixture'});
}
export const pointsBalance=state=>(state.pointLedger||[]).reduce((n,p)=>n+p.points,0);
export function claimCalendarCoupon(state,date,today){
 const benefit=calendarBenefits(date).find(b=>b.type==='coupon');
 if(!benefit||date!==today)throw new Error('장보기 쿠폰은 표시된 날짜에 받을 수 있어요.');
 if((state.coupons||[]).some(c=>c.id===benefit.id))return state;
 const next=structuredClone(state);next.coupons??=[];
 next.coupons.push({id:benefit.id,title:'캘린더 B마트 3,000원',description:'캘린더에서 받은 당일 장보기 쿠폰 · B마트 9,000원 이상',shopId:'bmart',service:'shopping',discount:3000,minOrder:9000,issuedAt:date,expiresAt:date,seenAt:today,usedAt:null,source:'fixture'});
 return next;
}
