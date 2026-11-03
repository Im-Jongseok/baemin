import 'package:flutter/material.dart';

import 'package:baemin_flutter/features/orders/presentation/commerce.dart';
import 'package:baemin_flutter/core/state/app_store.dart';
import 'package:baemin_flutter/shared/widgets/ui.dart';

void openFoodCategory(
  BuildContext context,
  AppStore store,
  String category, {
  bool pickup = false,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => FoodCategoryScreen(
        store: store,
        initialCategory: category,
        pickup: pickup,
      ),
    ),
  );
}

class FoodCategoryScreen extends StatefulWidget {
  const FoodCategoryScreen({
    super.key,
    required this.store,
    required this.initialCategory,
    this.pickup = false,
  });
  final AppStore store;
  final String initialCategory;
  final bool pickup;
  @override
  State<FoodCategoryScreen> createState() => _FoodCategoryState();
}

class _FoodCategoryState extends State<FoodCategoryScreen> {
  late String category = widget.initialCategory;
  late bool pickup = widget.pickup;
  String query = '', sort = '추천순';
  bool openOnly = false, highlyRated = false;
  final search = TextEditingController();
  final scroll = ScrollController();
  final selectedCategory = GlobalKey();
  AppStore get s => widget.store;
  @override
  void initState() {
    super.initState();
    revealCategory();
  }

  void revealCategory() => WidgetsBinding.instance.addPostFrameCallback((_) {
    final current = selectedCategory.currentContext;
    if (mounted && current != null) {
      Scrollable.ensureVisible(current, alignment: .3);
    }
  });
  @override
  void dispose() {
    search.dispose();
    scroll.dispose();
    super.dispose();
  }

  void choose(String name) {
    setState(() => category = name);
    revealCategory();
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) => Live(
    store: s,
    builder: (_) {
      final shops = s.shops
          .where(
            (shop) =>
                shop['service'] != 'shopping' &&
                (category == '전체' || shop['category'] == category) &&
                (!openOnly || shop['open'] == true) &&
                (!highlyRated || numOf(shop['rating']) >= 4.9) &&
                (query.trim().isEmpty ||
                    '${shop['name']} ${s.catalog.where((m) => m['shopId'] == shop['id']).map((m) => m['name']).join(' ')}'
                        .toLowerCase()
                        .contains(query.trim().toLowerCase())),
          )
          .toList();
      shops.sort((a, b) {
        final availability = (b['open'] == true ? 1 : 0).compareTo(
          a['open'] == true ? 1 : 0,
        );
        if (availability != 0) return availability;
        return sort == '별점 높은 순'
            ? numOf(b['rating']).compareTo(numOf(a['rating']))
            : sort == '최소주문 낮은 순'
            ? numOf(a['minOrder']).compareTo(numOf(b['minOrder']))
            : s.shops
                  .indexWhere((x) => x['id'] == a['id'])
                  .compareTo(s.shops.indexWhere((x) => x['id'] == b['id']));
      });
      return PageFrame(
        title: category == '전체' ? '음식배달' : category,
        actions: [
          IconButton(
            tooltip: '장바구니',
            onPressed: () => openCart(context, s),
            icon: Badge(
              isLabelVisible: s.cart.isNotEmpty,
              label: Text('${s.cart.values.fold(0, (a, b) => a + b)}'),
              child: assetIcon('cart'),
            ),
          ),
        ],
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 4, 17, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 18),
                        const SizedBox(width: 4),
                        txt('우리집 주변', weight: FontWeight.w700),
                      ],
                    ),
                  ),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: const [
                      ButtonSegment(value: false, label: Text('배달')),
                      ButtonSegment(value: true, label: Text('픽업')),
                    ],
                    selected: {pickup},
                    onSelectionChanged: (v) => setState(() => pickup = v.first),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 17),
              child: Row(
                children: (s.seed['categories'] as List)
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(right: 18),
                        child: InkWell(
                          onTap: () => choose(c[0]),
                          child: Container(
                            key: category == c[0] ? selectedCategory : null,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: category == c[0]
                                      ? ink
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: txt(
                              c[0],
                              size: 14,
                              weight: category == c[0]
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: category == c[0] ? ink : muted,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 12, 17, 4),
              child: TextField(
                controller: search,
                onChanged: (v) => setState(() => query = v),
                decoration: InputDecoration(
                  hintText: '$category 가게·메뉴 검색',
                  prefixIcon: const Icon(Icons.search, size: 22),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '검색어 지우기',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            search.clear();
                            setState(() => query = '');
                          },
                        ),
                  filled: true,
                  fillColor: surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: primary, width: 1),
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(17, 4, 17, 8),
              child: Row(
                spacing: 7,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      final selected = await sheet<String>(
                        context,
                        '가게 정렬',
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: ['추천순', '별점 높은 순', '최소주문 낮은 순']
                              .map(
                                (v) => ListTile(
                                  title: txt(v),
                                  trailing: sort == v
                                      ? const Icon(Icons.check, color: primary)
                                      : null,
                                  onTap: () => Navigator.pop(context, v),
                                ),
                              )
                              .toList(),
                        ),
                      );
                      if (selected != null && mounted) {
                        setState(() => sort = selected);
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        txt(sort, size: 12),
                        const Icon(Icons.expand_more, size: 17),
                      ],
                    ),
                  ),
                  FilterChip(
                    label: txt(
                      '영업 중',
                      size: 12,
                      color: openOnly ? Colors.white : ink,
                    ),
                    selected: openOnly,
                    onSelected: (v) => setState(() => openOnly = v),
                  ),
                  FilterChip(
                    label: txt(
                      '별점 4.9+',
                      size: 12,
                      color: highlyRated ? Colors.white : ink,
                    ),
                    selected: highlyRated,
                    onSelected: (v) => setState(() => highlyRated = v),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (category == '패스트푸드')
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(17, 10, 17, 8),
                child: Row(
                  spacing: 7,
                  children: [
                    for (final brand in [
                      '전체 브랜드',
                      ...s.shops
                          .where((shop) => shop['category'] == '패스트푸드')
                          .map((shop) => shop['brand'])
                          .whereType<String>()
                          .toSet(),
                    ])
                      ChoiceChip(
                        label: Text(brand),
                        selected: brand == '전체 브랜드'
                            ? query.isEmpty
                            : query == brand,
                        onSelected: (_) {
                          search.text = brand == '전체 브랜드' ? '' : brand;
                          setState(() => query = search.text);
                          if (scroll.hasClients) scroll.jumpTo(0);
                        },
                      ),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(17, 18, 17, 28),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: txt(
                          pickup ? '가까운 가게에서 직접 픽업' : '오늘은 $category 어때요?',
                          size: 20,
                          weight: FontWeight.w800,
                        ),
                      ),
                      txt('${shops.length}개', size: 12, color: muted),
                    ],
                  ),
                  gap(16),
                  if (shops.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Column(
                        children: [
                          const Icon(Icons.search_off, size: 42, color: muted),
                          gap(),
                          txt('조건에 맞는 가게가 없어요', weight: FontWeight.w700),
                          gap(),
                          actionButton('필터 초기화', () {
                            search.clear();
                            setState(() {
                              query = '';
                              openOnly = false;
                              highlyRated = false;
                            });
                          }, secondary: true),
                        ],
                      ),
                    ),
                  ...shops.map((shop) => storeCard(shop)),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget storeCard(Json shop) {
    final menu = s.catalog.firstWhere((m) => m['shopId'] == shop['id']);
    final favorite = (s.state['favorites'] as List).contains(shop['id']);
    final coupons = s.coupons
        .where(
          (c) => c['shopId'] == shop['id'] && s.couponStatus(c) == 'available',
        )
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              s.fulfillment = pickup ? 'pickup' : 'delivery';
              s.save();
              openShop(context, s, shop['id']);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Opacity(
                      opacity: shop['open'] == true ? 1 : .45,
                      child: FoodImage(
                        menu,
                        width: double.infinity,
                        height: 172,
                        radius: 16,
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: pill(
                        shop['open'] == true
                            ? (pickup ? '픽업 가능' : '배달팁 0원')
                            : '지금은 준비 중',
                        bg: Colors.white,
                        color: shop['open'] == true ? ink : muted,
                      ),
                    ),
                    if (shop['open'] != true)
                      Positioned.fill(
                        child: Center(
                          child: pill('영업 준비 중', bg: ink, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                gap(9),
                Row(
                  children: [
                    Expanded(
                      child: txt(
                        shop['name'],
                        size: 20,
                        weight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      tooltip: favorite ? '찜 해제' : '가게 찜하기',
                      onPressed: () => s.favorite(shop['id']),
                      icon: Icon(
                        favorite ? Icons.favorite : Icons.favorite_border,
                        color: favorite ? Colors.pink : muted,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (shop['rating'] is num) ...[
                      const Icon(
                        Icons.star,
                        size: 17,
                        color: Color(0xffffb900),
                      ),
                      const SizedBox(width: 3),
                      txt('${shop['rating']}', weight: FontWeight.w700),
                    ] else
                      txt(shop['category'], weight: FontWeight.w700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: txt(
                        pickup ? '가게에서 직접 받아요' : shop['eta'] ?? '20~35분',
                        size: 13,
                        color: muted,
                      ),
                    ),
                  ],
                ),
                gap(4),
                txt(
                  '${numOf(shop['minOrder']) > 0 ? '최소주문 ${won(shop['minOrder'])} · ' : ''}${menu['name']}',
                  size: 12,
                  color: muted,
                ),
                if (coupons.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: pill(
                      '보유 쿠폰 · ${coupons.first['title']}',
                      color: purple,
                      bg: const Color(0xfff0eaff),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
