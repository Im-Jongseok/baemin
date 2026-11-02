import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';

import 'store.dart';
import 'ui.dart';
import 'commerce.dart';
import 'nutrition.dart';
import 'photo.dart';
import 'category.dart';
import 'walking.dart';
import 'analysis_service.dart' show analysisBase, analysisConnection;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.load();
  final fontLicense = await rootBundle.loadString('assets/fonts/OFL.txt');
  LicenseRegistry.addLicense(
    () =>
        Stream.value(LicenseEntryWithLineBreaks(['Noto Sans KR'], fontLicense)),
  );
  runApp(BaeminApp(store: store));
}

class BaeminApp extends StatelessWidget {
  const BaeminApp({super.key, required this.store, this.initialTab = 0});
  final AppStore store;
  final int initialTab;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '한 끼 캘린더',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ko'),
    supportedLocales: const [Locale('ko'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansKR',
      scaffoldBackgroundColor: surface,
      colorScheme: ColorScheme.fromSeed(
        seedColor: mint,
        primary: primary,
        surface: Colors.white,
      ),
      dividerColor: const Color(0xffedf0ef),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          minimumSize: const Size(0, 40),
          tapTargetSize: MaterialTapTargetSize.padded,
          side: const BorderSide(color: Color(0xffe5e7e9)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: const BorderSide(color: Color(0xffe1e5e7)),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      textTheme: const TextTheme(bodyMedium: TextStyle(color: ink)),
      expansionTileTheme: const ExpansionTileThemeData(iconColor: primary),
    ),
    builder: (ctx, child) => ColoredBox(
      color: const Color(0xffeef1f3),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: kIsWeb ? 430 : 500),
          child: child,
        ),
      ),
    ),
    home: HomeShell(store: store, initialTab: initialTab),
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store, this.initialTab = 0});
  final AppStore store;
  final int initialTab;
  @override
  State<HomeShell> createState() => _ShellState();
}

class _ShellState extends State<HomeShell> {
  late int tab = widget.initialTab;
  String category = '전체',
      marketCategory = '전체',
      marketStore = 'all',
      query = '',
      filter = 'all';
  bool shoppingOrders = false, shoppingFavorites = false;
  bool get shoppingService => tab == 2 ? shoppingFavorites : shoppingOrders;
  void selectService(bool shopping) => setState(() {
    if (tab == 2) {
      shoppingFavorites = shopping;
    } else {
      shoppingOrders = shopping;
    }
  });
  final search = TextEditingController();
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

  void pickupStores() => openFoodCategory(context, s, '전체', pickup: true);
  Widget walkingCard() =>
      WalkingCard(store: s, sync: walking, onPickup: pickupStores);
  @override
  void dispose() {
    walking.dispose();
    search.dispose();
    super.dispose();
  }

  void selectTab(int value) {
    setState(() {
      tab = value;
      query = '';
      search.clear();
    });
  }

  void toMarket(String id) {
    setState(() {
      tab = 1;
      marketStore = id;
      marketCategory = '전체';
    });
  }

  @override
  Widget build(BuildContext context) => Live(
    store: s,
    builder: (ctx) => Scaffold(
      extendBody: true,
      backgroundColor: tab == 0 || tab == 1 ? Colors.white : surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            header(),
            if (tab == 3 || tab == 2)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 17),
                child: Row(
                  children: [
                    Expanded(
                      child: tabButton(
                        '배달·픽업',
                        !shoppingService,
                        () => selectService(false),
                      ),
                    ),
                    Expanded(
                      child: tabButton(
                        '장보기·쇼핑',
                        shoppingService,
                        () => selectService(true),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                key: ValueKey('tab-$tab-$shoppingService'),
                padding: const EdgeInsets.only(bottom: 110),
                children: tab == 0
                    ? home()
                    : tab == 1
                    ? shopping()
                    : tab == 2
                    ? favorites()
                    : tab == 3
                    ? orders()
                    : my(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: navigation(),
    ),
  );
  Widget header() {
    final home = tab < 2;
    return Container(
      color: tab == 4 ? surface : Colors.white,
      padding: const EdgeInsets.fromLTRB(17, 12, 17, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: txt(
                  home ? '우리집' : ['', '', '찜', '주문내역', '마이배민'][tab],
                  size: home ? 18 : 22,
                  weight: FontWeight.w800,
                ),
              ),
              if (home) pill('배민클럽', color: Colors.white, bg: ink),
              if (tab == 4) ...[
                IconButton(
                  onPressed: () => sheet(
                    context,
                    '고객센터',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        txt('무엇을 도와드릴까요?', size: 22, weight: FontWeight.w700),
                        gap(),
                        txt('주문 관련 문의는 주문내역에서 주문을 선택해 주세요.'),
                        actionButton('주문내역 보기', () {
                          Navigator.pop(context);
                          selectTab(3);
                        }, secondary: true),
                      ],
                    ),
                  ),
                  icon: assetIcon('headset'),
                ),
                IconButton(onPressed: settings, icon: assetIcon('settings')),
              ] else ...[
                if (home)
                  IconButton(
                    onPressed: () =>
                        sheet(context, '알림', txt('새로운 알림이 없어요.', color: muted)),
                    icon: assetIcon('bell'),
                  ),
                IconButton(
                  onPressed: () => openCart(context, s),
                  icon: Badge(
                    isLabelVisible: s.cart.isNotEmpty,
                    label: Text(
                      '${s.cart.values.fold<int>(0, (n, v) => n + v)}',
                    ),
                    child: assetIcon('cart'),
                  ),
                ),
              ],
            ],
          ),
          if (home) ...[
            gap(10),
            SizedBox(
              height: 45,
              child: TextField(
                controller: search,
                onChanged: (v) => setState(() => query = v),
                decoration: InputDecoration(
                  hintText: tab == 0 ? '덮밥? 볶음밥?' : '상품·가게를 검색해 보세요',
                  hintStyle: textStyle(14, muted),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.all(9),
                    child: assetIcon('search'),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: const BorderSide(color: ink),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget tabButton(String label, bool active, VoidCallback tap) => InkWell(
    onTap: tap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: active ? ink : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: Center(
        child: txt(
          label,
          size: 16,
          color: active ? ink : muted,
          weight: FontWeight.w700,
        ),
      ),
    ),
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

  Widget sectionTitle(String title, {String? note}) => Padding(
    padding: const EdgeInsets.fromLTRB(17, 20, 17, 12),
    child: Row(
      children: [
        Expanded(child: txt(title, size: 18, weight: FontWeight.w800)),
        if (note != null) txt(note, size: 11, color: muted),
      ],
    ),
  );
  Widget divider() => const Divider(height: 10, thickness: 10, color: surface);
  Widget marketLogos() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 19),
    child: Row(
      children: List.generate(5, (i) {
        const titles = ['B마트', 'CU', 'GS25', '동네마트', '과일·채소'],
            ids = ['bmart', 'cu-market', 'gs-market', 'fresh-market', 'all'];
        return Expanded(
          child: InkWell(
            onTap: () {
              toMarket(ids[i]);
              if (i == 4) {
                setState(() => marketCategory = '과일·채소');
              }
            },
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
                  onPressed: () {
                    if (label == '픽업') {
                      pickupStores();
                    } else if (label == '장보기·쇼핑') {
                      toMarket('all');
                    } else if (label == '혜택모아보기') {
                      couponsSheet(context, s);
                    } else if (label == '선물하기') {
                      couponsSheet(context, s);
                    } else {
                      openFoodCategory(context, s, '전체');
                    }
                  },
                  child: txt(label, size: 15, weight: FontWeight.w700),
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
      divider(),
      marketLogos(),
      divider(),
      Padding(
        padding: const EdgeInsets.all(17),
        child: InkWell(
          onTap: () => toMarket('bmart'),
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
      divider(),
      sectionTitle(
        category == '전체' ? '지금 생각나는 한 그릇' : category,
        note: '배달팁 0원',
      ),
      productGrid(featured, food: true),
      divider(),
      sectionTitle('우리 동네 맛집', note: '${shops.length}개'),
      ...shops.map(shopRow),
    ];
  }

  Widget productGrid(List<Json> items, {bool food = false}) => Padding(
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
      marketLogos(),
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
      divider(),
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
      productGrid(list),
      divider(),
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

  Widget shopRow(Json shop) {
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

  List<Widget> orders() {
    if (shoppingOrders) {
      final list = s.orders.where((o) => o['service'] == 'shopping').toList();
      return [
        sectionTitle('장보기·쇼핑 주문내역'),
        ...list.map(orderCard),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.all(50),
            child: txt('아직 장보기 주문내역이 없어요.', color: muted),
          ),
      ];
    }
    final list = s.orders
            .where(
              (o) =>
                  o['service'] != 'shopping' &&
                  orderDay(o) == s.selected &&
                  filter != 'photo',
            )
            .toList(),
        photos = s
            .dayRecords(s.selected, filter)
            .where((r) => r['orderId'] == null)
            .toList(),
        meals = s.dayRecords(s.selected, filter),
        total = s.totals(meals),
        day = parseDay(s.selected);
    return [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(17, 8, 17, 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: 7,
            children: [
              OutlinedButton.icon(
                onPressed: orderSearch,
                icon: const Icon(Icons.search, size: 16),
                label: txt('검색', size: 12),
              ),
              OutlinedButton(
                onPressed: () =>
                    showDatePicker(
                      context: context,
                      initialDate: day,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    ).then((d) {
                      if (d != null) {
                        s.choose(dateKey(d));
                      }
                    }),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    txt('조회 기간', size: 12),
                    const Icon(Icons.keyboard_arrow_down, size: 16),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => sheet(
                  context,
                  '주문 상태·정보',
                  Column(
                    children: statusLabels.entries
                        .map(
                          (e) => ListTile(
                            title: Text(e.value),
                            onTap: () {
                              Navigator.pop(context);
                              sheet(
                                context,
                                e.value,
                                Column(
                                  children: s.orders
                                      .where((o) => o['status'] == e.key)
                                      .map(
                                        (o) => ListTile(
                                          title: Text(o['shopName']),
                                          subtitle: Text(orderDay(o)),
                                          onTap: () {
                                            Navigator.pop(context);
                                            openOrder(context, s, o['id']);
                                          },
                                        ),
                                      )
                                      .toList(),
                                ),
                              );
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    txt('주문 상태·정보', size: 12),
                    const Icon(Icons.keyboard_arrow_down, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      divider(),
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(17, 14, 17, 8),
        child: Row(
          children: ['all', 'delivery', 'photo']
              .map(
                (f) => Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: ChoiceChip(
                    label: txt(
                      {'all': '전체', 'delivery': '배달 주문', 'photo': '사진 기록'}[f]!,
                      size: 12,
                      color: filter == f ? Colors.white : ink,
                    ),
                    selected: filter == f,
                    selectedColor: ink,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => filter = f),
                  ),
                ),
              )
              .toList(),
        ),
      ),
      calendar(),
      gap(14),
      NutritionPreview(store: s, onRecord: () => daySheet(s.selected)),
      sectionTitle(
        '${day.month}월 ${day.day}일 ${['월', '화', '수', '목', '금', '토', '일'][day.weekday - 1]}요일',
        note: '${list.length + photos.length}개 내역',
      ),
      if (meals.isNotEmpty)
        panel(
          InkWell(
            onTap: () => daySheet(s.selected),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    txt(
                      '이날의 한 끼',
                      size: 15,
                      color: primary,
                      weight: FontWeight.w700,
                    ),
                    const Spacer(),
                    pill('${meals.length}끼'),
                  ],
                ),
                gap(12),
                txt('기록한 식사의 총 열량', size: 12, color: muted),
                txt(
                  '${number(numOf(total['calories']))} kcal',
                  size: 36,
                  color: primary,
                  weight: FontWeight.w800,
                ),
                gap(10),
                Row(
                  children: [
                    ...meals
                        .take(3)
                        .map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: FoodImage(
                              r,
                              width: 35,
                              height: 35,
                              radius: 18,
                            ),
                          ),
                        ),
                    const Spacer(),
                    txt('음식별 기록 보기 ›', size: 12, color: primary),
                  ],
                ),
              ],
            ),
          ),
          color: const Color(0xffe4faf2),
        ),
      ...list.map(orderCard),
      ...photos.map(
        (r) => panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FoodImage(r, width: 49, height: 49),
                  const SizedBox(width: 12),
                  Expanded(
                    child: txt(r['name'], size: 16, weight: FontWeight.w800),
                  ),
                  pill('기록 완료'),
                ],
              ),
              gap(),
              if (r['image'] != null)
                FoodImage(r, height: 210, width: double.infinity),
              gap(),
              txt(
                '${number(numOf(r['nutrition']['calories']))} kcal · 탄 ${decimal(numOf(r['nutrition']['carbs']))}g · 단 ${decimal(numOf(r['nutrition']['protein']))}g · 지 ${decimal(numOf(r['nutrition']['fat']))}g',
                size: 13,
              ),
            ],
          ),
        ),
      ),
      if (list.isEmpty && photos.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 45, horizontal: 20),
          child: Center(child: txt('이날의 주문·음식 기록이 없어요.', color: muted)),
        ),
    ];
  }

  Widget orderCard(Json o) {
    final status = o['status'],
        items = rows(o['items']),
        recorded = s.records.any((r) => r['orderId'] == o['id']);
    final record = s.recordedOrder(o['id']), review = s.reviewFor(o['id']);
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FoodImage(items.first, width: 50, height: 50),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    txt(o['shopName'], size: 16, weight: FontWeight.w800),
                    txt(
                      '${orderDay(o).substring(5).replaceAll('-', '.')} · ${o['fulfillment'] == 'pickup'
                          ? '픽업'
                          : o['service'] == 'shopping'
                          ? '장보기'
                          : '배달'}',
                      size: 11,
                      color: muted,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => openOrder(context, s, o['id']),
                child: txt('주문상세', size: 10),
              ),
            ],
          ),
          gap(18),
          txt(
            items.map((i) => '${i['name']} ${i['quantity']}개').join(' · '),
            size: 13,
          ),
          gap(20),
          const Divider(),
          Row(
            children: [
              txt(
                status == 'cancelled' ? '취소금액' : '결제금액',
                weight: FontWeight.w700,
              ),
              const Spacer(),
              const Icon(Icons.auto_awesome, size: 20, color: mint),
              txt(
                won(o['amount']['paid']),
                size: 20,
                color: purple,
                weight: FontWeight.w800,
              ),
            ],
          ),
          gap(16),
          if (status == 'delivered' && o['service'] == 'shopping')
            actionButton(
              '가게 둘러보기',
              () => openShop(context, s, o['shopId']),
              secondary: true,
            )
          else if (status == 'delivered') ...[
            actionButton(
              review == null ? '리뷰 쓰기' : '★ 내 리뷰 ${review['rating']}점 보기',
              () => reviewSheet(context, s, o),
              secondary: true,
            ),
            gap(8),
            Row(
              children: [
                Expanded(
                  child: actionButton(
                    '같은 메뉴 담기',
                    () => reorderItems(context, s, o),
                    secondary: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: actionButton(
                    '바로 주문',
                    () => reorderItems(context, s, o, goCart: true),
                  ),
                ),
              ],
            ),
            if (o['service'] != 'shopping') ...[
              gap(15),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        txt(
                          recorded ? '식사 기록 완료' : '이 주문을 한 끼로 남겨보세요',
                          size: 12,
                          color: const Color(0xff545c5d),
                          weight: FontWeight.w600,
                        ),
                        txt(
                          recorded
                              ? '${number(numOf(record?['nutrition']?['calories']))} kcal · ${record?['date']}'
                              : '먹은 날짜와 양을 확인해요',
                          size: 10,
                          color: muted,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => recorded
                        ? daySheet(record?['date'] ?? orderDay(o))
                        : consumeSheet(context, s, o),
                    child: txt(
                      recorded ? '기록 확인 ›' : '식사로 기록 ›',
                      size: 12,
                      color: primary,
                    ),
                  ),
                ],
              ),
            ],
          ] else if (status == 'cancelled')
            txt('전체 취소', color: muted)
          else
            actionButton(
              orderStatusLabel(o),
              () => openOrder(context, s, o['id']),
            ),
        ],
      ),
    );
  }

  Widget calendar() {
    final selected = parseDay(s.selected),
        monthly = s.state['view'] == 'month',
        start = monthly
            ? DateTime(selected.year, selected.month).subtract(
                Duration(
                  days: DateTime(selected.year, selected.month).weekday % 7,
                ),
              )
            : selected.subtract(Duration(days: selected.weekday % 7)),
        count = monthly
            ? (((DateTime(selected.year, selected.month + 1, 0).day +
                              DateTime(selected.year, selected.month).weekday %
                                  7) /
                          7)
                      .ceil() *
                  7)
            : 7;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(17, 12, 17, 16),
      child: Column(
        children: [
          Row(
            children: [
              txt('나의 한 끼 캘린더', weight: FontWeight.w800),
              const SizedBox(width: 6),
              pill('NEW'),
            ],
          ),
          gap(12),
          Row(
            children: [
              IconButton(
                onPressed: () => s.choose(
                  dateKey(
                    monthly
                        ? DateTime(
                            selected.year,
                            selected.month - 1,
                            selected.day.clamp(1, 28),
                          )
                        : selected.subtract(const Duration(days: 7)),
                  ),
                ),
                icon: const Icon(Icons.chevron_left, size: 22),
              ),
              txt(
                '${selected.year}년 ${selected.month}월',
                size: 17,
                weight: FontWeight.w800,
              ),
              IconButton(
                onPressed: () => s.choose(
                  dateKey(
                    monthly
                        ? DateTime(
                            selected.year,
                            selected.month + 1,
                            selected.day.clamp(1, 28),
                          )
                        : selected.add(const Duration(days: 7)),
                  ),
                ),
                icon: const Icon(Icons.chevron_right, size: 22),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => s.choose(todayKey()),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.all(4),
                  minimumSize: const Size(30, 30),
                ),
                child: txt('오늘', size: 10, color: muted),
              ),
              ...['month', 'week'].map(
                (v) => InkWell(
                  onTap: () => s.setView(v),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: s.state['view'] == v
                          ? surface
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: txt(
                      v == 'month' ? '월간' : '주간',
                      size: 10,
                      weight: s.state['view'] == v
                          ? FontWeight.w800
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          ),
          gap(10),
          Row(
            children: List.generate(
              7,
              (i) => Expanded(
                child: Center(
                  child: txt(
                    ['일', '월', '화', '수', '목', '금', '토'][i],
                    size: 10,
                    color: i == 0
                        ? Colors.redAccent
                        : i == 6
                        ? Colors.blueAccent
                        : muted,
                  ),
                ),
              ),
            ),
          ),
          gap(8),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 96,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
            ),
            itemCount: count,
            itemBuilder: (ctx, i) {
              final d = start.add(Duration(days: i)),
                  date = dateKey(d),
                  meals = s.dayRecords(date, filter),
                  benefits = s.benefits(date),
                  other = d.month != selected.month;
              final summary = s.calendarSummary(date, filter: filter),
                  cover = summary['cover'] as Json?,
                  b = other ? null : benefits.firstOrNull;
              return Semantics(
                button: true,
                label:
                    '$date ${meals.isEmpty ? (summary['unconfirmed'] == true ? '식사 확인' : '식사 미기록') : '${number(numOf(s.totals(meals)['calories']))} kcal'}${b == null ? '' : ', ${b['title']}'}',
                child: InkWell(
                  onTap: () {
                    s.choose(date);
                    if (cover == null && b != null) {
                      benefitSheet(date, b);
                    } else {
                      daySheet(date);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: other ? const Color(0xfffcfcfc) : Colors.white,
                      border: Border.all(
                        color: date == s.selected
                            ? mint
                            : const Color(0xffeef0f0),
                        width: date == s.selected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (cover != null) ...[
                          FoodImage(cover, height: 96, radius: 0),
                          Container(color: Colors.black.withValues(alpha: .45)),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (meals.isNotEmpty)
                                  txt(
                                    number(numOf(s.totals(meals)['calories'])),
                                    size: 17,
                                    color: Colors.white,
                                    weight: FontWeight.w800,
                                  ),
                                if (meals.isNotEmpty)
                                  txt(
                                    'kcal',
                                    size: 10,
                                    color: Colors.white,
                                    weight: FontWeight.w700,
                                  ),
                                if (meals.isEmpty)
                                  txt(
                                    '식사\n확인',
                                    size: 12,
                                    color: Colors.white,
                                    weight: FontWeight.w700,
                                  ),
                              ],
                            ),
                          ),
                          Positioned(
                            bottom: 6,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: meals
                                  .take(3)
                                  .map(
                                    (_) => Container(
                                      width: 6,
                                      height: 6,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 1.5,
                                      ),
                                      decoration: const BoxDecoration(
                                        color: mint,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ] else if (b != null) ...[
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 7),
                              child: calendarBenefitIcon(b, size: 43),
                            ),
                          ),
                          if (b['type'] != 'coupon')
                            Positioned(
                              bottom: 4,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: txt(
                                  '+${number(b['points'])}P',
                                  size: 10,
                                  color: primary,
                                  weight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                        if (summary['cancelled'] == true)
                          Center(child: txt('취소', size: 10, color: muted)),
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: date == todayKey()
                                  ? mint
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: txt(
                              '${d.day}',
                              size: 11,
                              color: date == todayKey()
                                  ? ink
                                  : cover != null
                                  ? Colors.white
                                  : other
                                  ? const Color(0xffbec3c5)
                                  : ink,
                              weight: date == todayKey()
                                  ? FontWeight.w800
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> daySheet(String date) async {
    final meals = s.dayRecords(date, filter),
        total = s.totals(meals),
        pending = s.orders
            .where(
              (o) =>
                  orderDay(o) == date &&
                  o['service'] != 'shopping' &&
                  o['status'] != 'cancelled' &&
                  !s.records.any((r) => r['orderId'] == o['id']),
            )
            .toList(),
        benefits = s.benefits(date),
        day = parseDay(date);
    await sheet(
      context,
      '${day.month}월 ${day.day}일의 한 끼',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (meals.isNotEmpty) ...[
            Row(
              children: [
                txt('확인한 식사 ${meals.length}끼', color: muted),
                const Spacer(),
                txt(
                  '${number(numOf(total['calories']))} kcal',
                  size: 26,
                  weight: FontWeight.w800,
                ),
              ],
            ),
            ...meals.map(
              (r) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: FoodImage(r, width: 48, height: 48),
                title: txt(r['name'], size: 13, weight: FontWeight.w700),
                subtitle: txt(
                  r['orderId'] == null ? '직접 먹은 음식' : '주문 음식 · 먹은 양 확인',
                  size: 10,
                  color: muted,
                ),
                trailing: txt(
                  '${number(numOf(r['nutrition']['calories']))} kcal',
                  size: 12,
                ),
              ),
            ),
          ] else ...[
            gap(16),
            Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 45,
                    color: Color(0xffb8cdc2),
                  ),
                  gap(12),
                  txt(
                    pending.isEmpty ? '이날의 첫 한 끼를 남겨보세요' : '주문한 한 끼를 기록해보세요',
                    size: 18,
                    weight: FontWeight.w700,
                  ),
                  txt('사진을 찍어 먹은 음식을 기록할 수 있어요.', size: 12, color: muted),
                ],
              ),
            ),
            gap(16),
          ],
          if (pending.isNotEmpty) ...[
            gap(),
            txt('먹은 양을 확인해 주세요', weight: FontWeight.w700),
            ...pending.map(
              (o) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: FoodImage(o['items'][0], width: 45, height: 45),
                title: txt(o['items'][0]['name'], size: 13),
                subtitle: txt(orderStatusLabel(o), size: 11, color: muted),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  o['status'] == 'delivered'
                      ? consumeSheet(context, s, o)
                      : openOrder(context, s, o['id']);
                },
              ),
            ),
          ],
          if (benefits.isNotEmpty) ...[
            gap(15),
            txt('이날의 혜택', size: 17, weight: FontWeight.w800),
            ...benefits.map(
              (b) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: calendarBenefitIcon(b, size: 50),
                title: txt(b['title'], weight: FontWeight.w700),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  benefitSheet(date, b);
                },
              ),
            ),
          ],
          gap(22),
          Center(
            child: Column(
              children: [
                IconButton.filled(
                  key: const ValueKey('calendar-camera'),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PhotoScreen(store: s, date: date),
                      ),
                    );
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: mint,
                    fixedSize: const Size(60, 60),
                  ),
                  icon: const Icon(
                    Icons.camera_alt_outlined,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
                gap(7),
                txt('음식 촬영·등록', size: 12, color: muted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> benefitSheet(String date, Json b) async {
    final future = date.compareTo(todayKey()) > 0,
        claimed = s.coupons.any((c) => c['id'] == b['id']),
        earned = rows(s.state['pointLedger'])
            .any((p) => p['benefitId'] == b['id']);
    await sheet(
      context,
      b['title'],
      Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: .3, end: 1),
            duration: const Duration(milliseconds: 650),
            curve: Curves.elasticOut,
            builder: (ctx, value, child) =>
                Transform.scale(scale: value, child: child),
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    b['type'] == 'coupon'
                        ? const Color(0xffeee1ff)
                        : const Color(0xffd7fff0),
                    Colors.white,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: calendarBenefitIcon(b, size: 130),
              ),
            ),
          ),
          gap(16),
          txt(
            earned
                ? '이미 챙긴 나의 혜택'
                : future
                ? '다가오는 한 끼의 혜택'
                : '오늘의 혜택을 찾았어요!',
            color: primary,
            weight: FontWeight.w700,
          ),
          gap(10),
          txt(
            b['type'] == 'coupon'
                ? (claimed ? '쿠폰함에 잘 보관했어요' : '장보기에 쓸 쿠폰이 있어요')
                : '${number(b['points'])}P ${earned ? '챙겼어요' : '받아요'}',
            size: 25,
            weight: FontWeight.w800,
          ),
          gap(),
          pill('$date${future ? ' 예정' : ''}', color: muted),
          gap(24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                txt('이렇게 사용할 수 있어요', weight: FontWeight.w700),
                gap(8),
                txt(b['description'], size: 13, color: muted),
                txt(
                  future ? '표시된 날짜에 혜택을 받을 수 있어요.' : '주문 완료 후 하루 한 번 적립해요.',
                  size: 12,
                  color: muted,
                ),
              ],
            ),
          ),
          gap(20),
          actionButton('주문하러 가기  ›', () {
            if (b['type'] == 'coupon' && !future) {
              s.claimCoupon(date);
            }
            Navigator.pop(context);
            if (b['type'] == 'coupon') {
              toMarket('bmart');
            } else {
              s.fulfillment = b['type'] == 'pickup' ? 'pickup' : 'delivery';
              s.save();
              selectTab(0);
            }
          }),
        ],
      ),
    );
  }

  List<Widget> my() {
    final favorites = s.shops
            .where(
              (shop) => (s.state['favorites'] as List).contains(shop['id']),
            )
            .toList(),
        available = s.coupons
            .where((c) => s.couponStatus(c) == 'available')
            .length;
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 17),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xffe8e9ec),
            borderRadius: BorderRadius.circular(22),
          ),
          child: txt('ⓘ 배민의 음식주문 경험, 어떠셨나요?', size: 11, color: muted),
        ),
      ),
      gap(25),
      Center(child: assetIcon('profile-mascot', size: 115)),
      gap(),
      Center(child: txt('민수', size: 22, weight: FontWeight.w800)),
      walkingCard(),
      panel(
        Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: txt('쿠폰함', weight: FontWeight.w800),
              trailing: txt('$available개', weight: FontWeight.w800),
              onTap: () => couponsSheet(context, s),
            ),
            InkWell(
              onTap: () => couponsSheet(context, s),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: purple,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: txt(
                  '받은 쿠폰을 한곳에서 확인해요',
                  size: 12,
                  color: const Color(0xffb9fff4),
                  weight: FontWeight.w700,
                ),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: txt('포인트', weight: FontWeight.w700),
              trailing: txt('${number(s.points)}원', weight: FontWeight.w800),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: txt('선물함', weight: FontWeight.w700),
              trailing: txt('0원', weight: FontWeight.w800),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: txt('배민페이', weight: FontWeight.w700),
              subtitle: txt('결제수단을 간편하게 관리해요', size: 12, color: muted),
              trailing: txt('결제수단 관리', size: 12),
              onTap: () =>
                  sheet(context, '배민페이', txt('저장된 결제수단이 없어요.', color: muted)),
            ),
          ],
        ),
      ),
      panel(
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: txt('우리 학교 급식표', weight: FontWeight.w800),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              sheet(context, '우리 학교 급식표', txt('등록된 급식표가 없어요.', color: muted)),
        ),
      ),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: txt('찜한 가게·상품', weight: FontWeight.w800),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => selectTab(2),
            ),
            Row(
              children: favorites.take(3).map((shop) {
                final m = s.catalog.firstWhere(
                  (m) => m['shopId'] == shop['id'],
                );
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () => openShop(context, s, shop['id']),
                    child: Column(
                      children: [
                        FoodImage(m, width: 80, height: 76),
                        txt(shop['name'], size: 10, color: muted),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      panel(
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: txt('나의 한 끼 기록', weight: FontWeight.w800),
          subtitle: txt('캘린더에서 기록한 식사를 확인해요', size: 12, color: muted),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => selectTab(3),
        ),
      ),
      panel(
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: txt('배민클럽', weight: FontWeight.w800),
          subtitle: txt(
            s.club ? '클럽 회원 전용 리포트를 확인해요' : '한 끼를 더 자세히 돌아보세요',
            size: 12,
            color: muted,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => sheet(
            context,
            '배민클럽',
            Column(
              children: [
                txt('식사 구성과 영양 정보를 더 자세히', size: 20, weight: FontWeight.w800),
                gap(18),
                actionButton(s.club ? '식습관 리포트 보기' : '배민클럽 시작하기', () {
                  s.state['membership'] = {'baeminClub': true};
                  s.save();
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ReportScreen(store: s)),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Future<void> orderSearch() async {
    final controller = TextEditingController();
    await sheet(
      context,
      '주문 검색',
      Column(
        children: [
          TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: '가게·메뉴 검색'),
            onChanged: (_) {},
          ),
          gap(),
          actionButton('검색', () {
            Navigator.pop(context);
            final matches = s.orders
                .where(
                  (o) =>
                      '${o['shopName']} ${rows(o['items']).map((i) => i['name']).join(' ')}'
                          .contains(controller.text),
                )
                .toList();
            sheet(
              context,
              '검색 결과',
              Column(
                children: matches
                    .map(
                      (o) => ListTile(
                        title: Text(o['shopName']),
                        subtitle: Text(
                          '${orderDay(o)} · ${o['items'][0]['name']}',
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          s.choose(orderDay(o));
                        },
                      ),
                    )
                    .toList(),
              ),
            );
          }),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> settings() async {
    await sheet(
      context,
      '설정',
      Column(
        children: [
          ListTile(
            title: txt('기록 가져오기'),
            subtitle: txt('기존 웹 기록 JSON을 붙여넣어요', size: 12, color: muted),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pop(context);
              importRecords();
            },
          ),
          ListTile(
            title: txt('사진 분석 연결'),
            subtitle: txt(analysisBase, size: 12, color: muted),
            trailing: const Icon(Icons.wifi_find),
            onTap: () async {
              Navigator.pop(context);
              try {
                final config = await analysisConnection();
                if (!mounted) return;
                toast(
                  context,
                  config['hfConfigured'] == true
                      ? '사진 분석 서버 연결됨 · Hugging Face 토큰 설정됨'
                      : '사진 분석 서버 연결됨 · Hugging Face 설정 필요',
                );
              } on StateError catch (e) {
                if (mounted) toast(context, e.message);
              }
            },
          ),
          if (s.lastError.isNotEmpty)
            txt(s.lastError, size: 12, color: Colors.redAccent),
        ],
      ),
    );
  }

  Future<void> importRecords() async {
    final controller = TextEditingController();
    await sheet(
      context,
      '기록 가져오기',
      Column(
        children: [
          txt('가져오면 앱의 현재 기록이 교체돼요. 웹 기록은 변경되지 않아요.', size: 12, color: muted),
          gap(),
          field(controller, '웹 기록 JSON', lines: 7),
          actionButton('기록 가져오기', () {
            try {
              final incoming = obj(jsonDecode(controller.text));
              s.restore(incoming);
              s.save();
              Navigator.pop(context);
              selectTab(3);
              toast(context, '기록을 가져왔어요.');
            } catch (_) {
              toast(context, '기록 JSON 형식을 확인해 주세요.');
            }
          }),
        ],
      ),
    );
    controller.dispose();
  }
}
