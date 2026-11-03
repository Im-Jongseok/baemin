# 한 끼 캘린더 · Flutter

기존 `../web`의 화면·상품·이미지·주문 흐름을 별도 Flutter 위젯으로 구현한 앱이다. WebView를 사용하지 않는다. 원본 웹 소스와 브라우저 localStorage는 수정하지 않는다.

## 실행

이 Mac에는 Flutter 3.47.8 stable / Dart 3.13.7을 `~/.cache/baemin-flutter-sdk`에 준비했다. 셸 설정이나 기본 PATH는 변경하지 않았다.

```sh
./tools/flutter.sh pub get
./tools/flutter.sh run -d chrome --web-port 4181
```

빌드한 Flutter 미리보기:

```sh
./tools/flutter.sh build web --release
python3 -m http.server 4181 --bind 127.0.0.1 --directory build/web
```

원본 웹은 **http://localhost:4180/**, Flutter 미리보기는 **http://localhost:4181/** 이다. 별도 포트와 저장 키를 사용한다. `localhost:4181`과 `127.0.0.1:4181`의 브라우저 저장 공간도 서로 다르므로 한 주소를 일관되게 사용한다.

## iPhone에 설치해 미러링 시연

현재 준비 상태와 실제 설치 명령은 [IPHONE.md](IPHONE.md)에 정리했다. Xcode/기기 서명 설정이 끝나면 `./tools/run-iphone.sh <기기ID>`로 release 앱을 설치한다.

현재 Mac의 **Xcode 27.1과 iOS SDK 27.1에서 release 네이티브 컴파일(서명 제외)을 성공**했다. 이후 개인 Team으로 서명해 iPhone 14 Pro(iOS 27.0.1)에 설치·실행하고 Mac 미러링 화면까지 확인했다. 실제 카메라·HF 모델 분석은 별도 검증 항목이다. Android SDK가 없어 APK는 빌드하지 않았다. iOS 권한 선언과 카메라·앨범 진입 코드는 포함되어 있다.

1. [Flutter 공식 iOS 환경 설정](https://docs.flutter.dev/platform-integration/ios/setup)에 따라 Xcode와 iOS 플랫폼을 설치하고 최초 설정을 완료한다.
2. `./tools/flutter.sh doctor -v`로 도구 상태를 확인한다. 플러그인 빌드에서 CocoaPods가 요구되면 공식 안내대로 준비한다.
3. iPhone을 USB로 연결하고 기기 신뢰·개발자 모드를 설정한다. `./tools/flutter.sh devices`에서 기기 ID를 확인한다.
4. `open ios/Runner.xcworkspace`로 연 뒤 Runner의 Signing & Capabilities에서 본인의 Team을 선택한다. Bundle ID는 현재 `com.hankki.baeminFlutter`이며 필요하면 본인 계정에 맞게 바꾼다.
5. `./tools/flutter.sh run -d <기기ID>`로 설치한다. 설치·권한·촬영·로컬 저장을 실기기에서 확인한 뒤 iPhone Mirroring으로 발표한다.

이 작업에서 인증서/Apple 계정·배포 프로필을 만들거나 App Store/TestFlight에 업로드하지 않았다.

## 구현한 흐름

| 영역 | 구현 |
|---|---|
| 홈 | 캡처 카테고리·마트 아이콘, 치킨·피자·카페 등 전용 가게 목록/검색/정렬/필터, 배달·픽업 선택 → 가게 → 메뉴 상세 |
| 만보기 | 마이배민 프로필 아래 카드, iPhone Core Motion 걸음 수 연결, 오늘 목표·소비 열량 참고값, 픽업 부스터·중복 방지 보상, iOS 잠금화면·다이내믹 아일랜드 표시 |
| 장보기 | B마트·CU·GS25·동네마트, 카테고리·브랜드 필터, 배민이지 실제 캡처 상품 가로 목록, 상품 상세/담기 |
| 주문 | 메뉴/상품 상세 → 장바구니 → 쿠폰/수량/배달·픽업 → 요청사항/주문 → 상태 진행/취소 → 메뉴·결제·배달·영양 상세/리뷰 재조회 |
| 식사 기록 | 배달 완료와 섭취 확인을 구분, 먹은 날짜/분량 확인, 사진/수기 기록, 일별 총 열량 |
| 캘린더 | 주간 기본값, 월간 전환, 날짜 이동, 음식 사진/확인 열량, 미확인 주문/취소일 구분, 포인트·쿠폰·픽업 혜택 |
| 혜택 | 혜택 등장 모션, 예정/사용 상태, 대상 가게로 이동, 조건 충족 시 완료 후 한 번만 포인트 적립 |
| 맞춤 제안 | 기록된 탄단지 에너지 비중과 2025 KDRIs 일반 성인 범위 비교, 메뉴·레시피·국밥 제안 |
| 직접 만들기 | 추천과 관련 재료를 하나의 토글에 표시, 조리 단계는 자세히 보기로 확장, 재료 일괄 담기 |
| 찜/마이배민 | 찜 토글·가게 이동, 프로필·쿠폰함·포인트·리포트 회원 분기 |
| 저장 | 앱 전용 로컬 기록/장바구니 저장, 기존 웹 JSON 수동 가져오기, 원본 웹 기록 보존 |

화면은 현재 웹 디자인을 기반으로 이식했으나 픽셀 단위 동일성을 보증하지 않는다. Flutter의 시스템 상태바·키보드·날짜 선택기·화면 이동을 사용한다. 주소 변경/결제수단 등록/급식표/선물은 실제 서비스 연결이 없고 로컬 화면만 제공한다. 실제 배민 주문·결제·회원 가입·혜택 발급은 연동하지 않았다.

## 사진 분석

카메라·앨범에서 고른 사진은 먼저 앱 안에만 보관한다. 사용자가 사진 전송 동의와 `사진 분석`을 눌러야 분리된 분석 서버로 전송한다. 수기 입력은 서버 없이 가능하다.

분석 서버의 `/api/photo-analyze` 계약(`mode: huggingface`, `consent: true`)을 그대로 호출한다. HF 토큰은 앱에 넣지 않는다. 분석 서버에 HF_TOKEN이 없으면 자동 분석은 실패 안내를 표시하고 직접 입력을 제공한다. 임의의 영양값을 자동 분석 결과로 표시하지 않는다.

앱 폴더에서 별도 분석 서버를 실행한다:

```sh
(cd ../../services/nutrition-api && python3 -m nutrition_api)
```

API 기본 주소는 `127.0.0.1:4182`이며 `services/nutrition-api/nutrition_api/analysis.py`의 입력 검증·분석 함수를 사용한다. HF 토큰은 저장소 루트 기준 `services/nutrition-api/.env`에서 읽는다. Flutter 웹 미리보기 4181에만 CORS를 허용한다.

실기기에서 사진 분석이 필요할 때만 같은 Wi-Fi에서 다음과 같이 시작한다:

```sh
(cd ../../services/nutrition-api && python3 -m nutrition_api --host <Mac-LAN-IP>)
./tools/flutter.sh run -d <기기ID> --dart-define=ANALYSIS_BASE_URL=http://<Mac의LAN-IP>:4182
```

분석 API 접속 실패/권한 거절/유효하지 않은 영양값은 저장하지 않는다. 실기기에서 Mac 분석 API 연결은 확인했다. 실제 HF 추론은 402(크레딧/결제 제한) 응답으로 성공하지 않았고, iPhone 촬영/앨범 권한은 별도 검증 항목이다. 브리지 기본값은 루프백이며 실행 중인 서버를 외부에 공개하지 않는다.

## 웹 기록을 앱으로 가져오기

기본 데이터는 웹 소스의 `initialState()`이며, 현재 열려 있는 브라우저 저장 내용은 자동으로 읽지 않는다. 기존 웹 기록을 가져오려면 브라우저 개발자 도구에서 아래 값을 복사해 앱의 **마이배민 → 설정 → 기록 가져오기**에 붙여넣는다.

```js
localStorage.getItem('baemin-order-calendar-mock-v1')
```

가져오기는 Flutter 앱의 기록을 교체하며 웹 기록은 변경하지 않는다. 웹과 앱 사이에 실시간 동기화는 없다. 공개 카탈로그를 다시 복사하려면 `node tools/export_web_seed.mjs`를 실행한다. 이미 저장된 앱 기록은 이 명령으로 변경되지 않는다.

## 파일과 검증

- `lib/main.dart`: 초기화·앱 실행
- `lib/app/`: 테마·최상위 탭 이동·공통 만보기 수명 관리
- `lib/features/home`, `shopping`, `favorites`, `profile`: 홈·장보기·찜·마이배민 독립 화면
- `lib/core/state/app_store.dart`: 주문/쿠폰/포인트/기록/저장/영양 구성 계산
- `lib/core/network/analysis_service.dart`: 분석 API 계약
- `lib/features/catalog/presentation/`: 가게 목록·검색·필터
- `lib/features/orders/presentation/`: 가게·상품·주문/리뷰 화면
- `lib/features/nutrition/presentation/`: 리포트·추천·직접 만들기·레시피
- `lib/features/food_record/application/`: 분석 요청·섭취량·편집·저장 상태
- `lib/features/food_record/presentation/`: 음식 촬영·등록
- `lib/features/walking/presentation/`: 만보기 화면·iOS 이벤트 연동
- `lib/shared/widgets/`: 공통 UI·이미지·다이얼로그
- `assets/SOURCES.md`: 이미지·데이터·글꼴 출처
- `qa/VALIDATION.md`: 실행한 검증과 확인하지 못한 범위
- `qa/PARITY.md`: 기존 웹과 비교해 보완한 차이 및 실제 화면 증거

```sh
./tools/flutter.sh test
./tools/analyze.sh
./tools/flutter.sh build web --release
```

이 SDK의 `flutter analyze`는 한글 경로의 LSP 초기 메시지에서 길이 오류가 발생했다. 동일 Dart 분석기를 직접 실행하는 `dart analyze`로 정적 검증했다. 프로젝트를 옮길 경우 `pub get`을 다시 실행한다. 테스트 PNG는 실제 Flutter 위젯을 렌더한 결과이며 iPhone 실기기 스크린샷은 아니다.

### 메뉴 데이터 갱신

- 번들 데이터는 `assets/seed.json`, 원본 웹과 다른 추가·보정값은 `data/catalog-updates.json`에서 관리한다. `tools/export_web_seed.mjs`는 두 내용을 병합한다.
- 현재 원격 카탈로그 서버는 없다. 메뉴 추가·영양값 수정도 웹 재빌드 또는 iOS 재빌드·재설치가 필요하다. 세부 제공량·출처·기존 기록 보존 기준은 [영양값·가게 추가 검증](qa/NUTRITION-CATALOG-2026-10-29.md)에 기록했다.

## 화면 분리·사진 분석 후속

분석 성공 후 사진 속 음식 전체를 기준으로 25/50/75/100% 섭취량을 선택하고 영양값을 수정할 수 있습니다. 저장 기록은 원본 분석값·모델·섭취 비율·수정 여부를 보존합니다. 사진을 바꾸면 이전 값과 전송 동의를 초기화하고, 오래된 분석 응답은 무시합니다. 실제 HF 계정 한도와 코드 검증은 [후속 검증 기록](qa/SCREENS-PHOTO-2026-11-04.md)에 구분했습니다.
