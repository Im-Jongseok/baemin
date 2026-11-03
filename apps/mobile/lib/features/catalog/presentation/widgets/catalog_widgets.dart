import 'package:flutter/material.dart';
import 'package:baemin_flutter/core/state/app_store.dart';
import 'package:baemin_flutter/shared/widgets/ui.dart';
import 'package:baemin_flutter/features/orders/presentation/commerce.dart';

typedef MarketNavigator = void Function(String id, {String category});

class MarketLogos extends StatelessWidget {
  const MarketLogos({super.key, required this.onSelect});
  final MarketNavigator onSelect;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 19),
    child: Row(
      children: List.generate(5, (i) {
        const titles = ['B마트', 'CU', 'GS25', '동네마트', '과일·채소'],
            ids = ['bmart', 'cu-market', 'gs-market', 'fresh-market', 'all'];
        return Expanded(
          child: InkWell(
            onTap: () => onSelect(ids[i], category: i == 4 ? '과일·채소' : '전체'),
            child: Column(
              children: [
                if (i < 3)
                  assetIcon(
                    ['market-bmart', 'market-cu', 'market-gs'][i],
                    size: 58,
                  )
                else
                  Container(
                    height: 58,
                    width: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == 3 ? const Color(0xffe1f3dd) : surface,
                      shape: BoxShape.circle,
                    ),
                    child: i == 3
                        ? txt(
                            '싱싱',
                            size: 18,
                            color: const Color(0xff228335),
                            weight: FontWeight.w800,
                          )
                        : const Icon(Icons.apple, color: Colors.red, size: 36),
                  ),
                gap(6),
                txt(titles[i], size: 11, weight: FontWeight.w500),
              ],
            ),
          ),
        );
      }),
    ),
  );
}

class ProductGrid extends StatelessWidget {
  const ProductGrid({
    super.key,
    required this.store,
    required this.items,
    this.food = false,
  });
  final AppStore store;
  final List<Json> items;
  final bool food;
  AppStore get s => store;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 17),
    child: LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 18,
          mainAxisExtent:
              (constraints.maxWidth - 12) / 2 +
              125 * MediaQuery.textScalerOf(context).scale(1),
        ),
        itemBuilder: (ctx, i) {
          final m = items[i];
          return InkWell(
            onTap: () => food
                ? openShop(context, s, m['shopId'])
                : openItem(context, s, m['id']),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FoodImage(m, height: 200, radius: 12),
                      if (food)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 22,
                            alignment: Alignment.center,
                            color: purple,
                            child: txt(
                              '배달팁 0원',
                              size: 10,
                              color: Colors.white,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (!food)
                        Positioned(
                          right: 5,
                          bottom: 5,
                          child: IconButton.filledTonal(
                            onPressed: () => addItem(context, s, m['id']),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: ink,
                            ),
                            icon: const Icon(Icons.add),
                          ),
                        ),
                      if (m['pb'] == true)
                        Positioned(
                          left: 6,
                          top: 6,
                          child: pill(m['brand'] ?? 'PB'),
                        ),
                    ],
                  ),
                ),
                gap(6),
                txt(
                  s.shop(m['shopId'])['name'],
                  size: 10,
                  color: muted,
                  lines: 1,
                ),
                txt(m['name'], size: 13, weight: FontWeight.w600, lines: 2),
                txt(
                  '${m['discountPercent'] != null ? '${m['discountPercent']}% ' : ''}${won(m['price'])}',
                  size: 17,
                  color: m['discountPercent'] != null ? primary : ink,
                  weight: FontWeight.w800,
                ),
                txt(
                  food
                      ? '${shopSummary(s.shop(m['shopId']))} · ${s.shop(m['shopId'])['eta'] ?? '20~35분'}'
                      : '${m['unit']} · 배달팁 0원',
                  size: 10,
                  color: muted,
                  lines: 1,
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class ShopRow extends StatelessWidget {
  const ShopRow({super.key, required this.store, required this.shop});
  final AppStore store;
  final Json shop;
  AppStore get s => store;
  @override
  Widget build(BuildContext context) {
    final m = s.catalog.firstWhere((m) => m['shopId'] == shop['id']),
        favorite = (s.state['favorites'] as List).contains(shop['id']);
    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 10, 17, 16),
      child: InkWell(
        onTap: () => openShop(context, s, shop['id']),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FoodImage(m, width: 74, height: 74),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  txt(shop['name'], size: 16, weight: FontWeight.w800),
                  txt(shopSummary(shop), size: 12, color: muted),
                  txt(
                    '배달팁 0원',
                    size: 13,
                    color: purple,
                    weight: FontWeight.w700,
                  ),
                  txt(
                    '최소주문 ${won(shop['minOrder'])} · 픽업가능',
                    size: 11,
                    color: muted,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => s.favorite(shop['id']),
              icon: Icon(
                favorite ? Icons.favorite : Icons.favorite_border,
                color: favorite ? Colors.pink : muted,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
