#!/bin/sh
# Install the native release build after Xcode, signing and device trust are ready.
set -eu
cd "$(dirname "$0")/.."
# Use the installed full Xcode without changing global xcode-select or shell settings.
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app/Contents/Developer ]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  printf '%s\n' '전체 Xcode 설치와 최초 실행 설정이 필요합니다. IPHONE.md를 확인하세요.' >&2
  exit 1
fi
if ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
  printf '%s\n' 'Xcode를 열어 라이선스 확인 및 필수 구성요소 설치를 직접 완료하세요.' >&2
  exit 1
fi
if [ "$#" -ne 1 ]; then
  printf '%s\n' '사용법: ./tools/run-iphone.sh <아이폰 기기 ID>' >&2
  ./tools/flutter.sh devices
  exit 2
fi

# A phone's loopback address is not this Mac. Default to the current Wi-Fi address.
if [ -z "${ANALYSIS_BASE_URL:-}" ]; then
  baemin_server_ip=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)
  if [ -n "$baemin_server_ip" ]; then
    ANALYSIS_BASE_URL="http://$baemin_server_ip:4182"
  fi
fi
if [ -n "${ANALYSIS_BASE_URL:-}" ]; then
  exec ./tools/flutter.sh run --release -d "$1" --dart-define="ANALYSIS_BASE_URL=$ANALYSIS_BASE_URL"
fi
exec ./tools/flutter.sh run --release -d "$1"
