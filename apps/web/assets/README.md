# 캡처 기반 UI 에셋

> 현재 UI 아이콘은 `captured/`의 **원본 캡처 추출 PNG 25개**를 사용한다. 아래의 생성 에셋 기록은 이전 버전 및 시연 음식사진의 이력이다. 생성한 프로필 파일은 현재 UI에서 사용하지 않는다.

2026-10-26. 원본 iPhone Mirroring 캡처는 서버 폴더 밖에 유지한다. 공개 정적 경로에는 아래 결과물 두 장만 허용한다. 원본 닉네임·주문정보·연락처는 복사하지 않는다.

| 파일 | 제작 | 사용하는 곳 |
| --- | --- | --- |
| `profile-mascot.png` | P01 마이배민 캡처의 분홍 캐릭터만 대상으로 built-in image_gen에서 배경 제거 및 재구성. PNG alpha 유지. 원본 픽셀을 그대로 잘라낸 결과는 아님. | 마이배민 프로필 |
| `food-grid.png` | P09 찜 캡처를 음식사진 스타일 참고로 built-in image_gen에서 새로 제작. 2×2 순서: 비빔밥, 연어 포케, 국수, 치킨. | 메뉴·주문·캘린더·찜 썸네일 |

음식 사진은 시각 시연용이며 영양정보 분석의 입력이나 측정 근거가 아니다. 음식별 에셋은 CSS background-position으로 선택한다. 작은 탐색 아이콘은 캡처의 형태를 참고해 기존 SVG 코드에 맞춰 재작성했다.

## 사용한 프롬프트

### 음식 사진

Create a production UI food thumbnail contact sheet for a Korean Baemin-style local mock app. Reference image is only for food photography and food thumbnail visual style, not its UI or private contents. Output a square image split exactly into four equal square quadrants, no gutters, no text, no borders, no UI, no logos. Each quadrant has one realistic overhead food photograph filling the square, photographed like Korean delivery restaurant menu thumbnails. TOP LEFT: Korean vegetable bibimbap with egg and rice in dark bowl, TOP RIGHT: salmon poke rice bowl with cubed salmon greens avocado; BOTTOM LEFT: Korean janchi guksu thin noodles with broth vegetables and seaweed; BOTTOM RIGHT: crispy Korean fried chicken pieces in black plate. Warm appetizing photographic lighting, close food framing. All four food subjects fully inside their own quadrant, no overlap. These four independent quadrant photos will be used in CSS as individual menu images. Preserve exact 2x2 layout.

### 프로필 배경 제거

Edit target screenshot. Extract ONLY the small central pink cartoon profile avatar appearing above the Korean nickname: the pink dog-like Baemin profile mascot inside pale pink circular disc with white rim, black hand drawn face and two white/black sparkle shapes at top-left and bottom-right. Remove ALL surrounding UI, all text, nickname, gray background, phone frame, icons and screen elements. Output only that exact avatar illustration centered, tightly framed with a small transparent margin, on a truly transparent background. Preserve the mascot's original silhouette, colors, thick black outlines and sparkle shape as closely as possible. No redesign, no new text. This will be used as the profile avatar asset in a local mock app.

## 홈·장보기 확장 에셋

`commerce-grid.png`: built-in image_gen으로 만든 4×4 음식/상품 사진이다. CSS 위치로 각각 선택한다. 실제 가게의 판매 사진이나 영양 분석 근거가 아니다. 순서는 치킨/피자/버거/떡볶이, 돈까스/초밥/찌개/라떼·케이크, 사과/딸기/우유/계란, 상추/삼겹살/라면/크루아상이다. 메뉴별 사진은 대표 시연 이미지로 일부 메뉴가 같은 사진을 공유한다.

사용한 프롬프트:

A production image sprite sheet for a Korean food delivery and grocery shopping app. Exactly FOUR columns and FOUR rows of equal square photographic tiles, 16 tiles total, no gutters, no labels, no text, no logos. Entire image square, each object fits fully inside its own tile, consistent appetizing realistic commercial photography. Row1 from left: Korean crispy golden fried chicken in black bowl; pepperoni pizza top down; cheeseburger; tteokbokki rice cakes in red sauce. Row2: pork tonkatsu rice with cabbage; sliced salmon sushi nigiri platter; kimchi jjigae in black pot; iced latte with tiramisu cake. Row3: fresh red apples on pale background; fresh strawberries in clear tray; white milk carton with plain white label no letters; organic eggs in open cardboard carton. Row4: fresh green lettuce leaves; neatly sliced raw pork belly in tray; packaged Korean ramyeon noodles in plain orange packet without text; golden croissant bread on neutral plate. Food tiles row1 and row2 in warm restaurant style, grocery product tiles row3 row4 on soft cream studio background. Geometrically precise 4x4 grid layout. Individual tiles will be displayed via CSS background-position so exact equal size matters.

## 현재 적용: 원본 캡처에서 직접 추출

사용자 요청에 따라 생성 모델 없이 캡처를 좌표로 잘라 가공했다. `captured/manifest.json`에 원본 파일명·SHA-256·절단 좌표·처리 방식·출력 크기가 있다. 계정 전체 화면은 공개 정적 폴더에 복사하지 않는다.

- 하단 탐색: 기본 5개, 홈/주문내역/마이배민 선택 상태 3개.
- 상단: 고객센터·설정·검색·장바구니·알림 5개.
- 홈 음식 카테고리 8개, 매장 로고 3개, 원본 프로필 1개.
- 흑백 아이콘은 원본 형태를 유지하며 밝은 배경/색 번짐을 alpha로 제거하고 같은 48×48 캔버스에 중심 정렬.
- 장바구니는 원본 숫자 배지가 우측 상단 선을 가리고 있어, 배지 제거 후 생긴 빈 자국의 짧은 테두리만 선으로 복원했다. `extract_ui_assets.py`의 `badge-occlusion-repair` 처리이며 새 생성 이미지가 아니다.
- 컬러 카테고리·로고는 실제 색과 모양을 보존한 crop. 프로필은 화면 바탕과 가까운 색 중 가장자리에 연결된 부분만 제거.
- 하단 메뉴는 선택 여부에 따라 실제 기본/선택 PNG를 교체한다. 마이배민에 SVG 채움/흰색 선을 덮어쓰지 않는다.

추출 재실행: 기존 로컬 Pillow 환경에서 `python3 scripts/extract_ui_assets.py`. 서버 실행 자체에는 Pillow가 필요 없다.

[추출 결과 모음](../qa/captured-assets-contact.png) · [마이배민 화면](../qa/captured-my-screen.png) · [홈 화면](../qa/captured-home-screen.png)

## 첨부 캘린더 참고 이미지에서 절단한 혜택 아이콘

`captured/benefit-points.png`, `benefit-coupon.png`, `benefit-pickup.png`는 사용자가 2026-10-26 첨부한 `Screenshot 2026-10-26 at 7.46.19 AM.png`(476×512)에서 절단했다. 생성 모델을 사용하지 않았다. 배경 제거는 가장자리와 연결된 밝은 무채색 부분만 투명화하며 아이콘 내부는 보존했다. 원본 해시와 박스는 `captured/benefit-manifest.json`에 기록했다. 이 manifest와 원본 화면은 서버 PUBLIC에 포함하지 않는다.

## 볶음밥용 다짐 채소 사진

`chopped-vegetables.png`: 2026-10-26 imagegen 스킬의 built-in image_gen으로 새로 만든 단일 상품 사진. 양파·당근·애호박·대파를 작게 썰어 투명 용기에 담은 모습을 요청했다. 따뜻한 아이보리 배경, 라벨·글자·브랜드 없음. 현재 `pb-vegetables`에만 사용한다. 실제 PB 상품 촬영이나 영양 분석의 근거가 아니다. 원본 생성 결과를 변형 없이 프로젝트로 복사했다.

## 배민이지 두부 대표 이미지

`baemin-easy-tofu.png`: built-in image_gen으로 생성한 브랜드·문자가 없는 흰 두부 대표 사진이다. 실제 제품 포장 촬영이 아니며 상품의 실제 브랜드 디자인을 복제하지 않았다. 따뜻한 아이보리 배경과 흰 용기를 사용했다. 이미지 원본을 프로젝트로 복사해 사용한다. 우유 이미지는 아래 실제 캡처 사진으로 교체했다.


## 미러링에서 확보한 배민이지 실제 상품 사진

2026-10-26 사용자 허용 하에 iPhone Mirroring에서 관찰·캡처했다. 원본은 웹 루트 밖 `../baemin-private-evidence/2026-10-26-baemin-easy/`에 보관한다. 계정·주소·장바구니·구매 횟수가 포함된 전체 화면은 공개하지 않는다.

- `captured/easy-milk-observed.png`: E05-milk-detail 상품 사진 영역을 604×604로 절단했다.
- `captured/easy-sundae-observed.png`: E02-sundae-detail 상품 사진 영역을 604×604로 절단했다. 포인터 부분은 E01-search의 같은 상품 사진 픽셀로 보완했다.
- `captured/easy-pork-gukbap-observed.png`: E01-search 상품 타일을 원본 크기 231×231로 절단했다. 원래 타일의 프로모션 배지와 추가 버튼은 보존했다. 고해상도 상세 사진은 미확보다.

우유·순대국 사진 모서리의 공유 버튼과 프로모션 영역은 주변 배경을 보간하여 정리했다. 상품·음식 이미지를 생성하지 않았다. 정확한 절단 좌표·원본 및 출력 SHA-256·보정 범위는 비공개 `captured/easy-mirror-manifest.json`, 재현 코드는 `scripts/extract_baemin_easy_mirror.py`에 있다. 서버는 상품 PNG 3장만 제공하며 manifest·스크립트·원본을 제공하지 않는다.
