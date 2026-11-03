# Nutrition API

Flutter 앱과 웹 목업이 공유하는 사진 분석 모듈입니다. Python 표준 라이브러리만 사용하며, API 서버는 기본적으로 Mac의 `127.0.0.1:4182`에서 실행합니다.

```sh
# 저장소 루트
cp services/nutrition-api/.env.example services/nutrition-api/.env
# .env에 HF_TOKEN과 HF_MODEL_ID 입력 후
make api
```

또는 이 폴더에서:

```sh
python3 -m nutrition_api
python3 -m unittest discover -s tests -v
```

## 파일 역할

- `nutrition_api/server.py`: 서버 설정, CORS, 요청 크기·경로 검증, API 응답
- `nutrition_api/analysis.py`: 이미지/영양값 검증, 예시 분석, Hugging Face 모델 호출
- `nutrition_api/__main__.py`: 실행 진입점
- `tests/`: 분석 계약·동의·비밀키 비노출·오류·CORS 검증

`GET /api/config`는 연결 설정 상태만, `POST /api/photo-analyze`는 분석 결과를 반환합니다. 서버는 `.env`를 요청마다 다시 읽습니다. `.env`나 토큰을 내려주는 경로는 없으며 모델 호출 전에 사진 전송 동의를 확인합니다. 실제 모델 실패를 예시 영양값으로 대체하지 않습니다.

## iPhone에서 연결

같은 네트워크에서 Mac의 현재 주소를 확인하고, 서버를 해당 주소에 바인딩합니다.

```sh
# 이 폴더에서 실행; 아래 주소는 실제 Mac LAN 주소로 교체
python3 -m nutrition_api --host <Mac-LAN-IP> --port 4182
# 별도 터미널에서 저장소 루트 기준
cd apps/mobile
ANALYSIS_BASE_URL=http://<Mac-LAN-IP>:4182 ./tools/run-iphone.sh <기기ID>
```

`--env-file`로 다른 설정 파일도 지정할 수 있습니다. 웹 목업은 같은 `analysis.py`를 가져와 기존 4180의 API 계약을 유지합니다. Flutter 서버가 웹 소스 파일을 동적으로 불러오는 의존 관계는 제거했습니다.
