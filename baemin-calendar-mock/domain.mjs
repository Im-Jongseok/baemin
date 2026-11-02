import {awardOrderRewards} from './calendar.mjs';
import {issueDemoCoupons,quoteCoupon} from './insights.mjs';
import {EXTRA_SHOPS,EXTRA_MENUS,PRODUCTS} from './catalog.mjs';
import {normalizeSupplierNutrition} from './supplier.mjs';
export const VERSION = 1;
export const STORAGE_KEY = 'baemin-order-calendar-mock-v1';
export const TIME_ZONE = 'Asia/Seoul';
export const STATUS = {pending:'접수 대기',preparing:'조리 중',delivering:'배달 중',delivered:'배달 완료',cancelled:'전체 취소'};
export const TERMINAL = new Set(['delivered','cancelled']);
export const SHOPS = [
  {id:'mint-kitchen',name:'민트키친',category:'한식',rating:4.9,minOrder:10000,open:true},
  {id:'noodle-house',name:'한그릇 국수',category:'면요리',rating:4.8,minOrder:9000,open:true},
  {id:'chicken-house',name:'동네치킨',category:'치킨',rating:4.9,minOrder:18000,open:false},
  ...EXTRA_SHOPS
];
export const MENUS = [
  {id:'bibimbap',shopId:'mint-kitchen',name:'채소 비빔밥',price:11000,kind:'bowl',nutrition:{calories:620,carbs:88,protein:21,fat:20}},
  {id:'salmon',shopId:'mint-kitchen',name:'연어 포케',price:13500,kind:'salmon',nutrition:{calories:540,carbs:54,protein:32,fat:22}},
  {id:'noodles',shopId:'noodle-house',name:'잔치국수',price:9000,kind:'noodles',nutrition:{calories:480,carbs:83,protein:16,fat:8}},
  {id:'chicken',shopId:'chicken-house',name:'후라이드 치킨',price:22000,kind:'chicken',nutrition:{calories:1840,carbs:92,protein:116,fat:112}},
  ...EXTRA_MENUS
];
export const money = value => Math.round(value).toLocaleString('ko-KR')+'원';
export function kstDate(iso) {
  const d = new Date(iso);
  if (!Number.isFinite(d.getTime())) throw new Error('날짜를 확인해 주세요.');
  return new Intl.DateTimeFormat('en-CA',{timeZone:TIME_ZONE,year:'numeric',month:'2-digit',day:'2-digit'}).format(d);
}
export function validDate(value) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const d = new Date(value+'T12:00:00+09:00');
  return Number.isFinite(d.getTime()) && kstDate(d)===value;
}
export function validNutrition(n) {
  if (!n || !['calories','carbs','protein','fat'].every(k=>typeof n[k]==='number' && Number.isFinite(n[k]) && n[k]>=0)) return false;
  return n.calories<=20000 && ['carbs','protein','fat'].every(k=>n[k]<=3000);
}
export function scaleNutrition(n,ratio) {
  if (!validNutrition(n) || !Number.isFinite(ratio) || ratio<=0 || ratio>4) throw new Error('섭취량과 영양값을 확인해 주세요.');
  return Object.fromEntries(['calories','carbs','protein','fat'].map(k=>[k,Math.round(n[k]*ratio*10)/10]));
}
const clone = s => structuredClone(s);
export function createOrder(state,{id,attemptId,menuId,quantity=1,items=null,placedAt,fulfillment='delivery',couponId=null}) {
  if (state.orders.some(o=>o.attemptId===attemptId)) return state;
  const catalog=[...MENUS,...PRODUCTS],requests=items||[{menuId,quantity}];
  if(!Array.isArray(requests)||!requests.length||requests.length>40||new Set(requests.map(r=>r.menuId)).size!==requests.length)throw new Error('장바구니 메뉴를 확인해 주세요.');
  const first=catalog.find(m=>m.id===requests[0].menuId),shop=SHOPS.find(s=>s.id===first?.shopId);
  if(!shop?.open)throw new Error('지금 주문할 수 있는 메뉴를 선택해 주세요.');
  if(!id||!attemptId||state.orders.some(o=>o.id===id))throw new Error('주문 식별자를 확인해 주세요.');
  kstDate(placedAt);
  if(!['delivery','pickup'].includes(fulfillment))throw new Error('주문 방식을 확인해 주세요.');
  const snapshots=requests.map((r,index)=>{
    const menu=catalog.find(m=>m.id===r.menuId);
    if(!menu||menu.shopId!==shop.id)throw new Error('같은 가게의 메뉴만 함께 주문할 수 있어요.');
    if(!Number.isInteger(r.quantity)||r.quantity<1||r.quantity>10)throw new Error('수량은 1~10개까지 선택할 수 있어요.');
    let nutrition=null;
    if(menu.nutrition){
      const feed={menuId:menu.id,menuVersion:'menu-demo-2026-10',origin:'fixture',sourceId:'baemin-mock-catalog',basis:'per_serving',nutrients:Object.fromEntries(Object.entries(menu.nutrition).map(([k,value])=>[k,{value,unit:k==='calories'?'kcal':'g'}]))};
      nutrition=normalizeSupplierNutrition(feed,{menuId:menu.id,menuVersion:feed.menuVersion}).nutrition;
    }else if(shop.service!=='shopping')throw new Error('음식 메뉴의 영양정보를 확인해 주세요.');
    return {id:id+'-'+index,menuId:menu.id,name:menu.name,kind:menu.kind,image:menu.image||null,unitPrice:menu.price,quantity:r.quantity,nutrition:clone(nutrition)};
  });
  const total=snapshots.reduce((n,i)=>n+i.unitPrice*i.quantity,0);
  if(total<shop.minOrder)throw new Error('최소주문금액을 확인해 주세요.');
  const coupon=couponId?(state.coupons||[]).find(c=>c.id===couponId):null;
  const quote=couponId?quoteCoupon(coupon,{shopId:shop.id,service:shop.service||'delivery',items:snapshots,date:kstDate(placedAt)}):{eligible:true,discount:0,total};
  if(!quote.eligible)throw new Error(quote.reason);
  const next=clone(state);if(couponId){const used=next.coupons.find(c=>c.id===couponId);used.usedAt=placedAt;used.usedOrderId=id;}
  next.orders.unshift({id,attemptId,shopId:shop.id,shopName:shop.name,service:shop.service||'delivery',fulfillment:shop.service==='shopping'?'delivery':fulfillment,placedAt,status:'pending',items:snapshots,
    coupon:couponId?{id:couponId,title:coupon.title,source:'fixture'}:null,amount:{subtotal:total,deliveryFee:0,discount:quote.discount,paid:quote.total,refunded:0},nutritionSource:shop.service==='shopping'&&snapshots.some(i=>i.nutrition===null)?{type:'not-provided',label:'영양정보 미제공'}:{type:'baemin-fixture',label:'배민 제공 데이터 · 시연값',version:'menu-demo-2026-10'},history:[{status:'pending',at:placedAt}],completedAt:null});
  return next;
}
export function orderEvent(state,{orderId,eventId,action,at}) {
  if (state.events.includes(eventId)) return state;
  if (!eventId) throw new Error('이벤트 식별자가 없어요.');
  const original=state.orders.find(o=>o.id===orderId);
  if (!original) throw new Error('주문을 찾을 수 없어요.');
  kstDate(at);
  if (new Date(at)<new Date(original.history.at(-1).at)) throw new Error('이전 단계보다 빠른 시각으로 이동할 수 없어요.');
  if (TERMINAL.has(original.status)) throw new Error('종료된 주문이에요.');
  const next=clone(state),order=next.orders.find(o=>o.id===orderId);
  if (action==='cancel') {
    if (order.status!=='pending') throw new Error('접수 대기 중에만 취소할 수 있어요.');
    order.status='cancelled';order.amount.refunded=order.amount.paid;
    const coupon=(next.coupons||[]).find(c=>c.usedOrderId===order.id);if(coupon){coupon.usedAt=null;coupon.usedOrderId=null;}
  } else if (action==='next') order.status=({pending:'preparing',preparing:'delivering',delivering:'delivered'})[order.status];
  else throw new Error('지원하지 않는 동작이에요.');
  order.history.push({status:order.status,at});
  if(order.status==='delivered'){order.completedAt=at;awardOrderRewards(next,order);}
  next.events.push(eventId);return next;
}
export function recordDelivery(state,{orderId,recordId,consumedDate,portion=1}) {
  const existing=state.records.find(r=>r.orderId===orderId);
  if(existing) return state;
  const order=state.orders.find(o=>o.id===orderId);
  if (!order || order.service==='shopping' || order.status!=='delivered') throw new Error('배달 완료된 주문만 식사로 기록할 수 있어요.');
  if(!validDate(consumedDate)) throw new Error('먹은 날짜를 확인해 주세요.');
  const total={calories:0,carbs:0,protein:0,fat:0};
  for(const item of order.items) for(const k in total) total[k]+=item.nutrition[k]*item.quantity;
  const next=clone(state);
  next.records.push({id:recordId,orderId,date:consumedDate,name:order.items.map(i=>i.name).join(' · '),kind:order.items[0].kind,
    source:'baemin-fixture',sourceLabel:'배민 제공 데이터 · 시연값',nutrition:scaleNutrition(total,portion),portion,
    restaurant:order.shopName,image:null,confirmed:true});return next;
}
export function recordPhoto(state,{id,date,name,nutrition,image,source,modelId=null,ingredients=[],analysisId}) {
  if(state.records.some(r=>r.analysisId===analysisId)) return state;
  if(!id||!analysisId||!validDate(date)||!String(name).trim()||!validNutrition(nutrition)) throw new Error('음식 이름·날짜·영양값을 확인해 주세요.');
  if(!['photo-demo','hf-estimate','manual'].includes(source)) throw new Error('분석 출처를 확인해 주세요.');
  const next=clone(state);next.records.push({id,analysisId,date,name:String(name).trim().slice(0,100),nutrition:clone(nutrition),
    source,sourceLabel:({'photo-demo':'사진 분석 데모값','hf-estimate':'사진 AI 추정 · 확인됨',manual:'직접 입력'})[source],
    modelId,ingredients:ingredients.slice(0,20),image,kind:'bowl',confirmed:true,orderId:null});return next;
}
export function setFavorite(state,shopId,on) {
  if(!SHOPS.some(s=>s.id===shopId)) throw new Error('가게를 찾을 수 없어요.');
  const next=clone(state);next.favorites=on?[...new Set([...next.favorites,shopId])]:next.favorites.filter(id=>id!==shopId);return next;
}
export function submitReview(state,{orderId,rating,text}) {
  const order=state.orders.find(o=>o.id===orderId);
  if(!order||order.status!=='delivered'||!Number.isInteger(rating)||rating<1||rating>5) throw new Error('배달 완료 주문의 별점을 선택해 주세요.');
  if(state.reviews.some(r=>r.orderId===orderId)) return state;
  const next=clone(state);next.reviews.push({orderId,rating,text:String(text).trim().slice(0,1000)});return next;
}
export function entriesOn(state,date,filter='all') {
  const orders=state.orders.filter(o=>o.service!=='shopping'&&kstDate(o.placedAt)===date && (filter==='all'||filter==='delivery'||filter===o.status))
    .map(o=>({type:'order',id:o.id,order:o}));
  const records=state.records.filter(r=>r.date===date && (!r.orderId || !state.orders.some(o=>o.id===r.orderId&&kstDate(o.placedAt)===date)))
    .filter(r=>filter==='all'||filter==='photo'&&!r.orderId).map(r=>({type:'record',id:r.id,record:r}));
  return filter==='photo'?records:orders.concat(records);
}
export function totalsFor(state,prefix,filter='all') {
  const records=state.records.filter(r=>{
    if(!r.confirmed||!r.date.startsWith(prefix))return false;
    if(filter==='all')return true;
    if(filter==='photo')return !r.orderId;
    const order=state.orders.find(o=>o.id===r.orderId);
    return !!order&&(filter==='delivery'||filter===order.status);
  });
  const totals={calories:0,carbs:0,protein:0,fat:0};for(const r of records)for(const k in totals)totals[k]+=r.nutrition[k];
  return {count:records.length,...Object.fromEntries(Object.entries(totals).map(([k,v])=>[k,Math.round(v*10)/10]))};
}
export const hasClubMembership=state=>state?.membership?.baeminClub===true;
export function validateState(state) {
  if(state?.membership!==undefined&&(!state.membership||typeof state.membership.baeminClub!=='boolean'))return false;
  if(!state || state.version!==VERSION || !['orders','records','favorites','reviews','events'].every(k=>Array.isArray(state[k])))return false;
  if(state.coupons!==undefined&&(!Array.isArray(state.coupons)||new Set(state.coupons.map(c=>c.id)).size!==state.coupons.length||!state.coupons.every(c=>typeof c.id==='string'&&Number.isFinite(c.discount)&&c.discount>0&&Number.isFinite(c.minOrder)&&c.minOrder>=0&&validDate(c.issuedAt)&&validDate(c.expiresAt))))return false;
  if(state.pointLedger!==undefined&&(!Array.isArray(state.pointLedger)||new Set(state.pointLedger.map(p=>p.benefitId)).size!==state.pointLedger.length||!state.pointLedger.every(p=>typeof p.benefitId==='string'&&Number.isInteger(p.points)&&p.points>0&&state.orders.some(o=>o.id===p.orderId&&o.status==='delivered'))))return false;
  if(!validDate(state.selectedDate)||!/^\d{4}-\d{2}$/.test(state.month))return false;
  if(new Set(state.orders.map(o=>o.id)).size!==state.orders.length ||new Set(state.records.map(r=>r.id)).size!==state.records.length)return false;
  try {
    for(const o of state.orders){kstDate(o.placedAt);if(!STATUS[o.status]||!Array.isArray(o.items)||!o.items.length||!o.items.every(i=>(validNutrition(i.nutrition)||o.service==='shopping'&&i.nutrition===null)&&Number.isInteger(i.quantity)&&i.quantity>0)||!Array.isArray(o.history)||!o.history.length||!o.amount||!['paid','refunded','subtotal','deliveryFee','discount'].every(k=>Number.isFinite(o.amount[k])&&o.amount[k]>=0)||o.amount.refunded>o.amount.paid)return false;}
    for(const r of state.records)if(!validDate(r.date)||!validNutrition(r.nutrition)||!r.confirmed)return false;
  }catch{return false;}return true;
}
export function initialState() {
  let s={version:VERSION,month:'2026-10',selectedDate:'2026-10-26',view:'week',membership:{baeminClub:false},coupons:issueDemoCoupons(kstDate(new Date())),orders:[],records:[],favorites:['mint-kitchen','chicken-house'],reviews:[],events:[]};
  const dates=['2026-09-03','2026-09-03','2026-09-09','2026-09-21','2026-10-03','2026-10-12','2026-10-21','2026-10-23','2026-10-26'];
  dates.forEach((date,i)=>{
    const menu=MENUS[i%3],id='seed-order-'+i;
    s=createOrder(s,{id,attemptId:'seed-attempt-'+i,menuId:menu.id,quantity:1,placedAt:date+`T${i%2?'18':'12'}:00:00+09:00`});
    if(i===4)s=orderEvent(s,{orderId:id,eventId:id+'cancel',action:'cancel',at:date+'T12:01:00+09:00'});
    else {
      for(let j=0;j<3;j++)s=orderEvent(s,{orderId:id,eventId:id+'step'+j,action:'next',at:date+`T${i%2?'18':'12'}:${10+j*10}:00+09:00`});
      if(i!==7)s=recordDelivery(s,{orderId:id,recordId:'seed-record-'+i,consumedDate:date});
    }
  });
  s=submitReview(s,{orderId:'seed-order-6',rating:5,text:'맛있게 먹었어요. (시연 리뷰)'});
  return s;
}
