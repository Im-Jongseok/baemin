import 'package:flutter/material.dart';
import 'package:baemin_flutter/core/state/app_store.dart';
import 'package:baemin_flutter/shared/widgets/ui.dart';
import 'package:baemin_flutter/shared/widgets/tab_page.dart';
import 'package:baemin_flutter/features/orders/presentation/commerce.dart';
import 'package:baemin_flutter/features/catalog/presentation/widgets/catalog_widgets.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({
    super.key,
    required this.store,
    required this.request,
    this.storeId = 'all',
    this.category = '전체',
    this.active = true,
  });
  final AppStore store;
  final int request;
  final String storeId, category;
  final bool active;
  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  final search = TextEditingController();
  String query = '';
  late String marketStore = widget.storeId, marketCategory = widget.category;
  AppStore get s => widget.store;
  void selectMarket(String id, {String category = '전체'}) => setState(() {
    marketStore = id;
    marketCategory = category;
  });
  @override
  void didUpdateWidget(covariant ShoppingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.request != oldWidget.request) {
      marketStore = widget.storeId;
      marketCategory = widget.category;
      query = '';
      search.clear();
    }
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

  @override
  Widget build(BuildContext context) => Live(
    store: s,
    builder: (_) => TabPage(
      header: TabHeader(
        store: s,
        onCart: () => openCart(context, s),
        title: '우리집',
        search: search,
        hint: '상품·가게를 검색해 보세요',
        onSearch: (v) => setState(() => query = v),
      ),
      scrollKey: const PageStorageKey('shopping'),
      children: shopping(),
    ),
  );
  List<Widget> shopping() {
    final categories = List<String>.from(s.seed['marketCategories']),
        list = rows(s.seed['products'])
            .where(
              (p) =>
                  (marketStore == 'all' || p['shopId'] == marketStore) &&
                  (marketCategory == '전체' ||
                      (marketCategory == '배민이지'
                          ? p['brand'] == '배민이지'
                          : p['category'] == marketCategory)) &&
                  (query.isEmpty || p['name'].toString().contains(query)),
            )
            .toList();
    return [
      InkWell(
        onTap: () => couponsSheet(context, s),
        child: Container(
          padding: const EdgeInsets.all(22),
          color: const Color(0xfff2eaff),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    txt(
                      '장보기·쇼핑 혜택',
                      size: 12,
                      color: primary,
                      weight: FontWeight.w700,
                    ),
                    gap(6),
                    txt('장보기 전에,\n받아둔 쿠폰부터', size: 24, weight: FontWeight.w800),
                    txt('보유 쿠폰 확인하기 ›', size: 12, color: primary),
                  ],
                ),
              ),
              assetIcon('benefit-coupon', size: 82),
            ],
          ),
        ),
      ),
      MarketLogos(onSelect: selectMarket),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 17),
        child: Row(
          children: categories
              .map(
                (c) => Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: ChoiceChip(
                    label: txt(
                      c,
                      size: 12,
                      color: marketCategory == c ? Colors.white : ink,
                    ),
                    selected: marketCategory == c,
                    selectedColor: ink,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => marketCategory = c),
                  ),
                ),
              )
              .toList(),
        ),
      ),
      sectionDivider(),
      sectionTitle(
        marketStore == 'all' ? '지금 주문하면 곧 도착' : s.shop(marketStore)['name'],
        note: '배달팁 0원',
      ),
      if (marketStore != 'all')
        TextButton(
          onPressed: () => setState(() => marketStore = 'all'),
          child: const Text('모든 가게 보기'),
        ),
      if (query.isEmpty &&
          marketCategory == '전체' &&
          ['all', 'bmart'].contains(marketStore))
        BaeminEasyRail(
          store: s,
          onBrowse: () => setState(() {
            marketStore = 'bmart';
            marketCategory = '배민이지';
          }),
        ),
      ProductGrid(store: s, items: list),
      sectionDivider(),
      sectionTitle('가까운 가게 둘러보기'),
      ...s.shops
          .where((shop) => shop['service'] == 'shopping')
          .map(
            (shop) => ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              leading: shop['id'] == 'bmart'
                  ? assetIcon('market-bmart', size: 52)
                  : shop['id'] == 'cu-market'
                  ? assetIcon('market-cu', size: 52)
                  : shop['id'] == 'gs-market'
                  ? assetIcon('market-gs', size: 52)
                  : const Icon(Icons.shopping_bag_outlined, size: 40),
              title: txt(shop['name'], weight: FontWeight.w700),
              subtitle: txt('${shop['eta']} · 배달팁 0원', size: 12, color: muted),
              trailing: const Icon(Icons.chevron_right, color: muted),
              onTap: () => openShop(context, s, shop['id']),
            ),
          ),
    ];
  }
}
