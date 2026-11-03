#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# Use Dart's analyzer directly; Flutter's LSP URI handling fails on this Korean workspace path.
if command -v dart >/dev/null 2>&1; then
  exec dart analyze "$@"
elif [ -x "$HOME/.cache/baemin-flutter-sdk/bin/dart" ]; then
  exec "$HOME/.cache/baemin-flutter-sdk/bin/dart" analyze "$@"
fi
printf '%s\n' 'Dart 분석을 실행하려면 Flutter SDK의 bin 경로를 PATH에 추가하세요.' >&2
exit 1
