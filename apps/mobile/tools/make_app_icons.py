"""Compose launcher icons from the already-authorized captured order-history icon."""
from pathlib import Path
from PIL import Image, ImageDraw
import json
ROOT=Path(__file__).resolve().parents[1]
source=Image.open(ROOT/'assets/captured/nav-orders-active.png').convert('RGBA')
base=Image.new('RGB',(1024,1024),'#00d2b8')
layer=Image.new('RGBA',(1024,1024));ImageDraw.Draw(layer).rounded_rectangle((210,170,814,854),radius=100,fill='white')
icon=source.resize((460,460),Image.Resampling.LANCZOS);layer.alpha_composite(icon,(282,282));base.paste(layer,mask=layer.getchannel('A'))
for folder in ['ios/Runner/Assets.xcassets/AppIcon.appiconset','macos/Runner/Assets.xcassets/AppIcon.appiconset']:
 path=ROOT/folder
 for record in json.loads((path/'Contents.json').read_text())['images']:
  if not record.get('filename'):continue
  size=int(float(record['size'].split('x')[0])*float(record['scale'].rstrip('x')))
  base.resize((size,size),Image.Resampling.LANCZOS).save(path/record['filename'])
for density,size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:base.resize((size,size),Image.Resampling.LANCZOS).save(ROOT/f'android/app/src/main/res/mipmap-{density}/ic_launcher.png')
for size in [192,512]:
 for name in [f'Icon-{size}.png',f'Icon-maskable-{size}.png']:base.resize((size,size),Image.Resampling.LANCZOS).save(ROOT/'web/icons'/name)
base.resize((32,32),Image.Resampling.LANCZOS).save(ROOT/'web/favicon.png')
