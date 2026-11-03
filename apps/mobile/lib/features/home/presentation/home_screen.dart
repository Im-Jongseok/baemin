import 'package:flutter/material.dart';
import 'package:baemin_flutter/core/state/app_store.dart';
import 'package:baemin_flutter/shared/widgets/ui.dart';
import 'package:baemin_flutter/shared/widgets/tab_page.dart';
import 'package:baemin_flutter/features/orders/presentation/commerce.dart';
import 'package:baemin_flutter/features/catalog/presentation/widgets/catalog_widgets.dart';
import 'package:baemin_flutter/features/catalog/presentation/category_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.store,
    required this.onMarket,
    this.active = true,
  });
  final AppStore store;
  final MarketNavigator onMarket;
  final bool active;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final search = TextEditingController();
  String query = '', category = '전체';
  AppStore get s => widget.store;
  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active && oldWidget.active) {
      query = '';
      search.clear();
    }
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void pickupStores() => openFoodCategory(context, s, '전체', pickup: true);
  @override
  Widget build(BuildContext context) => Live(
    store: s,
    builder: (_) => TabPage(
      header: TabHeader(
        store: s,
        onCart: () => openCart(context, s),
        title: '우리집',
        background: const Color(0xffe8fbf6),
        search: search,
        hint: '덮밥? 볶음밥?',
        onSearch: (v) => setState(() => query = v),
      ),
      scrollKey: const PageStorageKey('home'),
      children: home(),
    ),
  );
  List<Widget> home() {
    final cats = [
      ...(s.seed['categories'] as List).skip(1),
      ['전체보기', '🍽️'],
    ];
    final available = s.catalog
        .where(
          (m) =>
              m['service'] != 'shopping' &&
              (category == '전체' ||
                  s.shop(m['shopId'])['category'] == category) &&
              (query.isEmpty ||
                  ('${m['name']}${s.shop(m['shopId'])['name']}').contains(
                    query,
                  )),
        )
        .toList();
    final shops = s.shops
        .where(
          (shop) =>
              shop['service'] != 'shopping' &&
              shop['open'] == true &&
              (category == '전체' || shop['category'] == category) &&
              (query.isEmpty ||
                  '${shop['name']} ${shop['category']} ${s.catalog.where((m) => m['shopId'] == shop['id']).map((m) => m['name']).join(' ')}'
                      .contains(query)),
        )
        .toList();
    final featured = category == '전체' && query.isEmpty
        ? shops
              .map(
                (shop) =>
                    available.firstWhere((m) => m['shopId'] == shop['id']),
              )
              .take(6)
              .toList()
        : available
              .where((m) => shops.any((shop) => shop['id'] == m['shopId']))
              .take(6)
              .toList();
    return [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 17),
        child: Row(
          children: ['음식배달', '픽업', '장보기·쇼핑', '선물하기', '혜택모아보기']
              .map(
                (label) => TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: ink,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: const RoundedRectangleBorder(),
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: () {
                    if (label == '픽업') {
                      pickupStores();
                    } else if (label == '장보기·쇼핑') {
                      widget.onMarket('all');
                    } else if (label == '혜택모아보기') {
                      couponsSheet(context, s);
                    } else if (label == '선물하기') {
                      couponsSheet(context, s);
                    } else {
                      openFoodCategory(context, s, '전체');
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: label == '음식배달' ? ink : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: txt(
                      label,
                      size: 15,
                      weight: label == '음식배달'
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.fromLTRB(17, 18, 17, 10),
        child: GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 10,
            mainAxisExtent: 88,
          ),
          itemCount: cats.length,
          itemBuilder: (ctx, i) {
            final raw = cats[i], name = (raw as List).first.toString();
            const captures = {
              '치킨': 'chicken',
              '카페·디저트': 'cafe',
              '피자': 'pizza',
              '찜·탕': 'stew',
              '돈까스·회': 'sushi',
              '패스트푸드': 'burger',
              '분식': 'snack',
            };
            return InkWell(
              onTap: () =>
                  openFoodCategory(context, s, name == '전체보기' ? '전체' : name),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(20),
                      border: category == name ? Border.all(color: mint) : null,
                    ),
                    child: captures[name] != null
                        ? assetIcon('category-${captures[name]}', size: 56)
                        : name == '한식'
                        ? FoodImage(
                            {'kind': 'bowl'},
                            height: 56,
                            width: 56,
                            radius: 20,
                          )
                        : name == '면요리'
                        ? FoodImage(
                            {'kind': 'noodles'},
                            height: 56,
                            width: 56,
                            radius: 20,
                          )
                        : assetIcon('category-single', size: 56),
                  ),
                  gap(5),
                  txt(name, size: 10, lines: 1),
                ],
              ),
            );
          },
        ),
      ),
      TextButton(
        onPressed: () => openFoodCategory(context, s, '전체'),
        child: txt('음식배달에서 더보기  ›', size: 12, weight: FontWeight.w700),
      ),
      sectionDivider(),
      MarketLogos(onSelect: widget.onMarket),
      sectionDivider(),
      Padding(
        padding: const EdgeInsets.all(17),
        child: InkWell(
          onTap: () => widget.onMarket('bmart'),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xffe5f7f0),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      txt(
                        '오늘의 한 끼를 준비하는 방법',
                        size: 11,
                        color: primary,
                        weight: FontWeight.w700,
                      ),
                      gap(7),
                      txt(
                        '신선한 재료로,\n우리 집이 맛집으로',
                        size: 21,
                        weight: FontWeight.w800,
                      ),
                      gap(8),
                      txt('장보기 둘러보기  ›', size: 12, color: primary),
                    ],
                  ),
                ),
                FoodImage(s.item('salmon'), height: 88, width: 88, radius: 44),
              ],
            ),
          ),
        ),
      ),
      sectionDivider(),
      sectionTitle(
        category == '전체' ? '지금 생각나는 한 그릇' : category,
        note: '배달팁 0원',
      ),
      ProductGrid(store: s, items: featured, food: true),
      sectionDivider(),
      sectionTitle('우리 동네 맛집', note: '${shops.length}개'),
      ...shops.map((shop) => ShopRow(store: s, shop: shop)),
    ];
  }
}
