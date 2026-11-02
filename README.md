# 한끼록 · 배민 프로토타입

음식 주문, 식사 캘린더, 영양 리포트와 만보기를 연결한 학술 발표용 프로토타입입니다. Flutter 네이티브 앱과 기존 웹 구현을 함께 보관합니다.

## 프로젝트 구조

- [`baemin-flutter/`](baemin-flutter/README.md): Flutter 앱, iOS 걸음 수·Live Activity, 가상 주문, 식사 기록, 맞춤 제안
- [`baemin-calendar-mock/`](baemin-calendar-mock/README.md): 기존 웹 목업과 사진 분석 서버
- 루트 `index.html`, `app.js`, `style.css`: 초기 음식 기록 웹 구현. [기존 안내](docs/legacy-web-README.md)

Flutter의 데이터 내보내기와 분석 브리지는 형제 폴더 `baemin-calendar-mock`을 참조하므로 두 폴더의 상대 위치를 유지합니다.

## Flutter 실행

Flutter SDK를 설치한 뒤:

```sh
cd baemin-flutter
./tools/flutter.sh pub get
./tools/flutter.sh run -d chrome --web-port 4181
```

iPhone 빌드·설치는 [아이폰 안내](baemin-flutter/IPHONE.md)를 참고하세요. Xcode에서 자신의 Apple Team과 서명을 설정해야 합니다. 개인 인증서·프로비저닝 파일은 포함하지 않습니다.

## 웹 목업 실행

```sh
cd baemin-calendar-mock
python3 server.py
```

정확한 포트와 분석 연결 설정은 각 폴더의 README를 참고하세요.

## 사진 분석 설정

`baemin-flutter/.env.example`을 `baemin-flutter/.env`로 복사해 서버에서만 사용하는 Hugging Face 토큰을 설정합니다. 토큰은 앱에 포함하거나 Git에 커밋하지 않습니다. 가상 주문과 수기 기록은 모델 연결 없이 사용할 수 있습니다.

```sh
cd baemin-flutter
python3 tools/analysis_bridge.py
```

## 데이터와 검증 범위

실제 배민 주문·결제·회원 서비스는 연동하지 않습니다. 영양값은 기록 또는 추정값이며, 브랜드 메뉴 사진 일부는 범용 예시 이미지입니다. 출처와 실행한 검증은 [이미지·데이터 출처](baemin-flutter/assets/SOURCES.md), [검증 기록](baemin-flutter/qa/VALIDATION.md), [카탈로그 기준](baemin-flutter/qa/NUTRITION-CATALOG-2026-10-29.md)에 정리했습니다.

상표와 원본 화면·이미지의 권리는 각 권리자에게 있습니다. 이 저장소는 공식 배민 앱이 아닙니다. 개인 문서·비밀키·빌드 산출물·기기 원본 캡처는 저장소에 포함하지 않습니다.
