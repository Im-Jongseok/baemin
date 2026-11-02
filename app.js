'use strict';
const $=s=>document.querySelector(s), $$=s=>document.querySelectorAll(s);
const key='hankkirok-meals-v1';
const photo=id=>id.startsWith("https://")?id:`https://images.unsplash.com/${id}?auto=format&fit=crop&w=400&q=80`;
const foods=[
 ['후라이드 치킨','동네 치킨집 · 예시',920,46,58,56,'https://www.tastingtable.com/img/gallery/why-the-size-of-your-fried-chicken-matters/l-intro-1660570176.jpg'],
 ['마르게리타 피자','우리동네 피자 · 예시',860,102,34,36,'photo-1579751626657-72bc17010498'],
 ['수제 치즈버거','동네 버거집 · 예시',780,68,35,41,'photo-1568901346375-23c9450c58cd'],
 ['소고기 쌀국수','쌀국수 한 그릇 · 예시',620,82,32,18,'https://www.phomein.com/upload/product/20251111/20251111134119459063.png'],
 ['소고기 마라탕','오늘의 마라탕 · 예시',850,65,40,48,'https://www.sweetcakeparis.fr/images/thumbs/0001393_-malatangepice_510.jpeg']
];
const localDate=d=>`${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
const parse=s=>new Date(s+'T12:00:00');
const now=new Date();let selected=localDate(now),month=new Date(now.getFullYear(),now.getMonth(),1),period='week',uploaded='',meals=[];
const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function seed(){let data=[];const last=now.getDate();for(let day=1;day<=last;day++){if(day%6===0)continue;const count=day%3===0?3:2;for(let n=0;n<count;n++){const f=foods[(day+n*3)%foods.length];data.push({id:`demo-${day}-${n}`,date:localDate(new Date(now.getFullYear(),now.getMonth(),day)),type:count===3?['아침','점심','저녁'][n]:['점심','저녁'][n],name:f[0],restaurant:f[1],calories:f[2],carbs:f[3],protein:f[4],fat:f[5],image:photo(f[6]),demo:true});}}return data;}
try{const saved=localStorage.getItem(key);meals=saved?JSON.parse(saved):seed();if(!Array.isArray(meals)||!meals.every(m=>m&&typeof m.date==='string'&&['calories','carbs','protein','fat'].every(k=>Number.isFinite(m[k])&&m[k]>=0)))throw Error();}catch{meals=seed();}
// Refresh only sample meals; preserve all user-entered records and deleted samples.
meals=meals.map(m=>{
 if(!m.demo)return m;
 const match=String(m.id).match(/^demo-(\d+)-(\d+)$/);
 const f=foods[match?(Number(match[1])+Number(match[2])*3)%foods.length:0];
 return {...m,name:f[0],restaurant:f[1],calories:f[2],carbs:f[3],protein:f[4],fat:f[5],image:photo(f[6])};
});

const sum=(list,k)=>list.reduce((s,m)=>s+Number(m[k]||0),0);const num=n=>Math.round(n).toLocaleString('ko-KR');
function save(next){try{localStorage.setItem(key,JSON.stringify(next));meals=next;return true;}catch{$('#form-error').textContent='저장 공간이 부족하거나 브라우저 저장이 차단되어 있습니다. 더 작은 사진으로 다시 시도해 주세요.';return false;}}
function datesInRange(){const d=parse(selected);let start,end;if(period==='week'){start=new Date(d);start.setDate(d.getDate()-(d.getDay()+6)%7);end=new Date(start);end.setDate(start.getDate()+6);}else{start=new Date(d.getFullYear(),d.getMonth(),1);end=new Date(d.getFullYear(),d.getMonth()+1,0);}return {start,end,list:meals.filter(m=>m.date>=localDate(start)&&m.date<=localDate(end))};}
function render(){renderCalendar();renderDaily();renderReport();const monthList=meals.filter(m=>m.date.startsWith(localDate(month).slice(0,7)));const days=new Set(monthList.map(m=>m.date)).size;const protein=sum(monthList,'protein');$('#stats').innerHTML=[['기록한 식사',monthList.length,'끼','✎','이번 달, 차곡차곡 쌓인 한 끼'],['기록일 평균 칼로리',days?sum(monthList,'calories')/days:0,'kcal','♨','기록이 있는 날짜만 계산했어요'],['기록일 평균 단백질',days?protein/days:0,'g','◈','기록한 식사의 단백질 합계 기준'],['이번 달 기록 일수',days,'일','▦','<b>나를 알아가는 습관</b>을 만들고 있어요']].map(s=>`<article class="stat"><span class="stat-label">${s[0]}</span><span class="stat-icon">${s[3]}</span><strong>${num(s[1])}<small>${s[2]}</small></strong><p>${s[4]}</p></article>`).join('');$('.demo').innerHTML=meals.some(m=>m.demo)?'<i></i> 예시 데이터 포함 · 직접 기록도 가능':'<i></i> 나의 식사 기록';}
const slidePositions = new Map();
let calendarExpanded=false;
function weekOfMonth(date){return Math.ceil(date.getDate()/7);}
function renderCalendar(){
  $('#month-title').textContent=calendarExpanded?`${month.getMonth()+1}월`:`${parse(selected).getMonth()+1}월 ${weekOfMonth(parse(selected))}주차`;
  const start=new Date(month);start.setDate(1-month.getDay());
  const count=Math.ceil((month.getDay()+new Date(month.getFullYear(),month.getMonth()+1,0).getDate())/7)*7;
  let html='';
  for(let i=0;i<count;i++){
    const d=new Date(start);d.setDate(start.getDate()+i);
    const date=localDate(d),list=meals.filter(m=>m.date===date),index=Math.min(slidePositions.get(date)||0,Math.max(0,list.length-1));
    slidePositions.set(date,index);
    html+=`<div class="day ${list.length?'has-photo':''} ${d.getMonth()!==month.getMonth()?'other':''} ${date===selected?'selected':''} ${date===localDate(now)?'is-today':''}" data-day="${date}">
      ${list.length?`<div class="day-photos"><div class="photo-track" style="transform:translateX(-${index*100}%)">${list.map(m=>`<img src="${esc(m.image)}" alt="${esc(m.name)}" loading="lazy" draggable="false">`).join('')}</div></div>`:''}
      <button class="day-select" data-date="${date}" aria-label="${d.getMonth()+1}월 ${d.getDate()}일, 식사 ${list.length}개" aria-pressed="${date===selected}"><span class="day-number">${d.getDate()}</span>${list.length?`<span class="day-cal">${num(sum(list,'calories'))}<small>kcal</small></span>`:''}</button>
      ${list.length>1?`<ul class="slick-dots" aria-label="${d.getMonth()+1}월 ${d.getDate()}일 음식 사진 선택">${list.map((m,n)=>`<li class="${n===index?'slick-active':''}"><button type="button" data-slide="${n}" aria-label="${d.getMonth()+1}월 ${d.getDate()}일 ${n+1}번째 음식 사진" aria-pressed="${n===index}">${n+1}</button></li>`).join('')}</ul>`:''}
    </div>`;
  }
  $('#calendar').innerHTML=html;
  const anchor=parse(selected);
  const weekStart=new Date(anchor);weekStart.setDate(anchor.getDate()-anchor.getDay());
  const weekEnd=new Date(weekStart);weekEnd.setDate(weekStart.getDate()+6);
  $$('[data-day]').forEach(cell=>{cell.hidden=!calendarExpanded&&(cell.dataset.day<localDate(weekStart)||cell.dataset.day>localDate(weekEnd));});
  let toggle=$('#calendar-toggle');
  if(!toggle){toggle=document.createElement('button');toggle.id='calendar-toggle';toggle.type='button';toggle.setAttribute('aria-controls','calendar');$('#calendar').after(toggle);}
  toggle.textContent=calendarExpanded?'주간으로 접기 ⌃':'전체 월 보기 ⌄';
  toggle.setAttribute('aria-expanded',String(calendarExpanded));
  toggle.onclick=()=>{calendarExpanded=!calendarExpanded;render();};
  $$('[data-day]').forEach(cell=>{
    const date=cell.dataset.day,total=meals.filter(m=>m.date===date).length;
    let swipeStart=null,suppressClick=false;
    function move(step){
      if(total<2)return;
      const index=((slidePositions.get(date)||0)+step+total)%total;
      slidePositions.set(date,index);
      cell.querySelector('.photo-track').style.transform=`translateX(-${index*100}%)`;
      cell.querySelectorAll('[data-slide]').forEach(b=>{const active=Number(b.dataset.slide)===index;b.parentElement.classList.toggle('slick-active',active);b.setAttribute('aria-pressed',String(active));});
    }
    cell.querySelectorAll('[data-slide]').forEach(b=>b.onclick=()=>move(Number(b.dataset.slide)-(slidePositions.get(date)||0)));
    const select=cell.querySelector('.day-select');
    select.onclick=()=>{if(suppressClick){suppressClick=false;return;}selected=date;month=new Date(parse(selected).getFullYear(),parse(selected).getMonth(),1);render();};
    select.onkeydown=e=>{if(['ArrowLeft','ArrowRight'].includes(e.key)){e.preventDefault();e.stopPropagation();if(!calendarExpanded)moveWeek(e.key==='ArrowRight'?1:-1);else if(total>1)move(e.key==='ArrowRight'?1:-1);}};
    select.addEventListener('pointerdown',e=>{suppressClick=false;swipeStart={x:e.clientX,y:e.clientY};select.setPointerCapture(e.pointerId);});
    select.addEventListener('pointerup',e=>{
      if(!swipeStart)return;
      const dx=e.clientX-swipeStart.x,dy=e.clientY-swipeStart.y;swipeStart=null;
      if(Math.abs(dx)>30&&Math.abs(dx)>Math.abs(dy)){suppressClick=true;e.preventDefault();if(!calendarExpanded)moveWeek(dx<0?1:-1);else if(total>1)move(dx<0?1:-1);}
    });
    select.addEventListener('pointercancel',()=>{swipeStart=null;});
  });
  fallbackImages();
}

const placeholder='data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="200" height="160"><rect width="200" height="160" fill="#e5f0e6"/><circle cx="100" cy="80" r="48" fill="#fff"/><circle cx="100" cy="80" r="33" fill="#bdd8b1"/><ellipse cx="93" cy="78" rx="23" ry="16" fill="#efb275"/><circle cx="118" cy="66" r="10" fill="#91b77d"/></svg>');
function fallbackImages(){$$('img').forEach(img=>{img.onerror=()=>{img.onerror=null;img.src=placeholder;};});}
function renderDaily(){const d=parse(selected);$('#day-title').textContent=`${d.getMonth()+1}월 ${d.getDate()}일 ${['일','월','화','수','목','금','토'][d.getDay()]}요일`;const order=['아침','점심','저녁','간식'];const list=meals.filter(m=>m.date===selected).sort((a,b)=>order.indexOf(a.type)-order.indexOf(b.type));$('#day-count').textContent=list.length+'끼 기록';$('#meals').innerHTML=list.length?list.map(m=>`<article class="meal"><img src="${esc(m.image)}" alt="${esc(m.name)}"><div class="meal-info"><span class="meal-tag">${esc(m.type)}${m.demo?' · 예시':''}</span><h3>${esc(m.name)}</h3><p>${esc(m.restaurant||'직접 기록')}</p><b>${num(m.calories)} kcal</b></div><button class="delete" data-delete="${esc(m.id)}" aria-label="${esc(m.name)} 기록 삭제">×</button></article>`).join('')+`<div class="day-total">기록한 총 칼로리 <b>${num(sum(list,'calories'))} kcal</b></div>`:'<div class="empty">아직 비어 있는 식탁 🍽️<br>첫 번째 식사를 남겨보세요.</div>';$$('[data-delete]').forEach(b=>b.onclick=()=>{if(save(meals.filter(m=>m.id!==b.dataset.delete))){render();toast('식사 기록을 삭제했어요.');}else toast('저장할 수 없어 삭제하지 못했어요.');});fallbackImages();}
function renderReport(){const {start,end,list}=datesInRange();$('#range').textContent=`${start.getFullYear()}. ${start.getMonth()+1}. ${start.getDate()} — ${end.getMonth()+1}. ${end.getDate()}`;let buckets=[];if(period==='week'){for(let i=0;i<7;i++){const d=new Date(start);d.setDate(start.getDate()+i);buckets.push({label:['월','화','수','목','금','토','일'][i],value:sum(list.filter(m=>m.date===localDate(d)),'calories')});}}else{for(let i=1;i<=end.getDate();i+=7){buckets.push({label:`${i}–${Math.min(i+6,end.getDate())}일`,value:sum(list.filter(m=>{const day=parse(m.date).getDate();return day>=i&&day<i+7;}),'calories')});}}const max=Math.max(...buckets.map(b=>b.value),1);$('#bars').innerHTML=buckets.map(b=>`<div class="bar-column" title="${b.label}: ${num(b.value)} kcal"><span>${b.value?num(b.value):''}</span><div class="bar" style="height:${b.value/max*87}%"></div><small>${b.label}</small></div>`).join('');const c=sum(list,'carbs'),p=sum(list,'protein'),f=sum(list,'fat'),energy=c*4+p*4+f*9;const cp=energy?c*4/energy*100:0,pp=energy?p*4/energy*100:0;$('#donut').style.background=energy?`conic-gradient(#0cefd3 0 ${cp}%,#222222 ${cp}% ${cp+pp}%,#a6a7a9 ${cp+pp}% 100%)`:'#f3f4f5';$('#donut-total').textContent=num(sum(list,'calories'));$('#macros').innerHTML=[['탄수화물',c,cp,'#0cefd3'],['단백질',p,pp,'#222222'],['지방',f,energy?100-cp-pp:0,'#a6a7a9']].map(m=>`<div class="macro-item"><i style="background:${m[3]}"></i>${m[0]}<b>${num(m[1])}g <small>${Math.round(m[2])}%</small></b></div>`).join('');const days=new Set(list.map(m=>m.date)).size;$('#insight').innerHTML=`<span class="insight-title">✦ ${period==='week'?'이번 주':'이번 달'}의 기록 노트</span><h3>${days?`${days}일 동안 ${list.length}끼,<br>나의 식탁을 돌아봤어요.`:'아직 기록이 없어요.<br>한 끼부터 시작해 볼까요?'}</h3><p>${days?`기록일 평균 ${num(sum(list,'calories')/days)} kcal를 기록했어요. 빠진 식사도 남기면 더 정확하게 돌아볼 수 있어요.`:'음식 사진과 영양 정보를 남기면 이곳에 나의 기록이 모여요.'}</p>`;$('#full-report').innerHTML=`<div class="report-row"><span>조회 기간</span><b>${period==='week'?'주간':'월간'} · ${days}일 기록</b></div>`+[['기록한 식사',list.length,'끼'],['총 칼로리',sum(list,'calories'),'kcal'],['탄수화물',c,'g'],['단백질',p,'g'],['지방',f,'g']].map(r=>`<div class="report-row"><span>${r[0]}</span><b>${num(r[1])} ${r[2]}</b></div>`).join('')+'<p class="form-help" style="padding:0 24px">아래 주간·월간 버튼으로 조회 기간을 전환하세요. 영양소 비율은 탄수화물·단백질 4 kcal/g, 지방 9 kcal/g으로 환산한 비율입니다.</p>';}
$('#prev').onclick=()=>calendarExpanded?moveMonth(-1):moveWeek(-1);
$('#next').onclick=()=>calendarExpanded?moveMonth(1):moveWeek(1);
function moveMonth(n){month=new Date(month.getFullYear(),month.getMonth()+n,1);selected=localDate(month);render();}
$$('[data-period]').forEach(b=>b.onclick=()=>{period=b.dataset.period;$$('[data-period]').forEach(x=>x.classList.toggle('active',x===b));renderReport();});
$$('[data-view]').forEach(b=>b.onclick=()=>{const report=b.dataset.view==='report';$$('[data-view]').forEach(x=>x.classList.toggle('active',x===b));$('#calendar-panel').hidden=report;$('#report-panel').hidden=!report;$('#page-name').textContent=report?'건강 리포트':'식사 캘린더';$('#title').innerHTML=report?'한 끼씩 쌓인, 나의 건강 이야기<span>.</span>':'잘 먹었습니다<span>.</span>';});
function openForm(){uploadVersion++;$('.save').disabled=false;$('#meal-form').reset();$('#date').value=selected;uploaded='';$('#preview').hidden=true;$('#upload-label').hidden=false;$('#form-error').textContent='';$('#dialog').showModal();}$('#add').onclick=openForm;$('#add-day').onclick=openForm;$('#bottom-add').onclick=openForm;
function updateStatusTime(){const d=new Date();$('#status-time').textContent=d.toLocaleTimeString('ko-KR',{hour:'2-digit',minute:'2-digit',hour12:false});}updateStatusTime();setInterval(updateStatusTime,60000);$('#close').onclick=()=>$('#dialog').close();$('#dialog').onclick=e=>{if(e.target===$('#dialog')){const r=e.target.getBoundingClientRect();if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom)e.target.close();}};
let uploadVersion=0;$('#photo').onchange=async e=>{const file=e.target.files[0],version=++uploadVersion;uploaded='';$('#preview').hidden=true;$('#upload-label').hidden=false;if(!file)return;$('#form-error').textContent='';if(file.size>5*1024*1024||!['image/jpeg','image/png','image/webp'].includes(file.type)){$('#form-error').textContent='5MB 이하의 JPG, PNG, WEBP 사진을 선택해 주세요.';e.target.value='';return;}$('.save').disabled=true;try{const url=URL.createObjectURL(file);const img=new Image();try{await new Promise((resolve,reject)=>{img.onload=resolve;img.onerror=reject;img.src=url;});const canvas=document.createElement('canvas'),scale=Math.min(1,900/Math.max(img.width,img.height));canvas.width=Math.round(img.width*scale);canvas.height=Math.round(img.height*scale);canvas.getContext('2d').drawImage(img,0,0,canvas.width,canvas.height);if(version===uploadVersion){uploaded=canvas.toDataURL('image/jpeg',.78);$('#preview').src=uploaded;$('#preview').hidden=false;$('#upload-label').hidden=true;}}finally{URL.revokeObjectURL(url);}}catch{$('#form-error').textContent='사진을 읽을 수 없어요. 다른 사진을 선택해 주세요.';}finally{if(version===uploadVersion)$('.save').disabled=false;}};
$('#meal-form').onsubmit=e=>{e.preventDefault();const name=$('#food-name').value.trim();if(!name){$('#form-error').textContent='음식 이름을 입력해 주세요.';return;}const item={id:crypto.randomUUID(),date:$('#date').value,type:$('#meal-type').value,name,restaurant:$('#restaurant').value.trim(),image:uploaded||placeholder,calories:Number($('#calories').value),carbs:Number($('#carbs').value),protein:Number($('#protein').value),fat:Number($('#fat').value),demo:false};if(save([...meals,item])){selected=item.date;month=new Date(parse(selected).getFullYear(),parse(selected).getMonth(),1);$('#dialog').close();render();toast('맛있는 한 끼를 기록했어요!');}};
function toast(message){$('#toast').textContent=message;$('#toast').style.opacity=1;clearTimeout(window.toastTimeout);window.toastTimeout=setTimeout(()=>$('#toast').style.opacity=0,2600);}render();

function moveWeek(direction){
 const date=parse(selected);date.setDate(date.getDate()+direction*7);
 selected=localDate(date);month=new Date(date.getFullYear(),date.getMonth(),1);
 render();
 const calendar=$('#calendar');
 if(!window.matchMedia('(prefers-reduced-motion: reduce)').matches)calendar.animate([{transform:`translateX(${direction*35}px)`,opacity:.35},{transform:'translateX(0)',opacity:1}],{duration:220,easing:'ease-out'});
}
$('#calendar').addEventListener('keydown',e=>{
 if(e.target===$('#calendar')&&!calendarExpanded&&['ArrowLeft','ArrowRight'].includes(e.key)){e.preventDefault();moveWeek(e.key==='ArrowRight'?1:-1);}
});
