// Explicit refresh only: the original web project is read, never written.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {SHOPS,MENUS,initialState} from '../../web/domain.mjs';
import {PRODUCTS,CATEGORIES,MARKET_CATEGORIES} from '../../web/catalog.mjs';
import {RECIPES,NUTRITION_REFERENCE} from '../../web/insights.mjs';
const root=path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const seed={shops:SHOPS,menus:MENUS,products:PRODUCTS,categories:CATEGORIES,marketCategories:MARKET_CATEGORIES,recipes:RECIPES,nutritionReference:NUTRITION_REFERENCE,state:initialState()};
const updates=JSON.parse(fs.readFileSync(path.join(root,'data/catalog-updates.json'),'utf8'));
for(const kind of ['shops','menus','products']) {
  const additions=kind==='shops'?updates.shopAdditions:kind==='menus'?updates.menuAdditions:[];
  const ids=new Set(additions.map(x=>x.id));
  seed[kind]=[...additions.filter(x=>!x.brand),...seed[kind].filter(x=>!ids.has(x.id)).map(x=>({...x,...updates.itemUpdates.find(p=>p.id===x.id)})),...additions.filter(x=>x.brand)];
}
seed.nutritionRevision=updates.nutritionRevision;
fs.writeFileSync(path.join(root,'assets/seed.json'),JSON.stringify(seed,null,2));
console.log('Updated Flutter seed with curated catalog additions. Existing app preferences and original web files were not changed.');
