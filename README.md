# 한끼록 · 배민 프로토타입

가상 주문, 식사 캘린더, 영양 리포트와 만보기를 연결한 학술 발표용 프로젝트입니다. 앱·웹·분석 서버를 하나의 저장소에서 독립적으로 실행합니다.

## 구조

```text
apps/
  mobile/               Flutter 앱 (iOS·Android·웹)
    lib/
      main.dart         앱 시작
      app/              테마·최상위 탐색
      core/             공통 상태·분석 API 연결
      features/         catalog / orders / nutrition / food_record / walking
      shared/widgets/   공통 UI
    assets/             번들 이미지·글꼴·예시 데이터
    data/               카탈로그 보정 원본
    test/               앱 테스트
    tools/              앱 빌드·설치·데이터 내보내기
  web/                  기존 배민 웹 목업 (4180)
  legacy-web/           초기 음식 기록 웹 (4173)
services/
  nutrition-api/
    nutrition_api/      설정·HTTP 서버·이미지 검증·모델 호출
    tests/              서버 테스트·테스트 사진
    .env.example        서버 설정 예시
    .env                개인 토큰 (Git 제외)
docs/                   구조·운영 안내
Makefile                공통 실행·검증 명령
```

폴더별 책임과 의존 관계는 [구조 안내](docs/ARCHITECTURE.md)에 정리했습니다.

## 실행

Flutter SDK, Node.js, Python 3가 필요합니다. Flutter는 `PATH` 또는 기존 `~/.cache/baemin-flutter-sdk`의 SDK를 사용합니다.

```sh
cd apps/mobile
./tools/flutter.sh pub get
cd ../..
make help
make mobile  # Flutter 웹 개발: 4181
make web     # 기존 웹 목업: 4180 (별도 터미널)
make api     # 사진 분석 API: 4182 (별도 터미널)
```

[iPhone 설치 안내](apps/mobile/IPHONE.md), [Flutter 안내](apps/mobile/README.md), [웹 목업 안내](apps/web/README.md)를 참고하세요. iOS 서명은 자신의 Apple Team으로 설정해야 합니다.

## 사진 분석

`services/nutrition-api/.env.example`을 같은 폴더의 `.env`로 복사해 서버용 토큰을 입력합니다. 앱에는 토큰이 들어가지 않습니다. 실제 분석에는 사진 전송 동의와 사용 가능한 모델/추론 크레딧이 필요합니다. 가상 주문·수기 기록은 서버 없이 사용할 수 있습니다.

- [분석 서버 실행·환경 설정](services/nutrition-api/README.md)
- [실기기 분석 연결](apps/mobile/HF-SETUP.md)

## 검증

```sh
make test
make analyze
make build-web
```

앱/웹 기능 검증 기록은 [Flutter QA](apps/mobile/qa/VALIDATION.md), 이번 이동 검증은 [폴더 분리 기록](docs/RESTRUCTURE.md)에 있습니다. 기존 웹 JSON을 앱으로 수동 가져올 수 있으며 자동 동기화는 하지 않습니다.

## 데이터·권리

실제 배민 주문·결제·회원 서비스는 연동하지 않습니다. 영양값은 기록 또는 추정값이며 일부 메뉴 사진은 범용 예시 이미지입니다. [출처](apps/mobile/assets/SOURCES.md)와 [카탈로그 기준](apps/mobile/qa/NUTRITION-CATALOG-2026-10-29.md)을 확인하세요. 상표와 원본 이미지의 권리는 각 권리자에게 있으며 공식 배민 앱이 아닙니다.

개인 문서·비밀키·인증서·빌드 산출물·기기 원본 캡처는 업로드하지 않습니다.
