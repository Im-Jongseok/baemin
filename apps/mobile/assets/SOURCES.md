# Assets and data

- `captured/*.png`: existing web prototype server's explicit public asset allowlist only. The user authorized iPhone Mirroring capture/crop and reuse for this reconstruction. Private source screenshots, account details, raw evidence and hash manifests were not copied into app assets.
- `food/*.png`: deterministic square crops of the existing `food-grid.png` (2×2) and `commerce-grid.png` (4×4). No images are stretched. These representative food images retain the provenance of the web mock.
- `chopped-vegetables.png`, `baemin-easy-tofu.png`: existing web mock representative images. Tofu is not a verified product-pack photograph.
- `captured/easy-milk-observed.png`, `easy-sundae-observed.png`, `easy-pork-gukbap-observed.png`: actual observed Baemin Easy product photos from the 2026-10-26 mirroring session. Pork soup only has the 231px source tile, including its captured add control. Displayed product prices are snapshots, not a live API.
- `fonts/NotoSansKR.ttf`: Google Fonts Noto Sans KR, SIL Open Font License; `fonts/OFL.txt` is included in the app bundle. https://github.com/google/fonts/tree/main/ofl/notosanskr
- Launcher icons: composed from the captured order-history icon on a mint background; see `tools/make_app_icons.py`.
- `seed.json`: exported from the current web source catalog, recipes, nutrition reference and `initialState()` on 2026-10-26. This is the default fixture, not a dump of browser localStorage. The web's existing saved records are left untouched.
- Nutrition values in the default catalog are fixtures. Unknown actual PB-product labels stay null. PB grocery purchases never automatically become consumed meals. The 700g package weight is a sale quantity, not a recommended serving or nutrient measurement.
