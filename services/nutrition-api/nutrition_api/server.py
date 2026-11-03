"""Small local/LAN analysis API. Credentials stay in the server-only .env file."""
import argparse
import json
import os
from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from . import analysis as api

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MODEL = 'Qwen/Qwen2.5-VL-7B-Instruct:featherless-ai'
ALLOWED_ORIGINS = ('http://localhost:4181', 'http://127.0.0.1:4181')


def config(path):
    values = {}
    if path.is_file():
        for line in path.read_text().splitlines():
            key, sep, value = line.strip().partition('=')
            if sep and key in ('HF_TOKEN', 'HF_MODEL_ID'):
                values[key] = value.strip().strip('\"\'')
    return {
        'token': values.get('HF_TOKEN') or os.environ.get('HF_TOKEN', ''),
        'model': values.get('HF_MODEL_ID') or os.environ.get('HF_MODEL_ID', DEFAULT_MODEL),
    }


class Bridge(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass  # Never log tokens, images, request bodies, or provider responses.

    def cors(self):
        origin = self.headers.get('Origin')
        if origin in ALLOWED_ORIGINS:
            self.send_header('Access-Control-Allow-Origin', origin)
            self.send_header('Vary', 'Origin')

    def respond(self, status, payload):
        body = json.dumps(payload, ensure_ascii=False).encode()
        self.send_response(status)
        self.cors()
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def allowed(self):
        # Native iPhone requests have no browser Origin header.
        origin = self.headers.get('Origin')
        return not origin or origin in ALLOWED_ORIGINS

    def do_OPTIONS(self):
        if self.headers.get('Origin') not in ALLOWED_ORIGINS:
            self.respond(403, {'error': '허용하지 않은 요청이에요.'})
            return
        self.send_response(204)
        self.cors()
        self.send_header('Access-Control-Allow-Methods', 'POST, GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_GET(self):
        if not self.allowed():
            self.respond(403, {'error': '허용하지 않은 요청이에요.'})
        elif self.path == '/api/config':
            c = config(self.server.env_file)
            self.respond(200, {'hfConfigured': bool(c['token']), 'modelId': c['model'], 'baeminProvider': 'fixture'})
        else:
            self.respond(404, {'error': '찾을 수 없는 경로예요.'})

    def do_POST(self):
        if not self.allowed():
            self.respond(403, {'error': '허용하지 않은 요청이에요.'})
            return
        if self.path != '/api/photo-analyze':
            self.respond(404, {'error': '찾을 수 없는 경로예요.'})
            return
        try:
            size = int(self.headers.get('Content-Length', 0))
        except ValueError:
            self.respond(400, {'error': '요청을 읽을 수 없어요.'})
            return
        if size < 1 or size > 7_100_000:
            self.respond(413, {'error': '5MB 이하 사진을 사용해 주세요.'})
            return
        try:
            payload = json.loads(self.rfile.read(size))
            if not isinstance(payload, dict):
                raise ValueError()
        except (ValueError, UnicodeError):
            self.respond(400, {'error': '요청 형식을 확인해 주세요.'})
            return
        try:
            c = config(self.server.env_file)
            if payload.get('mode') == 'huggingface' and not c['token']:
                self.respond(503, {'error': '사진 분석 서버에 Hugging Face 연결이 아직 설정되지 않았어요. 음식 종류 선택·직접 입력을 이용해 주세요.'})
                return
            self.respond(200, api.analyze(payload, token=c['token'], model=c['model']))
        except api.APIError as error:
            self.respond(error.status, {'error': error.message})
        except Exception:
            self.respond(500, {'error': '분석 중 문제가 생겼어요. 다시 시도해 주세요.'})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host', default='127.0.0.1')
    parser.add_argument('--port', type=int, default=4182)
    parser.add_argument('--env-file', type=Path, default=ROOT / '.env')
    args = parser.parse_args()
    server = ThreadingHTTPServer((args.host, args.port), Bridge)
    server.env_file = args.env_file
    print(f'Analysis API: http://{args.host}:{args.port}', flush=True)
    server.serve_forever()
