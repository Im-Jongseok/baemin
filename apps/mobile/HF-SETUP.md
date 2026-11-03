# iPhone 사진 분석 연결

## 실행 중인 구조

아이폰 앱 → 같은 Wi-Fi의 Mac(`192.168.219.104:4182`) → Hugging Face Inference Providers.

아이폰에서 `127.0.0.1`은 아이폰 자신이므로 Mac의 주소로 빌드했다. `tools/run-iphone.sh`는 기본적으로 `en0`/`en1`의 주소를 사용하고, `ANALYSIS_BASE_URL`로 직접 지정할 수도 있다. IP가 바뀌면 다시 빌드한다.

앱은 **마이배민 → 설정 → 사진 분석 연결**을 눌러 서버 상태를 확인할 수 있다. 이 검사는 사진 없이 GET `/api/config`만 호출한다. iOS에서 요청하면 로컬 네트워크 접근을 허용한다.

## 서버 자격 증명

저장소 루트의 `services/nutrition-api/.env` 파일에 직접 입력한다. 앱/브라우저 번들에는 넣지 않는다.

```dotenv
HF_TOKEN=
HF_MODEL_ID=Qwen/Qwen3-VL-30B-A3B-Instruct:deepinfra
```

토큰은 [Hugging Face 토큰 설정](https://huggingface.co/settings/tokens)에서 Inference Providers 호출 권한을 포함해 생성한다. 파일은 서버가 요청마다 다시 읽으므로 토큰 저장 후 재시작할 필요가 없다. 토큰/사진/요청 본문은 로그에 남기지 않는다.

```sh
(cd ../../services/nutrition-api && python3 -m nutrition_api --host 127.0.0.1 --port 4182)
# 별도 터미널에서 실제 Mac의 Wi-Fi 주소에 바인딩한다.
(cd ../../services/nutrition-api && python3 -m nutrition_api --host 192.168.219.104 --port 4182)
```

`.env`의 다운로드 경로는 제공하지 않는다. `/api/config`에는 토큰 유무와 모델 ID만 반환한다. 실제 분석에는 사진 전송 동의가 필요하다. 결과는 음식명·사진·분량에 따른 추정값이며 기록 전에 수정할 수 있다.

## 현재 확인한 범위

- iPhone용 서명 앱 설치/실행과 Mac 미러링 성공.
- API 서버의 loopback/LAN 설정 GET 응답 확인.
- 모델 지원 매핑에서 위 모델의 Featherless 제공 상태 `live` 확인 (2026-10-26). 실제 추론 성공을 의미하지 않는다.
- 구독 전 실제 요청은 402(추론 사용 한도·결제)를 반환했다. PRO 구독 후 기존 모델을 다시 확인하니 HTTP 400 `model_not_deployed`였다. Hub의 `live` 매핑만으로 실제 제공 여부를 판단할 수 없었다.
- 2026-11-04 HF 라우터 `/v1/models`에서 이미지 입력을 지원하는 경로를 확인해 `Qwen/Qwen3-VL-30B-A3B-Instruct:deepinfra`로 교체했다. 기존 HF 토큰을 그대로 사용한다.
- 앱에 포함된 햄버거 이미지 한 장을 실제 전송해 HTTP 200, 음식명·재료·영양 JSON과 서버 검증 성공을 확인했다. 4.2초, 입력 213/출력 89토큰, 응답의 `estimated_cost`는 $0.00008535였다. 청구 명세에서 확인한 확정 금액은 아니다.
- 이 검증은 Mac에서 동일 서버 분석 함수를 호출한 연결 확인이다. 실제 아이폰 카메라 촬영부터 저장까지의 전체 흐름이나 음식별 영양 정확도를 검증한 것은 아니다. 실패 시 가짜 영양값을 반환하지 않는다.

## 비용 (2026-11-04 공식 안내 확인)

접속용 토큰 발급과 모델 실행 비용은 별개다. 현재 무료 계정에는 포함된 Inference Providers 크레딧이 없고 크레딧 구매가 필요하다. PRO는 월 $9이며 $2 크레딧이 포함된다. PRO 구독이 필수인 것은 아니다. 요청 비용은 모델/제공자/사진 입력량/출력량에 따라 달라지며 이번 한 장의 실제 분석 성공과 응답의 추정 비용은 확인했지만, 사진당 고정 비용이나 확정 청구액은 측정하지 않았다.

현재 앱은 서버의 HF 토큰으로 Hugging Face 라우터를 호출한다. 같은 토큰 계정에 PRO 포함 크레딧이나 별도 구매 크레딧이 생기면 이 호출에 사용할 수 있다. PRO는 무제한 추론 상품이 아니며 포함 크레딧 소진 후 추가 사용에는 별도 크레딧이 필요하다. 다른 컴퓨팅 서비스도 같은 포함 크레딧을 사용할 수 있다. 사진 분석 API만 필요하다면 PRO 없이 크레딧만 구매하는 방법도 있다.

사용자는 [계정 Billing](https://huggingface.co/settings/billing)에서 잔액·결제 제한을 확인한다. 같은 계정의 기존 토큰을 유지하면 앱 재빌드나 토큰 재발급은 필요하지 않다. 다른 계정으로 바꾸면 서버 `.env`의 토큰을 갱신한다. 이번에는 크레딧 준비 후 실제 사진 1장의 성공 응답까지 확인했다. 구독만으로 모델 제공 상태·접근 권한 등 다른 오류까지 해결되는 것은 아니다. 외부 제공자의 별도 API 키로 결제하도록 바꾼 경우에는 HF 포함 크레딧이 적용되지 않는다.

[Hugging Face 과금 안내](https://huggingface.co/docs/inference-providers/pricing) · [공식 요금표](https://huggingface.co/pricing) · [이미지·텍스트 모델 API](https://huggingface.co/docs/inference-providers/tasks/image-text-to-text).
