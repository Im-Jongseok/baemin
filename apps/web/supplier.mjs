/** Proposed Baemin/merchant nutrition contract, NOT a discovered public API. */
export function normalizeSupplierNutrition(feed,{menuId,menuVersion}={}) {
  if(!feed || typeof feed!=='object')throw new Error('공급 영양 데이터가 없어요.');
  if(menuId && feed.menuId!==menuId)throw new Error('메뉴 식별자가 일치하지 않아요.');
  if(menuVersion && feed.menuVersion!==menuVersion)throw new Error('메뉴 버전이 일치하지 않아요.');
  if(!feed.menuId||!feed.menuVersion||!feed.sourceId||!['supplier','fixture'].includes(feed.origin))throw new Error('영양 데이터의 버전·출처가 필요해요.');
  const source={type:feed.origin==='fixture'?'baemin-fixture':'baemin-supplier',sourceId:feed.sourceId,version:feed.menuVersion,retrievedAt:feed.retrievedAt||null};
  if(feed.nutrients===null)return {nutrition:null,source,status:'unavailable'};
  if(!['per_serving','per_100g'].includes(feed.basis))throw new Error('영양값 기준 단위를 확인해 주세요.');
  const units={calories:'kcal',carbs:'g',protein:'g',fat:'g'},values={};
  for(const [key,unit] of Object.entries(units)){
    const entry=feed.nutrients?.[key];
    if(!entry||entry.unit!==unit||typeof entry.value!=='number'||!Number.isFinite(entry.value)||entry.value<0)throw new Error('영양값의 단위·숫자를 확인해 주세요.');
    values[key]=entry.value;
  }
  const multiplier=feed.basis==='per_100g'?feed.servingGrams/100:1;
  if(typeof multiplier!=='number'||!Number.isFinite(multiplier)||multiplier<=0||multiplier>50)throw new Error('100g 기준 데이터에는 제공량(g)이 필요해요.');
  const nutrition=Object.fromEntries(Object.entries(values).map(([k,v])=>[k,Math.round(v*multiplier*10)/10]));
  if(nutrition.calories>20000||['carbs','protein','fat'].some(k=>nutrition[k]>3000))throw new Error('영양값 범위를 확인해 주세요.');
  return {nutrition,source,status:'available'};
}
