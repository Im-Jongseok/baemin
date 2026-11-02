// Local catalog. Most prices/nutrition are fixtures; priceSource identifies observed display prices. No live Baemin API.
export const EXTRA_SHOPS=[
 {id:'crispy-chicken',name:'바삭한 치킨 연구소',category:'치킨',rating:4.9,minOrder:17000,open:true,eta:'25~40분'},
 {id:'pizza-club',name:'피자클럽',category:'피자',rating:4.8,minOrder:16000,open:true,eta:'30~45분'},
 {id:'burger-room',name:'버거룸',category:'패스트푸드',rating:4.9,minOrder:8000,open:true,eta:'20~30분'},
 {id:'snack-lab',name:'오늘의 분식',category:'분식',rating:4.8,minOrder:8000,open:true,eta:'20~35분'},
 {id:'rice-table',name:'한상 가득',category:'찜·탕',rating:4.9,minOrder:9000,open:true,eta:'25~40분'},
 {id:'sushi-table',name:'정성 초밥',category:'돈까스·회',rating:4.9,minOrder:12000,open:true,eta:'30~45분'},
 {id:'cafe-day',name:'카페 오롯',category:'카페·디저트',rating:4.8,minOrder:6000,open:true,eta:'15~25분'},
 {id:'bmart',name:'B마트',category:'마트',service:'shopping',rating:4.9,minOrder:0,open:true,eta:'약 25분'},
 {id:'cu-market',name:'CU 우리동네점',category:'편의점',service:'shopping',rating:4.8,minOrder:0,open:true,eta:'약 30분'},
 {id:'gs-market',name:'GS25 한끼점',category:'편의점',service:'shopping',rating:4.9,minOrder:0,open:true,eta:'약 25분'},
 {id:'fresh-market',name:'싱싱한 동네마트',category:'마트',service:'shopping',rating:4.8,minOrder:0,open:true,eta:'약 40분'}
];
const food=(id,shopId,name,price,kind,calories,carbs,protein,fat,description)=>({id,shopId,name,price,kind,nutrition:{calories,carbs,protein,fat},description});
export const EXTRA_MENUS=[
 food('salad-poke','mint-kitchen','연어 샐러드 포케',12500,'salmon',480,35,30,22,'채소를 곁들여 골라보는 샐러드 포케'),
 food('soy-bowl','mint-kitchen','두부 버섯 덮밥',10500,'bowl',510,70,25,16,'고소한 두부와 버섯을 듬뿍 올린 한 그릇'),
 food('spicy-noodles','noodle-house','매콤 비빔국수',9500,'noodles',560,91,17,11,'새콤달콤한 양념과 아삭한 채소'),
 food('warm-noodles','noodle-house','진한 멸치국수',9500,'noodles',470,80,17,8,'따뜻한 멸치 육수로 속 편한 한 끼'),
 food('crispy-original','crispy-chicken','황금 후라이드 치킨',19000,'fried',1750,85,110,108,'바삭한 튀김옷과 촉촉한 속살'),
 food('crispy-boneless','crispy-chicken','순살 후라이드',21000,'fried',1820,97,106,116,'먹기 편한 순살로 즐기는 바삭한 치킨'),
 food('crispy-half','crispy-chicken','반반 치킨',22000,'fried',1910,124,104,114,'함께 나눠 먹기 좋은 인기 메뉴'),
 food('pizza-pepperoni','pizza-club','페퍼로니 피자',18900,'pizza',1590,162,62,74,'페퍼로니와 치즈를 가득 올렸어요'),
 food('pizza-cheese','pizza-club','더블 치즈 피자',16900,'pizza',1480,156,67,66,'진한 치즈를 두 배로 즐겨요'),
 food('pizza-set','pizza-club','피자 한 판 세트',23900,'pizza',1840,202,71,82,'함께 먹기 좋은 든든한 피자 세트'),
 food('burger-classic','burger-room','클래식 치즈버거 세트',10900,'burger',920,103,34,42,'치즈버거와 감자튀김, 음료까지'),
 food('burger-double','burger-room','더블 패티 버거',11900,'burger',810,53,48,43,'두툼한 패티 두 장을 올린 버거'),
 food('burger-chicken','burger-room','크리스피 치킨버거',8900,'burger',650,61,30,32,'바삭한 치킨 패티와 신선한 채소'),
 food('tteokbokki','snack-lab','국물 떡볶이',8900,'tteok',720,137,15,12,'매콤달콤한 국물과 쫄깃한 떡'),
 food('tteok-set','snack-lab','떡볶이와 튀김 세트',13900,'tteok',1120,168,24,40,'떡볶이에 바삭한 튀김을 곁들여요'),
 food('kimchi-stew','rice-table','돼지고기 김치찌개',10500,'stew',670,69,35,29,'푹 익은 김치와 돼지고기, 공깃밥 포함'),
 food('soy-stew','rice-table','구수한 된장찌개',9500,'stew',550,71,25,18,'채소와 두부를 넣은 따뜻한 한 상'),
 food('pork-cutlet','sushi-table','등심 돈까스 정식',12500,'cutlet',870,97,39,38,'바삭한 등심 돈까스와 밥, 샐러드'),
 food('salmon-sushi','sushi-table','생연어 초밥 10피스',16900,'sushi',690,89,38,20,'부드러운 생연어를 올린 초밥 한 접시'),
 food('sushi-combo','sushi-table','모둠 초밥 12피스',18900,'sushi',760,102,42,21,'다채로운 맛을 담은 모둠 초밥'),
 food('coffee-cake','cafe-day','라떼와 티라미수 세트',10900,'coffee',540,61,12,28,'고소한 라떼와 부드러운 티라미수'),
 food('croissant-set','cafe-day','크루아상 브런치',8900,'bread',480,49,10,27,'겹겹이 바삭한 크루아상과 커피'),
 food('tiramisu','cafe-day','티라미수 2개 세트',12000,'coffee',650,71,12,36,'달콤한 디저트를 나누는 시간')
];
const product=(id,shopId,name,price,kind,category,unit,calories,carbs,protein,fat)=>({...food(id,shopId,name,price,kind,calories,carbs,protein,fat,''),category,unit,service:'shopping'});
export const PRODUCTS=[
 {...product('pb-eggs','bmart','PB 신선란',4490,'eggs','우유·계란','10구',700,4,63,48),pb:true,fixtureLabel:'PB 시연 상품'},
 {...product('pb-vegetables','bmart','PB 볶음밥용 다짐 채소',2990,'lettuce','과일·채소','250g',65,12,4,1),image:'/assets/chopped-vegetables.png',pb:true,fixtureLabel:'PB 시연 상품'},
 product('fresh-eggs','fresh-market','우리동네 신선란',4980,'eggs','우유·계란','10구',700,4,63,48),
 product('fresh-bread','fresh-market','샌드위치용 빵',3980,'bread','빵·간식','1봉',780,84,15,45),
 product('apple','bmart','아삭한 사과',6900,'apple','과일·채소','3입',285,75,1,1),
 product('strawberry','bmart','한입 딸기',9900,'berry','과일·채소','500g',160,38,3,1),
 {id:'milk',shopId:'bmart',name:'[배민이지] 갓 짜낸 1급A 우유',price:1990,listPrice:2290,discountPercent:13,kind:'milk',image:'/assets/captured/easy-milk-observed.png',category:'우유·계란',unit:'900mL',service:'shopping',brand:'배민이지',pb:true,nutrition:null,nutritionStatus:'not-provided',priceSource:'mirroring-observed',observedAt:'2026-10-26',storage:'냉장',lowestPriceChallenge:true,featuredOrder:1,productSource:'E05-milk-detail'},
 {id:'baemin-easy-sundae',shopId:'bmart',name:'[냉동][배민이지] 순대많이 얼큰 순대국',price:5490,kind:'stew',image:'/assets/captured/easy-sundae-observed.png',category:'라면·간편식',unit:'700g',service:'shopping',brand:'배민이지',pb:true,nutrition:null,nutritionStatus:'not-provided',priceSource:'mirroring-observed',observedAt:'2026-10-26',storage:'냉동',lowestPriceChallenge:true,featuredOrder:2,productSource:'E01-search; E02-sundae-detail'},
 {id:'baemin-easy-pork-gukbap',shopId:'bmart',name:'[냉동][배민이지] 부산식 돼지수육국밥',price:5460,kind:'stew',image:'/assets/captured/easy-pork-gukbap-observed.png',category:'라면·간편식',unit:'700g',service:'shopping',brand:'배민이지',pb:true,nutrition:null,nutritionStatus:'not-provided',priceSource:'mirroring-observed',observedAt:'2026-10-26',storage:'냉동',lowestPriceChallenge:true,featuredOrder:3,productSource:'E01-search'},
 {id:'baemin-easy-tofu',shopId:'bmart',name:'[배민이지] 찌개와 부침 겸용 만능 두부',price:1980,kind:'tofu',image:'/assets/baemin-easy-tofu.png',category:'우유·계란',unit:'300g',service:'shopping',brand:'배민이지',pb:true,nutrition:null,nutritionStatus:'not-provided',priceSource:'fixture',productSource:'https://www.ceoscoredaily.com/page/view/2026082013455095015'},
 product('eggs','bmart','신선란',4980,'eggs','우유·계란','10구',700,4,63,48),
 product('lettuce','bmart','무농약 상추',2480,'lettuce','과일·채소','150g',23,4,2,0.3),
 product('pork','bmart','국내산 삼겹살',12900,'pork','정육·수산','400g',1320,0,68,116),
 product('ramyeon','bmart','얼큰한 라면 멀티팩',3980,'ramyeon','라면·간편식','5입',2500,390,50,85),
 product('bread','bmart','버터 크루아상',4980,'bread','빵·간식','3입',780,84,15,45),
 product('cu-milk','cu-market','고소한 우유',2900,'milk','우유·계란','900mL',576,43,29,32),
 product('cu-ramyeon','cu-market','출출할 땐 라면',1600,'ramyeon','라면·간편식','1입',500,78,10,17),
 product('gs-bread','gs-market','바삭한 크루아상',2200,'bread','빵·간식','1입',260,28,5,15),
 product('gs-eggs','gs-market','신선한 계란',5400,'eggs','우유·계란','10구',700,4,63,48),
 product('fresh-apple','fresh-market','가정용 사과',7900,'apple','과일·채소','4입',380,100,1,1),
 product('fresh-lettuce','fresh-market','오늘 수확한 상추',1980,'lettuce','과일·채소','150g',23,4,2,0.3),
 product('fresh-pork','fresh-market','도톰한 삼겹살',14900,'pork','정육·수산','500g',1650,0,85,145),
 product('gs-berry','gs-market','달콤한 딸기',8900,'berry','과일·채소','400g',128,30,2,1)
];
export const PB_PRODUCT_IDS=PRODUCTS.filter(p=>p.pb).map(p=>p.id);
export const CATEGORIES=[['전체','🍽️'],['치킨','🍗'],['카페·디저트','🧋'],['피자','🍕'],['찜·탕','🍲'],['돈까스·회','🍣'],['한식','🍚'],['면요리','🍜'],['패스트푸드','🍔'],['분식','🍢']];
export const MARKET_CATEGORIES=['전체','배민이지','과일·채소','우유·계란','정육·수산','라면·간편식','빵·간식'];
export function addCart(cart,item,quantity=1){
 if(!item||!Number.isInteger(quantity)||quantity<1||quantity>10)throw new Error('담을 수량을 확인해 주세요.');
 if(cart?.lines?.length&&cart.shopId!==item.shopId)throw new Error('다른 가게의 장바구니가 있어요.');
 const next=structuredClone(cart||{shopId:item.shopId,lines:[]}),existing=next.lines.find(l=>l.menuId===item.id);
 if(existing){if(existing.quantity+quantity>10)throw new Error('한 메뉴는 10개까지 담을 수 있어요.');existing.quantity+=quantity;}
 else next.lines.push({menuId:item.id,quantity});return next;
}
export function cartTotal(cart,catalog){return (cart?.lines||[]).reduce((sum,line)=>sum+(catalog.find(m=>m.id===line.menuId)?.price||0)*line.quantity,0);}
