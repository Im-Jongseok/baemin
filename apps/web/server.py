"""Loopback-only web preview with the shared nutrition API."""
import argparse
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'services/nutrition-api'))
from nutrition_api.analysis import APIError, SAMPLES, analyze, normalize_result, validate_image

ROOT = Path(__file__).resolve().parent
PUBLIC = {'/': 'index.html', '/index.html': 'index.html', '/app.mjs': 'app.mjs', '/domain.mjs': 'domain.mjs', '/supplier.mjs':'supplier.mjs', '/style.css': 'style.css', '/commerce.css':'commerce.css', '/catalog.mjs':'catalog.mjs', '/assets/food-grid.png':'assets/food-grid.png', '/assets/commerce-grid.png':'assets/commerce-grid.png'}
# Explicit named UI assets only. Original account screenshots are never served.
CAPTURED_UI_NAMES=('nav-home','nav-home-active','nav-shopping','nav-favorites','nav-orders','nav-orders-active','nav-my','nav-my-active','headset','settings','search','cart','bell','category-chicken','category-cafe','category-pizza','category-stew','category-sushi','category-burger','category-snack','category-single','market-bmart','market-cu','market-gs','profile-mascot')
PUBLIC['/captured-ui.css']='captured-ui.css'
PUBLIC['/insights.mjs']='insights.mjs'
PUBLIC['/report-view.mjs']='report-view.mjs'
PUBLIC['/report.css']='report.css'
PUBLIC['/screens.css']='screens.css'
PUBLIC['/calendar.mjs']='calendar.mjs'
PUBLIC['/calendar.css']='calendar.css'
PUBLIC['/order-detail.css']='order-detail.css'
PUBLIC['/interaction.css']='interaction.css'
PUBLIC['/assets/chopped-vegetables.png']='assets/chopped-vegetables.png'
PUBLIC['/assets/baemin-easy-tofu.png']='assets/baemin-easy-tofu.png'
for name in ('easy-milk-observed','easy-sundae-observed','easy-pork-gukbap-observed'):PUBLIC['/assets/captured/'+name+'.png']='assets/captured/'+name+'.png'
for name in ('points','coupon','pickup'):PUBLIC['/assets/captured/benefit-'+name+'.png']='assets/captured/benefit-'+name+'.png'
for asset in CAPTURED_UI_NAMES:
 PUBLIC['/assets/captured/'+asset+'.png']='assets/captured/'+asset+'.png'
class Handler(BaseHTTPRequestHandler):
 def log_message(self,*args): pass  # Never log images, headers, tokens or request bodies.
 def respond(self,status,data,content_type='application/json; charset=utf-8'):
  raw=json.dumps(data,ensure_ascii=False).encode() if isinstance(data,dict) else data
  self.send_response(status); self.send_header('Content-Type',content_type); self.send_header('Content-Length',str(len(raw)))
  self.send_header('Cache-Control','no-store');self.send_header('X-Content-Type-Options','nosniff');self.end_headers();self.wfile.write(raw)
 def do_GET(self):
  path=self.path.split('?')[0]
  if path=='/api/config':
   return self.respond(200,{'hfConfigured':bool(os.environ.get('HF_TOKEN')),'modelId':os.environ.get('HF_MODEL_ID','Qwen/Qwen2.5-VL-7B-Instruct:featherless-ai'),'baeminProvider':'fixture','samples':list(SAMPLES)})
  if path not in PUBLIC:return self.respond(404,{'error':'찾을 수 없는 경로예요.'})
  file=ROOT/PUBLIC[path]
  types={'.html':'text/html; charset=utf-8','.mjs':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.png':'image/png'}
  self.respond(200,file.read_bytes(),types[file.suffix])
 def do_POST(self):
  if self.path!='/api/photo-analyze': return self.respond(404,{'error':'찾을 수 없는 경로예요.'})
  origin=self.headers.get('Origin'); port=self.server.server_address[1]
  if origin and origin not in (f'http://localhost:{port}',f'http://127.0.0.1:{port}'):return self.respond(403,{'error':'이 로컬 미리보기에서 요청해 주세요.'})
  try:
   length=int(self.headers.get('Content-Length','0'))
   if length<1 or length>7_200_000: raise APIError('사진은 5MB 이하로 준비해 주세요.',413)
   if not self.headers.get('Content-Type','').startswith('application/json'):raise APIError('JSON 요청이 필요해요.',415)
   payload=json.loads(self.rfile.read(length))
   if not isinstance(payload,dict): raise APIError('요청 형식을 확인해 주세요.')
   self.respond(200,analyze(payload))
  except APIError as error:self.respond(error.status,{'error':error.message,'code':error.code})
  except (ValueError,UnicodeError):self.respond(400,{'error':'요청을 읽을 수 없어요.'})
  except Exception:self.respond(500,{'error':'분석 중 문제가 생겼어요. 다시 시도해 주세요.'})

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--port',type=int,default=4180);args=parser.parse_args()
 server=ThreadingHTTPServer(('127.0.0.1',args.port),Handler)
 print(f'Local: http://localhost:{args.port}/',flush=True)
 print('사진 분석: '+('Hugging Face 연결 설정됨' if os.environ.get('HF_TOKEN') else '데모 모드 · HF_TOKEN 미설정'),flush=True)
 try:server.serve_forever()
 except KeyboardInterrupt:server.server_close()
