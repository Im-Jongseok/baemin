import 'package:flutter/material.dart';
import 'package:baemin_flutter/core/state/app_store.dart';
import 'package:baemin_flutter/shared/widgets/ui.dart';
import 'package:baemin_flutter/shared/widgets/tab_page.dart';
import 'package:baemin_flutter/features/orders/presentation/commerce.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, required this.store});
  final AppStore store;
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool shoppingFavorites = false;
  AppStore get s => widget.store;
  @override
  Widget build(BuildContext context) => Live(
    store: s,
    builder: (_) => TabPage(
      header: TabHeader(
        store: s,
        onCart: () => openCart(context, s),
        title: '찜',
      ),
      tabs: ServiceTabs(
        shopping: shoppingFavorites,
        onChanged: (v) => setState(() => shoppingFavorites = v),
      ),
      scrollKey: PageStorageKey('favorites-$shoppingFavorites'),
      children: favorites(),
    ),
  );
  List<Widget> favorites() {
    final favorites = s.shops
        .where(
          (shop) =>
              (s.state['favorites'] as List).contains(shop['id']) &&
              (shoppingFavorites
                  ? (shop['service'] == 'shopping')
                  : (shop['service'] != 'shopping')),
        )
        .toList();
    return [
      sectionTitle('찜한 가게 ${favorites.length}개'),
      ...favorites.map((shop) {
        final m = s.catalog.firstWhere((m) => m['shopId'] == shop['id']);
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 17,
            vertical: 12,
          ),
          leading: FoodImage(m, width: 72, height: 72),
          title: txt(shop['name'], size: 16, weight: FontWeight.w800),
          subtitle: txt(
            '${shopSummary(shop)}\n${shop['open'] == true ? '배달팁 0원' : '지금은 준비 중이에요'}',
            size: 12,
            color: muted,
          ),
          trailing: IconButton(
            onPressed: () => s.favorite(shop['id']),
            icon: const Icon(Icons.favorite, color: Colors.pink),
          ),
          onTap: () => openShop(context, s, shop['id']),
        );
      }),
    ];
  }
}
