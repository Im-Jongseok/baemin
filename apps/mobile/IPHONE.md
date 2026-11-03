# iPhone에 Flutter 앱 설치하기

기존 4180 웹과 4181 미리보기는 유지한다. 아래는 WebView나 홈 화면 웹 바로가기가 아닌 네이티브 Flutter 앱 설치 절차다.

## 이 Mac에서 확인한 상태 (2026-10-26)

- macOS 26.6.2 / Apple Silicon, 남은 저장 공간 약 208GiB.
- Flutter 3.47.8, iOS release 엔진/프로젝트/아이콘/카메라·사진 권한 문구 준비됨.
- CocoaPods 1.17.0 설치 완료.
- Xcode 27.1 / iOS SDK 27.1 설치 및 최초 설정 완료. 실행 스크립트는 `DEVELOPER_DIR`를 설정해 전역 도구 선택을 바꾸지 않는다.
- iOS 27.0.1 / iPhone 14 Pro 실기기에서 서명·설치·release 앱 실행과 Mac iPhone Mirroring 화면을 확인했다.
- 개인 개발 Team의 현재 프로비저닝 만료는 2026-11-02 21:14 KST다. 이후 사용에는 다시 빌드·설치가 필요하다.

## 최초 설정

1. App Store에서 Apple의 Xcode 설치를 완료한다. 계정 인증 또는 약관 동의는 소유자가 직접 진행한다.
2. Xcode를 최초 실행해 라이선스 확인과 필수 구성요소 설치를 완료한다. 설치 선택지가 나오면 iOS 플랫폼을 포함한다.
3. Terminal에서 활성 개발 도구를 선택한다. 관리자 암호는 직접 입력한다.

   ```sh
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   ```

4. iPhone을 USB로 Mac에 연결하고 잠금을 해제한다. 기기에서 ‘이 컴퓨터를 신뢰’를 선택한다.
5. iPhone의 설정 → 개인정보 보호 및 보안 → 개발자 모드를 켠 뒤 안내대로 재시동/확인한다. 항목이 없으면 먼저 Xcode에서 기기를 인식시킨다.
6. `ios/Runner.xcworkspace`를 Xcode로 열고 Runner → Signing & Capabilities에서 본인의 Team을 선택한다. 필요한 경우 Xcode의 Accounts에서 본인 Apple 계정으로 로그인한다. 별도 계정/인증서를 타인과 공유하지 않는다.
7. 현재 Bundle Identifier는 `com.hankki.baeminFlutter`다. 서명 충돌이 있을 때 본인 계정에서 사용 가능한 식별자로 바꾼다.

## 설치/실행

프로젝트 폴더에서 다음을 실행한다.

```sh
./tools/flutter.sh doctor -v
./tools/flutter.sh devices
./tools/run-iphone.sh <아이폰 기기 ID>
```

스크립트는 release 모드로 실행한다. 빌드·설치 후 Flutter 실행을 종료하고 iPhone 홈 화면에서 앱이 독립 실행되는지 확인한다. ‘확인되지 않은 개발자’ 안내가 나오면 기기의 설정 → 일반 → VPN 및 기기 관리에서 해당 본인 개발자 프로필을 확인한다.

## 사진 분석 서버

카메라/앨범·수동 기록·음식 기본값 선택은 앱에서 사용한다. 자동 사진 분석을 Mac의 기존 로컬 서버에 연결하려면 같은 네트워크의 Mac 주소를 빌드에 지정해야 한다. iPhone의 `127.0.0.1`은 Mac이 아니다.

```sh
# 서버는 이 Mac의 실제 LAN 주소에만 바인딩한다. 주소가 바뀌면 다시 확인한다.
(cd ../../services/nutrition-api && python3 -m nutrition_api --host <Mac의 LAN IP> --port 4182)
ANALYSIS_BASE_URL=http://<Mac의 LAN IP>:4182 ./tools/run-iphone.sh <아이폰 기기 ID>
```

분석 API는 `/api/photo-analyze`와 `/api/config` 두 경로만 제공한다. `services/nutrition-api`의 공통 사진·응답 검증 함수를 사용한다. 저장소 루트의 `services/nutrition-api/.env`에서 `HF_TOKEN`, `HF_MODEL_ID`를 매 요청 읽는다. 토큰은 앱이나 config 응답에 포함하지 않는다. 사진은 동의 후 분석 버튼을 눌러야 전송된다. 자세한 설정은 [HF-SETUP.md](HF-SETUP.md)에 기록했다.

## 미러링 시연 전 확인

만보기는 마이배민의 프로필 아래 카드에서 연다. `아이폰 걸음 수 연결`을 누른 뒤 운동 및 피트니스 권한을 허용하면 오늘의 걸음 수를 불러온다. 외부 API/HealthKit 권한은 필요 없다. 상세에서 ‘잠금화면에 걸음 수 표시’를 켜면 ActivityKit 라이브 액티비티를 시작한다. 잠금화면과 다이내믹 아일랜드에서 보인다. 앱 사용 중에는 Core Motion 걸음 이벤트를 받아 자동 반영하고, 복귀 시 오늘 누적 걸음을 조회한다. iOS가 앱 실행을 정지한 동안에는 갱신이 일시 중단된다. 웹의 3,665걸음은 미리보기 값이며 기기 측정과 구분한다.

앱 단독 실행, 홈에서 주문 → 상태 완료 → 섭취 확인 → 캘린더 반영, 주간/월간 리포트, 레시피 자세히 보기, 사진·앨범 권한을 실제 기기에서 확인한다. iPhone을 잠근 뒤 Mac의 iPhone Mirroring으로 앱을 열어 화면 크기와 스크롤도 확인한다. 최초 USB 신뢰/기기 설정 중에는 미러링 대신 실제 iPhone을 조작할 수 있다.

공식 참고: [Flutter iOS 설정](https://docs.flutter.dev/platform-integration/ios/setup), [Apple Xcode 시스템 요구사항](https://developer.apple.com/xcode/system-requirements).
