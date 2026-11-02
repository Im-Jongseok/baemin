#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
./tools/flutter.sh build web --release
exec python3 -m http.server 4181 --bind 127.0.0.1 --directory build/web
