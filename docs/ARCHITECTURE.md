# 저장소 구조와 변경 기준

## 실행 단위

| 경로 | 책임 | 독립 실행 |
|---|---|---|
| `apps/mobile` | Flutter 앱·플랫폼 연동·번들 데이터 | Flutter 도구 |
| `apps/web` | 기존 웹 UI·가상 주문·웹 정적 서버 | `python3 server.py` |
| `apps/legacy-web` | 초기 음식 기록 웹 보관 | Python 정적 서버 |
| `services/nutrition-api` | 사진 분석 HTTP API·모델 호출·비밀키 | `python3 -m nutrition_api` |
| `docs` | 구조·변경·검증 설명 | 해당 없음 |

## 의존 방향

- Flutter `main.dart` → `app` → 기능 화면(`features`) → 공통 상태/네트워크(`core`), 공통 UI(`shared`).
- `core`는 기능 화면을 가져오지 않는다. `shared`는 기능 화면에 의존하지 않는다.
- Flutter가 분석 서버에 의존하는 방식은 HTTP 계약이다. 앱 실행에 서버 소스가 필요하지 않고 비밀키도 포함하지 않는다.
- Python `nutrition_api.server` → `nutrition_api.analysis`. 분석 서버는 앱이나 웹 소스를 가져오지 않는다.
- 웹 `server.py` → 공통 `nutrition_api.analysis`. 기존 웹의 동일 출처 API를 유지하기 위한 진입점이다.
- `apps/mobile/tools/export_web_seed.mjs`는 개발 시에만 `apps/web`의 공개 카탈로그를 읽고 모바일 보정 데이터를 병합한다. 이 명령은 명시적으로 실행한다. 실행 중인 앱의 저장 데이터와 자동 동기화하지 않는다.

## Flutter 내부

기능은 `home`, `shopping`, `favorites`, `orders`, `profile`, `catalog`, `nutrition`, `food_record`, `walking`으로 나눈다. 각 기능의 화면은 `presentation`에 둔다. 공통 상태는 기존 `AppStore`를 `core/state`에 유지한다. 실제 서버 저장·계정 동기화가 없는 현재 프로토타입에 비어 있는 repository/use-case 계층을 만들지는 않는다.

`app/home_shell.dart`는 하단 탭 이동, 장보기 진입 요청, 공통 만보기 센서의 시작·종료만 맡는다. 다섯 탭은 독립된 StatefulWidget이며 IndexedStack으로 검색·서비스 필터·스크롤 수명을 관리한다. 홈과 장보기의 검색은 탭을 떠날 때 초기화하고, 찜과 주문내역의 배달/장보기 선택은 서로 독립적이다.

캘린더는 `orders/presentation/widgets/meal_calendar.dart`, 직접 먹은 음식 카드는 `recorded_food_card.dart`로 분리했다. 홈/장보기에서 사용하는 상품 그리드·브랜드 아이콘·가게 행은 `catalog/presentation/widgets`에 둔다. 헤더·서비스 탭·스크롤 틀은 `shared/widgets/tab_page.dart`에서 콜백을 받아 사용하며 기능 화면을 직접 가져오지 않는다.

사진 등록은 `food_record/application/photo_record_controller.dart`가 분석 요청 상태·오래된 응답 무시·섭취량·편집·저장을 관리하고 `presentation/photo_screen.dart`는 입력과 화면 이동을 맡는다. 전역 주문/기록 상태는 기존 AppStore를 유지한다.

플랫폼 권한·Live Activity 코드는 Flutter 관례에 따라 `ios/`에 유지한다. 번들 데이터·이미지·폰트는 앱 `assets/`, 카탈로그 편집 원본은 `data/`, 앱 테스트는 `test/`, 변경 근거는 `qa/`에 둔다.

## 설정·개인 데이터

- 서버 비밀키: `services/nutrition-api/.env`만 사용. `.env.example`만 추적한다.
- 기존 로컬 `.env`는 내용 변경 없이 서버 폴더로 이동했다.
- 앱 저장 키·bundle ID·API 경로·포트·카탈로그 값은 유지한다. 폴더 이동으로 설치된 앱의 기록이 바뀌지 않는다.
- 원본 계정 캡처·연구 문서·인증서·빌드 산출물은 계속 Git에서 제외한다. UI에 필요한 가공 이미지와 출처 기록은 포함한다.
- 예전 폴더를 가리키는 실행 중 프로세스가 있으면 종료 후 `make web`, `make api`, `make mobile`로 다시 실행한다.
