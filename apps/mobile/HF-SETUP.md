# iPhone 사진 분석 연결

## 실행 중인 구조

아이폰 앱 → 같은 Wi-Fi의 Mac(`192.168.219.103:4182`) → Hugging Face Inference Providers.

아이폰에서 `127.0.0.1`은 아이폰 자신이므로 Mac의 주소로 빌드했다. `tools/run-iphone.sh`는 기본적으로 `en0`/`en1`의 주소를 사용하고, `ANALYSIS_BASE_URL`로 직접 지정할 수도 있다. IP가 바뀌면 다시 빌드한다.

앱은 **마이배민 → 설정 → 사진 분석 연결**을 눌러 서버 상태를 확인할 수 있다. 이 검사는 사진 없이 GET `/api/config`만 호출한다. iOS에서 요청하면 로컬 네트워크 접근을 허용한다.

## 서버 자격 증명

저장소 루트의 `services/nutrition-api/.env` 파일에 직접 입력한다. 앱/브라우저 번들에는 넣지 않는다.

```dotenv
HF_TOKEN=
HF_MODEL_ID=Qwen/Qwen2.5-VL-7B-Instruct:featherless-ai
```

토큰은 [Hugging Face 토큰 설정](https://huggingface.co/settings/tokens)에서 Inference Providers 호출 권한을 포함해 생성한다. 파일은 서버가 요청마다 다시 읽으므로 토큰 저장 후 재시작할 필요가 없다. 토큰/사진/요청 본문은 로그에 남기지 않는다.

```sh
(cd ../../services/nutrition-api && python3 -m nutrition_api --host 127.0.0.1 --port 4182)
# 별도 터미널에서 실제 Mac의 Wi-Fi 주소에 바인딩한다.
(cd ../../services/nutrition-api && python3 -m nutrition_api --host 192.168.219.103 --port 4182)
```

`.env`의 다운로드 경로는 제공하지 않는다. `/api/config`에는 토큰 유무와 모델 ID만 반환한다. 실제 분석에는 사진 전송 동의가 필요하다. 결과는 음식명·사진·분량에 따른 추정값이며 기록 전에 수정할 수 있다.

## 현재 확인한 범위

- iPhone용 서명 앱 설치/실행과 Mac 미러링 성공.
- API 서버의 loopback/LAN 설정 GET 응답 확인.
- 모델 지원 매핑에서 위 모델의 Featherless 제공 상태 `live` 확인 (2026-10-26). 실제 추론 성공을 의미하지 않는다.
- 토큰 저장 후 서버 `hfConfigured: true` 및 iPhone 설정 화면의 서버 연결 성공을 확인했다. 공개 음식 이미지 한 장으로 실제 호출했으나 HF가 402(추론 사용 한도·결제)를 반환했다. 서버는 이 사유를 앱에 전달한다.
- 현재 남은 조건은 HF 계정의 추론 크레딧/결제 한도 준비다. 실제 영양 분석 성공은 아직 확인하지 않았다. 실패 시 영양값을 만들어 내지 않고 오류와 직접 입력 경로를 제공한다.

## 비용 (2026-10-26 공식 안내 확인)

접속용 토큰 발급과 모델 실행 비용은 별개다. 현재 무료 계정에는 포함된 Inference Providers 크레딧이 없고 크레딧 구매가 필요하다. PRO는 월 $9이며 $2 크레딧이 포함된다. PRO 구독이 필수인 것은 아니다. 요청 비용은 모델/제공자/사진 입력량/출력량에 따라 달라지며 사진당 확정 비용이나 실제 유료 분석 성공을 아직 측정하지 않았다.

[Hugging Face 과금 안내](https://huggingface.co/docs/inference-providers/pricing) · [공식 요금표](https://huggingface.co/pricing) · [이미지·텍스트 모델 API](https://huggingface.co/docs/inference-providers/tasks/image-text-to-text).
