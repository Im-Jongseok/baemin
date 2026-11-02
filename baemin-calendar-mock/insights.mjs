import {PB_PRODUCT_IDS} from './catalog.mjs';
// Product discovery rules for this local prototype, not a clinical health assessment.
const dateOf=iso=>new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Seoul',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date(iso));
export function dayOffset(date,offset){const d=new Date(date+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+offset);return d.toISOString().slice(0,10);}
export function issueDemoCoupons(date){return [
 {id:'issued-greens',title:'포케·샐러드 2,000원',description:'포케·샐러드와 채소 메뉴에 쓸 수 있어요',shopId:'mint-kitchen',service:'delivery',discount:2000,minOrder:10000,allowedMenuIds:['salmon','salad-poke','soy-bowl'],issuedAt:dayOffset(date,-10),expiresAt:dayOffset(date,3),seenAt:null,usedAt:null,source:'fixture'},
 {id:'issued-pb',title:'B마트 PB 장보기 3,000원',description:'PB 상품을 포함해 9,000원 이상 담으면',shopId:'bmart',service:'shopping',discount:3000,minOrder:9000,requiredMenuIds:[...PB_PRODUCT_IDS],issuedAt:dayOffset(date,-7),expiresAt:dayOffset(date,5),seenAt:null,usedAt:null,source:'fixture'},
 {id:'issued-market',title:'동네마트 장보기 1,000원',description:'싱싱한 동네마트에서 10,000원 이상',shopId:'fresh-market',service:'shopping',discount:1000,minOrder:10000,issuedAt:dayOffset(date,-5),expiresAt:dayOffset(date,7),seenAt:null,usedAt:null,source:'fixture'}
];}
export function couponStatus(coupon,date){if(coupon.usedAt)return 'used';if(date<coupon.issuedAt)return 'not-issued';if(date>coupon.expiresAt)return 'expired';return 'available';}
export function quoteCoupon(coupon,{shopId,service='delivery',items,date}){
 const subtotal=items.reduce((n,i)=>n+i.unitPrice*i.quantity,0);
 const reject=reason=>({eligible:false,discount:0,total:subtotal,subtotal,reason});
 if(!coupon)return reject('선택한 쿠폰이 없어요.');
 if(couponStatus(coupon,date)!=='available')return reject('사용했거나 기간이 지난 쿠폰이에요.');
 if(coupon.shopId!==shopId||coupon.service!==service)return reject('이 가게에서 사용할 수 없는 쿠폰이에요.');
 if(subtotal<coupon.minOrder)return reject(`${coupon.minOrder.toLocaleString('ko-KR')}원 이상 주문에 사용할 수 있어요.`);
 const requiredIds=coupon.id==='issued-pb'&&coupon.source==='fixture'?[...new Set([...(coupon.requiredMenuIds||[]),...PB_PRODUCT_IDS])]:coupon.requiredMenuIds;
 if(requiredIds&&!items.some(i=>requiredIds.includes(i.menuId)))return reject('PB 상품이 한 개 이상 필요해요.');
 const eligibleSubtotal=items.filter(i=>!coupon.allowedMenuIds||coupon.allowedMenuIds.includes(i.menuId)).reduce((n,i)=>n+i.unitPrice*i.quantity,0);
 if(!eligibleSubtotal)return reject('쿠폰 대상 메뉴가 장바구니에 없어요.');
 const discount=Math.min(coupon.discount,eligibleSubtotal,subtotal);
 return {eligible:true,discount,total:subtotal-discount,subtotal,reason:''};
}
export function markCouponsSeen(state,date){return {...state,coupons:(state.coupons||[]).map(c=>couponStatus(c,date)==='available'&&!c.seenAt?{...c,seenAt:date}:c)};}
export const RECIPES=[
 {id:'pb-rice',name:'달걀 채소 볶음밥',subtitle:'오늘 한 끼는 직접 만들어볼까요?',minutes:10,shopId:'bmart',couponId:'issued-pb',kind:'bowl',servings:1,difficulty:'쉬움',description:'달걀은 부드럽게, 채소는 아삭하게. 밥 한 공기로 준비하는 한 그릇이에요.',amounts:['달걀 2개','채소 약 80g','상추 2장'],items:[{menuId:'pb-eggs',quantity:1},{menuId:'pb-vegetables',quantity:1},{menuId:'lettuce',quantity:1}],pantry:'밥·식용유·기본 양념은 집에 있는 재료를 사용해요.',steps:['다짐 채소는 볶을 만큼 덜어 준비해요. 상추는 씻어 물기를 빼고 마지막에 곁들일 크기로 잘라요.','그릇에 달걀 2개를 풀어요. 팬을 중불로 달군 뒤 식용유를 두르고 달걀을 저어 완전히 익혀 따로 덜어둬요.','같은 팬에 채소를 넣고 2~3분 볶아요. 채소에서 나온 물기가 잦아들 때까지 볶아주세요.','밥 한 공기를 넣고 뭉친 밥을 풀어가며 볶아요. 간장 1작은술을 넣고 맛을 본 뒤 필요한 만큼만 더해요.','덜어둔 달걀을 다시 넣고 고루 섞어요. 불을 끄고 상추를 곁들여 마무리해요.'],stepTitles:['재료 손질','달걀 먼저 익히기','채소 볶기','밥과 간장 넣기','한 그릇 완성'],tips:'찬밥을 쓰면 밥알이 덜 뭉쳐요. 물기 있는 채소는 먼저 충분히 볶아주세요.',note:'구매 가격은 재료 한 팩씩의 합계예요. 한 끼 분량의 가격과는 달라요.'},
 {id:'market-sandwich',name:'달걀 채소 샌드위치',subtitle:'장보기로 준비하는 다음 식사',minutes:15,shopId:'fresh-market',couponId:'issued-market',kind:'bread',servings:1,difficulty:'쉬움',description:'달걀과 채소를 차곡차곡. 팬 하나로 준비하는 간단한 샌드위치예요.',amounts:['달걀 2개','빵 2장','상추 2~3장'],items:[{menuId:'fresh-eggs',quantity:1},{menuId:'fresh-bread',quantity:1},{menuId:'fresh-lettuce',quantity:1}],pantry:'소금·후추 등 기본 양념은 집에 있는 재료를 사용해요.',steps:['상추를 한 장씩 씻고 물기를 충분히 털어요. 키친타월로 한 번 더 닦으면 빵이 눅눅해지지 않아요.','달걀 2개를 풀어 소금과 후추로 간해요. 중약불의 팬에 식용유를 조금 두르고 속까지 완전히 익혀요.','빵 2장을 마른 팬에 앞뒤로 살짝 구워요. 구운 빵은 잠시 식혀 수증기를 날려주세요.','빵 위에 상추와 달걀을 차례로 올려요. 집에 소스가 있다면 취향에 맞춰 소량 더해요.','나머지 빵을 덮고 살짝 눌러 고정해요. 반으로 잘라 접시에 담고 남은 재료는 따로 보관해요.'],stepTitles:['채소 준비','달걀 익히기','빵 굽기','차곡차곡 쌓기','잘라서 마무리'],tips:'채소와 달걀의 물기·열기를 조금 빼고 쌓으면 먹기 편해요.',note:'재료 포장 단위 기준의 장바구니 가격이에요.'}
];
export const HEALTHY_MENU_IDS=['salmon','salad-poke','soy-bowl'];
const VEGETABLE_MENUS=new Set(['bibimbap','salmon','salad-poke','soy-bowl']);
export function recipeQuote(recipe,catalog,coupons,date){const items=recipe.items.map(l=>{const m=catalog.find(m=>m.id===l.menuId);return {...l,unitPrice:m.price};});return quoteCoupon(coupons.find(c=>c.id===recipe.couponId),{shopId:recipe.shopId,service:'shopping',items,date});}
export function calendarReportWindow({month,selectedDate,view}){
 if(view==='week'){
  const d=new Date(selectedDate+'T12:00:00Z'),start=dayOffset(selectedDate,-d.getUTCDay()),end=dayOffset(start,6);
  return {start,end,mode:'week',label:`${start.slice(5).replace('-','.')} — ${end.slice(5).replace('-','.')} 주간`};
 }
 const [year,m]=month.split('-').map(Number),end=new Date(Date.UTC(year,m,0)).toISOString().slice(0,10);
 return {start:month+'-01',end,mode:'month',label:`${year}년 ${m}월 월간`};
}
export function reportWindow(endDate,mode='week',startDate=null){
 const start=startDate||(mode==='month'?endDate.slice(0,7)+'-01':dayOffset(endDate,-6));let dates=[];for(let d=start;d<=endDate;d=dayOffset(d,1))dates.push(d);return {start,end:endDate,dates};
}
export function buildReport(state,{endDate,startDate=null,mode='week',shops=[]}={}){
 const window=reportWindow(endDate,mode,startDate),within=date=>date>=window.start&&date<=window.end;
 const completed=state.orders.filter(o=>o.status==='delivered'&&o.service!=='shopping'&&within(dateOf(o.placedAt)));
 const delivery=completed.filter(o=>o.fulfillment!=='pickup'),pickup=completed.filter(o=>o.fulfillment==='pickup');
 const byOrder=new Map(state.orders.map(o=>[o.id,o]));
 const records=state.records.filter(r=>{if(!r.confirmed||!within(r.date))return false;const o=byOrder.get(r.orderId);return !o||o.status==='delivered'&&o.service!=='shopping';});
 const sourceOf=r=>!r.orderId?'direct':!byOrder.has(r.orderId)?'unknown':byOrder.get(r.orderId).fulfillment==='pickup'?'pickup':'delivery';
 const sources={delivery:0,pickup:0,direct:0,unknown:0};records.forEach(r=>sources[sourceOf(r)]++);
 const totals={calories:0,carbs:0,protein:0,fat:0};records.forEach(r=>{for(const k in totals)totals[k]+=r.nutrition[k];});for(const k in totals)totals[k]=Math.round(totals[k]*10)/10;
 const days=window.dates.map(date=>{const rs=records.filter(r=>r.date===date);return {date,count:rs.length,calories:Math.round(rs.reduce((n,r)=>n+r.nutrition.calories,0)),delivery:rs.filter(r=>sourceOf(r)==='delivery').length,direct:rs.filter(r=>sourceOf(r)==='direct').length,pickup:rs.filter(r=>sourceOf(r)==='pickup').length};});
 const categories={};let vegetableMeals=0,knownMenuMeals=0;
 for(const r of records){const o=byOrder.get(r.orderId);const category=o?(shops.find(s=>s.id===o.shopId)?.category||'기타'):r.orderId?'연결 미확인':'직접 기록';categories[category]=(categories[category]||0)+1;if(o){knownMenuMeals++;if(o.items.some(i=>VEGETABLE_MENUS.has(i.menuId)))vegetableMeals++;}}
 const orderCategories={};delivery.forEach(o=>{const c=shops.find(s=>s.id===o.shopId)?.category||'기타';orderCategories[c]=(orderCategories[c]||0)+1;});
 const dominant=Object.entries(orderCategories).sort((a,b)=>b[1]-a[1])[0]||null;
 const deliveryDays=new Set(delivery.map(o=>dateOf(o.placedAt))).size,recordDays=days.filter(d=>d.count).length;
 const frequent=delivery.length>=Math.ceil(window.dates.length*4/7)&&deliveryDays>=3,concentrated=delivery.length>=3&&dominant&&dominant[1]/delivery.length>=.6;
 const pattern=frequent?'frequent-delivery':concentrated?'repeat-category':records.length<3||recordDays<2?'insufficient':'varied';
 const title=pattern==='frequent-delivery'?'배달이 잦았던 기간, 다음 한 끼는 다르게':pattern==='repeat-category'?'비슷한 메뉴가 이어졌어요':pattern==='insufficient'?'한 끼씩 모이면 패턴이 보여요':'나의 식사 선택을 돌아봐요';
 const evidence=pattern==='frequent-delivery'?`${window.dates.length}일 동안 완료한 배달 ${delivery.length}회 · 주문한 날 ${deliveryDays}일`:pattern==='repeat-category'?`완료한 배달 ${delivery.length}회 중 ${dominant[0]} ${dominant[1]}회`:pattern==='insufficient'?`확인한 식사 ${records.length}끼 · 기록한 날 ${recordDays}일`:`확인한 식사 ${records.length}끼 · ${Object.keys(categories).length}가지 기록 분류`;
 const knownSources=sources.delivery+sources.pickup+sources.direct;
 const macroEnergy={carbs:totals.carbs*4,protein:totals.protein*4,fat:totals.fat*9},energy=Object.values(macroEnergy).reduce((n,v)=>n+v,0);
 const macroKeys=['carbs','protein','fat'],macroShares=energy?Object.fromEntries(macroKeys.map(k=>[k,Math.floor(macroEnergy[k]/energy*100)])):null;
 if(macroShares){const remaining=100-Object.values(macroShares).reduce((n,v)=>n+v,0);macroKeys.sort((a,b)=>(macroEnergy[b]/energy*100-macroShares[b])-(macroEnergy[a]/energy*100-macroShares[a])).slice(0,remaining).forEach(k=>macroShares[k]++);}
 const menuMap=new Map();
 for(const o of delivery){for(const i of new Map(o.items.map(i=>[i.menuId,i])).values()){const row=menuMap.get(i.menuId)||{menuId:i.menuId,name:i.name||'주문 메뉴',kind:i.kind,count:0};row.count++;menuMap.set(i.menuId,row);}}
 const menuChoices=[...menuMap.values()].sort((a,b)=>b.count-a.count);
 const recentFoods=[...new Set([...records].sort((a,b)=>b.date.localeCompare(a.date)).map(r=>r.name||byOrder.get(r.orderId)?.items[0]?.name).filter(Boolean))].slice(0,3);
 const habits={deliveryShare:knownSources?Math.round(sources.delivery/knownSources*100):null,macroShares,dominantCategory:dominant?{name:dominant[0],share:Math.round(dominant[1]/delivery.length*100)}:null};
 return {window,completed:completed.length,delivery:delivery.length,pickup:pickup.length,deliveryDays,records:records.length,recordDays,missingDays:window.dates.length-recordDays,unconfirmedOrders:completed.filter(o=>!state.records.some(r=>r.orderId===o.id&&r.confirmed)).length,sources,totals,menuChoices,recentFoods,averageCalories:records.length?Math.round(totals.calories/records.length):null,days,categories,vegetableMeals,knownMenuMeals,pattern,title,evidence,habits};
}
// 2025 KDRIs, general adult energy distribution; applied only to confirmed meal records.
export const NUTRITION_REFERENCE={year:2025,source:'https://www.kns.or.kr/fileroom/fileroom_view.asp?BoardID=Kdr&idx=168',ranges:{carbs:[50,65],protein:[10,20],fat:[15,30]}};
const MACRO_LABELS={carbs:'탄수화물',protein:'단백질',fat:'지방'};
function macroProfile(n){
 if(!n||!['carbs','protein','fat'].every(k=>Number.isFinite(n[k])&&n[k]>=0))return null;
 const energy=n.carbs*4+n.protein*4+n.fat*9;if(!energy)return null;
 return Object.fromEntries(['carbs','protein','fat'].map(k=>[k,Math.round(n[k]*(k==='fat'?9:4)/energy*1000)/10]));
}
const macroDistance=shares=>Object.entries(NUTRITION_REFERENCE.ranges).reduce((sum,[key,[min,max]])=>sum+Math.max(min-shares[key],0,shares[key]-max),0);
export function nutritionBalance(report){
 const shares=report.records?macroProfile(report.totals):null;
 if(!shares)return {status:'unknown',shares:null,flags:[],primary:null,reference:NUTRITION_REFERENCE};
 const flags=Object.entries(NUTRITION_REFERENCE.ranges).flatMap(([key,[min,max]])=>shares[key]<min?[{key,label:MACRO_LABELS[key],direction:'low',share:shares[key],min,max,gap:min-shares[key]}]:shares[key]>max?[{key,label:MACRO_LABELS[key],direction:'high',share:shares[key],min,max,gap:shares[key]-max}]:[]).sort((a,b)=>b.gap-a.gap);
 return {status:flags.length?'adjust':'balanced',shares,flags,primary:flags[0]||null,reference:NUTRITION_REFERENCE};
}
export function mealSuggestions(report,catalog=[],shops=[]){
 const balance=nutritionBalance(report),{shares,primary}=balance;
 if(!shares)return [{tone:'neutral',label:'한 끼의 영양정보부터 확인해요',title:'먹은 양을 확인하면<br>영양 균형을 살펴볼 수 있어요',evidence:'아직 확인한 영양정보가 없어요.',reason:'먹은 양을 남기면 다음 한 끼를 제안해요.',target:'record',name:'내 식사의 영양정보 확인',action:'먹은 한 끼 기록하기'}];
 const evidence=`탄수화물 ${shares.carbs}% · 단백질 ${shares.protein}% · 지방 ${shares.fat}%`;
 const allLowProtein=balance.flags.some(f=>f.key==='protein'&&f.direction==='low'),highCarbs=balance.flags.some(f=>f.key==='carbs'&&f.direction==='high'),highProtein=balance.flags.some(f=>f.key==='protein'&&f.direction==='high');
 const actions={
  'carbs-high':{title:'밥·면의 비중을 조절하고,<br>단백질 반찬과 채소를 함께',reason:allLowProtein?'밥·면은 줄이고, 달걀·두부·생선 반찬을 곁들여요.':'밥·면의 양을 조절하고, 반찬·채소를 함께 담아요.'},
  'protein-low':{title:'다음 한 끼엔 단백질 반찬을<br>함께 챙겨볼까요?',reason:'달걀·두부·생선 중 한 가지를 밥과 함께 골라요.'},
  'fat-high':{title:'기름·소스의 양을 조절해<br>한 끼의 구성을 맞춰봐요',reason:'튀김·소스는 조절하고, 곡류·반찬·채소를 고루 담아요.'},
  'protein-high':{title:'단백질만 더하기보다,<br>곡류와 채소도 함께 챙겨요',reason:'단백질 반찬은 조절하고, 곡류·채소도 함께 챙겨요.'},
  'carbs-low':{title:'곡류도 적당히 곁들여<br>탄단지 구성을 맞춰봐요',reason:'밥·통곡물을 곁들이고, 반찬·채소도 함께 챙겨요.'},
  'fat-low':{title:'견과류나 식물성 기름도<br>적당량 곁들여봐요',reason:'견과류·식물성 기름을 적당량 곁들여 구성을 맞춰요.'}
 };
 const action=primary?actions[primary.key+'-'+primary.direction]:{title:'탄단지 구성,<br>참고 범위 안이에요',reason:'현재의 구성을 이어가며, 곡류·반찬·채소를 고루 챙겨요.'};
 const common={tone:primary?'change':'positive',label:primary?`${primary.label} 비중 ${primary.direction==='high'?'조절':'보완'}`:'탄단지 구성 유지',title:action.title,evidence,recordLabel:`기록한 ${report.records}끼의 영양 구성`,metric:primary?{value:primary.share,unit:'%',label:`${primary.label} 비중 · 참고 ${primary.min}~${primary.max}%`}:{value:shares.carbs,unit:'%',label:'탄수화물 비중 · 참고 50~65%'},balanceStatus:balance.status};
 const baseline=macroDistance(shares),ordered=new Set((report.menuChoices||[]).map(m=>m.menuId));
 const candidates=catalog.filter(m=>m.service!=='shopping'&&m.name&&macroProfile(m.nutrition)&&(!shops.length||shops.some(s=>s.id===m.shopId&&s.open))).map(m=>{
  const after=macroProfile(Object.fromEntries(['carbs','protein','fat'].map(k=>[k,report.totals[k]+m.nutrition[k]]))),own=macroProfile(m.nutrition);
  const distance=macroDistance(after),ownDistance=macroDistance(own);
  const gap=primary?Math.max(primary.min-after[primary.key],0,after[primary.key]-primary.max):0;
  return {menu:m,distance,ownDistance,gap,seen:ordered.has(m.id)};
 }).filter(x=>x.ownDistance===0&&(primary?x.distance<baseline-.05&&x.gap<primary.gap:x.distance===0)).sort((a,b)=>a.distance-b.distance||a.ownDistance-b.ownDistance||Number(a.seen)-Number(b.seen));
 const best=candidates[0],cards=[];
 if(best){const m=best.menu;cards.push({...common,reason:action.reason,target:'menu',menuId:m.id,name:m.name,kind:m.kind,action:primary?'구성을 보완할 메뉴 보기':'균형을 이어갈 메뉴 보기',menuNutrition:m.nutrition});}
 if((allLowProtein||highCarbs||!primary)&&!highProtein){cards.push({...common,tone:'fresh',label:'집밥으로 균형 챙기기',title:highCarbs?'밥은 조금 줄이고,<br>달걀·채소를 함께':'달걀·채소로<br>간단한 집밥 한 끼',metric:{value:shares.protein,unit:'%',label:'단백질 비중 · 참고 10~20%'},evidence:highCarbs?'밥 반 공기와 달걀 2개로 준비해요.':allLowProtein?'달걀 2개로 단백질 식품을 곁들여요.':'밥·달걀·채소를 함께 챙겨요.',reason:highCarbs?'달걀 2개를 넣고, 기름·양념은 계량해요.':allLowProtein?'단백질 식품과 채소를 한 그릇에 담아요.':'먹을 양을 정하고 기름·양념은 계량해요.',target:'recipe',recipeId:'pb-rice',name:'달걀 채소 볶음밥',kind:'bowl',action:'영양 구성을 생각한 레시피 보기',recipeAdjustment:highCarbs?{rice:'밥 반 공기',stepsNeedRiceHalf:true}:null});}
 if(!cards.length){cards.push({...common,reason:action.reason,target:'record',name:'먹은 양과 영양정보 확인',action:'기록한 한 끼 확인하기'});}
 // Explicit grocery option; unknown product nutrients never enter the macro ranking above.
 const gukbap=catalog.find(p=>p.id==='baemin-easy-pork-gukbap'&&p.service==='shopping');
 if(gukbap&&(!shops.length||shops.some(s=>s.id===gukbap.shopId&&s.open)))cards.push({tone:'neutral',label:'배민이지 간편식 제안',title:'바쁜 날엔 간편하게,<br>배민이지 국밥 한 끼',recordLabel:'간편식 한 팩',metric:{value:Number.parseFloat(gukbap.unit),unit:gukbap.unit.replace(/[\d.\s]/g,''),label:'판매 용량 · 한 끼 분량과 달라요'},evidence:highCarbs?'밥은 조절하고, 채소 반찬을 곁들여요.':'밥·채소 반찬을 함께 준비해요.',reason:'먹을 만큼 덜어 드세요. 영양성분은 미확인이에요.',target:'product',productId:gukbap.id,name:'부산식 돼지수육국밥',kind:gukbap.kind,action:'배민이지 상품 보기',nutritionStatus:gukbap.nutritionStatus});
 return cards;
}
export function mealSuggestion(report,catalog=[],shops=[]){return mealSuggestions(report,catalog,shops)[0];}
export function demoReportState(base,endDate){
 const menuRows=[['crispy-original','fried','치킨',1750],['pizza-pepperoni','pizza','피자',1590],['crispy-original','fried','치킨',1750],['burger-classic','burger','패스트푸드',920],['pizza-cheese','pizza','피자',1480]];
 const orders=[],records=[];menuRows.forEach(([menuId,kind,category,calories],i)=>{const date=dayOffset(endDate,-6+i),id='report-example-'+i;orders.push({id,shopId:'example-'+category,status:'delivered',service:'delivery',fulfillment:'delivery',placedAt:date+'T18:00:00+09:00',items:[{menuId,kind}]});records.push({id:'record-'+id,orderId:id,date,confirmed:true,nutrition:{calories,carbs:100,protein:40,fat:40}});});
 return {state:{...base,orders,records},shops:[{id:'example-치킨',category:'치킨'},{id:'example-피자',category:'피자'},{id:'example-패스트푸드',category:'패스트푸드'}]};
}

export function baeminEasySelection(report,catalog,{suggestion=null,relatedOnly=false}={}){
 if(relatedOnly){
  // Match known ingredients, never infer nutrient amounts from a product name.
  const ids=suggestion?.target==='product'?[suggestion.productId]:suggestion?.target==='recipe'?RECIPES.find(r=>r.id===suggestion.recipeId)?.items.map(i=>i.menuId)||[]:suggestion?.menuId==='soy-bowl'?['baemin-easy-tofu']:[];
  const products=catalog.filter(p=>p.brand==='배민이지'&&p.service==='shopping'&&ids.includes(p.id));
  return {title:suggestion?.target==='product'?'국밥 한 끼 준비,<br>배민이지로 간편하게':`${suggestion?.name||'추천 메뉴'}에 맞춘<br>배민이지 재료`,reason:suggestion?.target==='product'?'위에서 제안한 국밥이에요. 밥과 채소 반찬을 곁들여 준비해 보세요.':'위에서 추천한 메뉴에 들어가는 재료예요. 다른 재료와 먹을 양도 함께 살펴보세요.',products};
 }
 const products=catalog.filter(p=>p.brand==='배민이지'&&p.service==='shopping').sort((a,b)=>(a.featuredOrder||99)-(b.featuredOrder||99));
 return {title:'B마트에서 만난 배민이지,<br>한 끼 준비를 간편하게',reason:'우유부터 냉동 국·탕까지, 식사 구성과 먹을 양에 맞춰 골라보세요.',products};
}
