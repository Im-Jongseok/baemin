#!/bin/sh
set -eu
if command -v flutter >/dev/null 2>&1; then
  exec flutter "$@"
elif [ -x "$HOME/.cache/baemin-flutter-sdk/bin/flutter" ]; then
  exec "$HOME/.cache/baemin-flutter-sdk/bin/flutter" "$@"
fi
printf '%s\n' 'Flutter SDK가 필요합니다: https://docs.flutter.dev/install/manual' >&2
exit 1
