.PHONY: help mobile web legacy-web api test test-mobile test-web test-api analyze build-web export-catalog

help:
	@echo 'make mobile        Flutter 웹 개발 (4181)'
	@echo 'make web           기존 웹 목업 (4180)'
	@echo 'make legacy-web    초기 음식 기록 웹 (4173)'
	@echo 'make api           사진 분석 API (4182)'
	@echo 'make test          앱·웹·서버 테스트'
	@echo 'make analyze       Dart 정적 분석'
	@echo 'make build-web     Flutter 웹 release 빌드'
	@echo 'make export-catalog  웹 카탈로그를 Flutter 번들로 명시적 갱신'

mobile:
	cd apps/mobile && ./tools/flutter.sh run -d chrome --web-port 4181
web:
	cd apps/web && python3 server.py
legacy-web:
	python3 -m http.server 4173 --bind 127.0.0.1 --directory apps/legacy-web
api:
	cd services/nutrition-api && python3 -m nutrition_api

test: test-mobile test-web test-api
test-mobile:
	cd apps/mobile && ./tools/flutter.sh test
test-web:
	cd apps/web && node --test
test-api:
	cd services/nutrition-api && python3 -m unittest discover -s tests -v
analyze:
	cd apps/mobile && ./tools/analyze.sh
build-web:
	cd apps/mobile && ./tools/flutter.sh build web --release
export-catalog:
	node apps/mobile/tools/export_web_seed.mjs
