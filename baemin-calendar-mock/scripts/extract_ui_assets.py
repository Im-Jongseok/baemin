"""Deterministic crop/mask of user-authorized UI captures; never uploads source images."""
from pathlib import Path
from PIL import Image, ImageDraw
import hashlib,json

ROOT=Path(__file__).resolve().parents[1]
PRIVATE=Path('/Users/jongseok/.codex/visualizations/2026/10/25/01a1741c-a524-7b60-b429-4ba47d10f6b8/baemin-private-evidence/2026-10-26-postpurchase')
EARLY=ROOT.parent/'output/baemin-ux-analysis-2026-10-26/screenshots'
SOURCES={'my':PRIVATE/'P01_마이배민_상단.jpg','favorites':PRIVATE/'P09_찜_배달픽업.jpg','orders':PRIVATE/'P06_배달완료_카드.jpg','home':EARLY/'R02_홈.jpg','home-end':EARLY/'R12_종료_홈.jpg'}
OUT=ROOT/'assets/captured';OUT.mkdir(exist_ok=True)
# Rectangles are measured against these exact screenshots (636x1402).
SPECS=[
 ('nav-home','my',(98,1277,139,1316),'ink'),
 ('nav-home-active','home',(98,1277,139,1316),'ink'),
 ('nav-shopping','my',(199,1277,240,1316),'ink'),
 ('nav-favorites','my',(301,1277,342,1316),'ink'),
 ('nav-orders','my',(399,1277,440,1316),'ink'),
 ('nav-orders-active','orders',(399,1277,440,1316),'ink'),
 ('nav-my','favorites',(497,1277,539,1316),'ink'),
 ('nav-my-active','my',(497,1277,539,1316),'ink'),
 ('headset','my',(477,183,515,220),'ink-soft'),
 ('settings','my',(548,181,586,220),'ink-soft'),
 ('search','favorites',(489,181,526,219),'ink'),
 ('cart','home-end',(562,181,601,217),'ink'),
 ('bell','home-end',(502,180,538,218),'ink'),
 ('category-chicken','home',(43,436,137,533),'crop'),
 ('category-cafe','home',(158,436,252,533),'crop'),
 ('category-pizza','home',(273,436,367,533),'crop'),
 ('category-stew','home',(388,436,482,533),'crop'),
 ('category-sushi','home',(501,436,595,533),'crop'),
 ('category-burger','home',(273,583,367,680),'crop'),
 ('category-snack','home',(388,583,482,680),'crop'),
 ('category-single','home-end',(157,572,253,680),'crop'),
 ('market-bmart','home-end',(40,813,140,927),'crop'),
 ('market-cu','home-end',(142,812,242,928),'crop'),
 ('market-gs','home-end',(249,822,352,928),'crop'),
 ('profile-mascot','my',(226,334,411,470),'matte'),
]
images={key:Image.open(path).convert('RGB') for key,path in SOURCES.items()}
manifest=[]
for name,key,box,mode in SPECS:
 source=images[key];tile=source.crop(box).convert('RGBA')
 if mode in ('ink','ink-soft'):
  # Keep the exact captured shape; discard translucent nav/background tint.
  pixels=[]
  for r,g,b,_ in tile.get_flattened_data():
   lum=.2126*r+.7152*g+.0722*b
   # Saturated badge/cursor pixels are not part of the monochrome icon.
   chroma=max(r,g,b)-min(r,g,b)
   a=round(max(0,min(1,((245-lum)/225 if mode=='ink-soft' else (155-lum)/100)))*255) if chroma<65 else 0
   if mode=='ink-soft' and a<20:a=0
   pixels.append((15,17,18,a))
  tile.putdata(pixels)
  bounds=tile.getbbox()
  if bounds:
   # All navigation assets share the same canvas and optical center.
   mark=tile.crop(bounds);canvas=Image.new('RGBA',(48,48));canvas.alpha_composite(mark,((48-mark.width)//2,(48-mark.height)//2));tile=canvas
 elif mode=='matte':
  # The profile's surrounding screen is flat gray. Remove only pixels connected
  # to the border and close to that screen color, preserving white mascot rim.
  w,h=tile.size;pix=tile.load();seen=set();stack=[(x,0) for x in range(w)]+[(x,h-1) for x in range(w)]+[(0,y) for y in range(h)]+[(w-1,y) for y in range(h)]
  background=(244,245,247)
  while stack:
   x,y=stack.pop()
   if (x,y) in seen or x<0 or y<0 or x>=w or y>=h:continue
   seen.add((x,y));r,g,b,a=pix[x,y]
   if max(abs(r-background[0]),abs(g-background[1]),abs(b-background[2]))>4:continue
   pix[x,y]=(r,g,b,0);stack.extend(((x-1,y),(x+1,y),(x,y-1),(x,y+1)))
  bounds=tile.getbbox()
  if bounds:tile=tile.crop(bounds)
 if name=='cart':
  # The captured count badge occludes the basket's upper-right corner. Rejoin
  # only that missing stroke; keep the original handle, basket and wheel pixels.
  repair=Image.new('RGBA',(48*4,48*4));pen=ImageDraw.Draw(repair)
  pen.line([(30*4,15*4),(38*4,15*4),(36*4,22*4)],fill=(15,17,18,255),width=3*4,joint='curve')
  tile.alpha_composite(repair.resize((48,48),Image.Resampling.LANCZOS))
 target=OUT/(name+'.png');tile.save(target)
 manifest.append({'name':name,'file':target.name,'source':SOURCES[key].name,'sourceSha256':hashlib.sha256(SOURCES[key].read_bytes()).hexdigest(),'box':box,'operation':mode+('+badge-occlusion-repair' if name=='cart' else ''),'width':tile.width,'height':tile.height})
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
# Inspection sheet only; served assets remain the individual cropped pixels.
sheet=Image.new('RGB',(700,((len(SPECS)+5)//6)*135),'#eceef1');draw=ImageDraw.Draw(sheet)
for i,item in enumerate(manifest):
 tile=Image.open(OUT/item['file']);tile.thumbnail((95,95));x=(i%6)*116+(110-tile.width)//2;y=(i//6)*135+5
 sheet.paste(tile,(x,y),tile);draw.text(((i%6)*116+3,(i//6)*135+106),item['name'],fill='#222')
sheet.save(ROOT/'qa/captured-assets-contact.png')
print(f'{len(manifest)} captured assets extracted')
