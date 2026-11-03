import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:baemin_flutter/core/state/app_store.dart';
import 'package:baemin_flutter/shared/widgets/ui.dart';
import 'package:baemin_flutter/features/home/presentation/home_screen.dart';
import 'package:baemin_flutter/features/shopping/presentation/shopping_screen.dart';
import 'package:baemin_flutter/features/favorites/presentation/favorites_screen.dart';
import 'package:baemin_flutter/features/orders/presentation/order_history_screen.dart';
import 'package:baemin_flutter/features/profile/presentation/my_baemin_screen.dart';
import 'package:baemin_flutter/features/catalog/presentation/category_screen.dart';
import 'package:baemin_flutter/features/walking/presentation/walking.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store, this.initialTab = 0});
  final AppStore store;
  final int initialTab;
  @override
  State<HomeShell> createState() => _ShellState();
}

class _ShellState extends State<HomeShell> {
  late int tab = widget.initialTab;
  int marketRequest = 0;
  String marketStore = 'all', marketCategory = '전체';
  late final WalkingSync walking;
  AppStore get s => widget.store;
  @override
  void initState() {
    super.initState();
    walking = WalkingSync(
      s,
      onOpen: () => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        selectTab(4);
        Navigator.of(context).popUntil((route) => route.isFirst);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                WalkingScreen(store: s, sync: walking, onPickup: pickupStores),
          ),
        );
      }),
    )..start();
  }

  @override
  void dispose() {
    walking.dispose();
    super.dispose();
  }

  void pickupStores() => openFoodCategory(context, s, '전체', pickup: true);
  void selectTab(int value) => setState(() => tab = value);
  void toMarket(String id, {String category = '전체'}) => setState(() {
    tab = 1;
    marketStore = id;
    marketCategory = category;
    marketRequest++;
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    extendBody: true,
    backgroundColor: tab < 2 ? Colors.white : surface,
    body: SafeArea(
      bottom: false,
      child: IndexedStack(
        index: tab,
        children: [
          HomeScreen(store: s, onMarket: toMarket, active: tab == 0),
          ShoppingScreen(
            store: s,
            request: marketRequest,
            storeId: marketStore,
            category: marketCategory,
            active: tab == 1,
          ),
          FavoritesScreen(store: s),
          OrderHistoryScreen(
            store: s,
            onMarket: toMarket,
            onSelectTab: selectTab,
          ),
          MyBaeminScreen(
            store: s,
            walking: walking,
            onPickup: pickupStores,
            onSelectTab: selectTab,
          ),
        ],
      ),
    ),
    bottomNavigationBar: navigation(),
  );
  Widget navigation() {
    const names = ['홈', '장보기·쇼핑', '찜', '주문내역', '마이배민'],
        icons = [
          'nav-home',
          'nav-shopping',
          'nav-favorites',
          'nav-orders',
          'nav-my',
        ];
    return SafeArea(
      top: false,
      child: Container(
        height: 70,
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .82),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              padding: const EdgeInsets.all(5),
              child: Row(
                children: List.generate(5, (i) {
                  final active = tab == i;
                  return Expanded(
                    child: Semantics(
                      selected: active,
                      button: true,
                      label: names[i],
                      child: InkWell(
                        key: ValueKey('nav-$i'),
                        borderRadius: BorderRadius.circular(30),
                        onTap: () => selectTab(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            color: active
                                ? const Color(0xffe6e8e8).withValues(alpha: .85)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              assetIcon(
                                icons[i] +
                                    (active && [0, 3, 4].contains(i)
                                        ? '-active'
                                        : ''),
                                size: 30,
                              ),
                              txt(
                                names[i],
                                size: 10,
                                weight: active
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
