import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baemin_flutter/main.dart';
import 'package:baemin_flutter/store.dart';
import 'package:baemin_flutter/commerce.dart';
import 'package:baemin_flutter/nutrition.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final seed = obj(jsonDecode(File('assets/seed.json').readAsStringSync()));
  setUpAll(() async {
    final f = FontLoader('NotoSansKR')
      ..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'));
    await f.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final width in [360.0, 393.0, 430.0]) {
    for (final tab in [0, 1, 2, 3, 4]) {
      testWidgets(
        'tab $tab fits ${width.toInt()}px and renders captured assets',
        (tester) async {
          tester.view.physicalSize = Size(width, 932);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final boundary = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: BaeminApp(store: AppStore(seed), initialTab: tab),
            ),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final manifest = await AssetManifest.loadFromAssetBundle(
              rootBundle,
            );
            final context = boundary.currentContext!;
            for (final key in manifest.listAssets().where(
              (k) => k.endsWith('.png'),
            )) {
              await precacheImage(AssetImage(key), context);
            }
          });
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (width == 393) {
            await tester.runAsync(() async {
              final render =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await render.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final f = File('qa/flutter-tab-$tab.png');
              await f.parent.create(recursive: true);
              await f.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        },
      );
    }
  }
  testWidgets(
    'calendar entry opens camera registration and weekly mode is the default',
    (tester) async {
      tester.view.physicalSize = const Size(393, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = AppStore(seed);
      await tester.pumpWidget(BaeminApp(store: s, initialTab: 3));
      await tester.pumpAndSettle();
      expect(s.state['view'], 'week');
      expect(find.text('나의 한 끼 캘린더'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(RegExp('2026-10-26')).first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('calendar-camera')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('cart checkout creates an order and opens native order details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = AppStore(seed);
    s.addCart('salmon');
    await tester.pumpWidget(MaterialApp(home: CheckoutScreen(store: s)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('주문 완료하기'));
    await tester.pumpAndSettle();
    expect(find.text('주문상세'), findsOneWidget);
    expect(s.orders.first['items'][0]['menuId'], 'salmon');
    expect(s.orders.first['status'], 'pending');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'recipe and matching PB ingredients share a collapsed preparation section',
    (tester) async {
      tester.view.physicalSize = const Size(393, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = AppStore(seed);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Preparation(
                store: s,
                suggestion: {'target': 'recipe', 'id': 'pb-rice'},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('직접 만들어 먹기'), findsOneWidget);
      await tester.tap(find.text('직접 만들어 먹기'));
      await tester.pumpAndSettle();
      expect(find.text('이 레시피에 필요한 재료'), findsOneWidget);
      expect(find.text('PB 신선란'), findsOneWidget);
      expect(find.text('자세히 보기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'nutrition suggestions and detailed report render without hidden overflow',
    (tester) async {
      tester.view.physicalSize = const Size(393, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = AppStore(seed);
      s.state['membership'] = {'baeminClub': true};
      s.recordPhoto(
        name: '한 끼',
        date: s.selected,
        nutrition: {
          'calories': 1000,
          'carbs': 151,
          'protein': 34,
          'fat': 260 / 9,
        },
      );
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'NotoSansKR'),
            home: Scaffold(
              body: SingleChildScrollView(child: NutritionPreview(store: s)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('qa/flutter-suggestions.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(BaeminApp(store: s));
      await tester.pumpAndSettle();
      final ctx = tester.element(find.byType(HomeShell));
      Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => ReportScreen(store: s)),
      );
      await tester.pumpAndSettle();
      expect(find.text('식습관 리포트'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'order detail tabs reach payment and delivery and open an existing meal record',
    (tester) async {
      tester.view.physicalSize = const Size(360, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = AppStore(seed);
      s.addCart('salmon');
      final o = s.checkout(deliveryRequest: '벨 누르지 말아주세요');
      for (var i = 0; i < 3; i++) {
        s.advance(o['id']);
      }
      s.recordOrder(o['id'], s.selected, .5);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'NotoSansKR'),
            home: OrderScreen(store: s, id: o['id']),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('배달이 완료됐어요'), findsOneWidget);
      expect(find.textContaining('주문번호'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('qa/parity-order-widget.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.tap(find.widgetWithText(ChoiceChip, '결제 정보'));
      await tester.pumpAndSettle();
      expect(find.text('결제수단').hitTestable(), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, '배달 정보'));
      await tester.pumpAndSettle();
      expect(find.text('벨 누르지 말아주세요').hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.text('기록한 식사 확인'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('기록한 식사 확인'));
      await tester.pumpAndSettle();
      expect(find.text('식사 기록 완료'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'a benefit-only calendar date opens the reward and routes to shopping',
    (tester) async {
      tester.view.physicalSize = const Size(393, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = AppStore(seed);
      await tester.pumpWidget(BaeminApp(store: s, initialTab: 3));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(RegExp('2026-10-29')).first);
      await tester.pumpAndSettle();
      expect(find.text('장보기에 쓸 쿠폰이 있어요'), findsOneWidget);
      expect(find.byKey(const ValueKey('calendar-camera')), findsNothing);
      await tester.tap(find.text('주문하러 가기  ›'));
      await tester.pumpAndSettle();
      expect(find.text('모든 가게 보기'), findsOneWidget);
      expect(find.text('장보기 전에,\n받아둔 쿠폰부터'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'report recommendation anchors work offscreen and recipe steps expand',
    (tester) async {
      tester.view.physicalSize = const Size(360, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = AppStore(seed);
      s.recordPhoto(
        name: '식사',
        date: s.selected,
        nutrition: {
          'calories': 1000,
          'carbs': 151,
          'protein': 34,
          'fat': 260 / 9,
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'NotoSansKR'),
          home: ReportScreen(store: s),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('내게 맞춘 집밥 제안'));
      await tester.tap(find.text('내게 맞춘 집밥 제안'));
      await tester.pumpAndSettle();
      expect(find.text('직접 만들어 먹기').hitTestable(), findsOneWidget);
      await tester.tap(find.text('직접 만들어 먹기'));
      await tester.pumpAndSettle();
      expect(find.text('이 레시피에 필요한 재료'), findsOneWidget);
      await tester.ensureVisible(find.text('자세히 보기'));
      await tester.tap(find.text('자세히 보기'));
      await tester.pumpAndSettle();
      expect(find.text('맛있게 만드는 팁'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('home featured food opens its store before menu detail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = AppStore(seed);
    await tester.pumpWidget(BaeminApp(store: s));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -550));
    await tester.pumpAndSettle();
    await tester.tap(find.text('채소 비빔밥').first);
    await tester.pumpAndSettle();
    expect(find.byType(ShopScreen), findsOneWidget);
    expect(find.text('인기 메뉴'), findsOneWidget);
    await tester.ensureVisible(find.text('채소 비빔밥').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('채소 비빔밥').first);
    await tester.pumpAndSettle();
    expect(find.byType(ItemScreen), findsOneWidget);
    expect(find.text('메뉴 상세'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Mongchon menu opens with two servings and displays portion estimates',
    (tester) async {
      tester.view.physicalSize = const Size(393, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = AppStore(seed), boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: 'NotoSansKR'),
            home: ShopScreen(store: s, id: 'mongchon-dakgalbi'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final name in ['mongchon-herbal', 'mongchon-spicy']) {
          await precacheImage(
            AssetImage('assets/food/$name.webp'),
            boundary.currentContext!,
          );
        }
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('null'), findsNothing);
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('qa/mongchon-shop.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.tap(find.text('몽촌 한방 닭갈비').first);
      await tester.pumpAndSettle();
      expect(find.text('2개'), findsOneWidget);
      expect(find.text('주문 1개 전체 약 600 kcal'), findsOneWidget);
      final add = find.text('장바구니에 담기 · 34,000원');
      await tester.drag(find.byType(ListView).last, const Offset(0, -550));
      await tester.pumpAndSettle();
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(s.cart['mongchon-herbal'], 2);
      final order = s.checkout();
      s.advance(order['id']);
      s.advance(order['id']);
      s.advance(order['id']);
      consumeSheet(tester.element(find.byType(ShopScreen)), s, order);
      await tester.pumpAndSettle();
      expect(find.text('기록할 열량 약 600 kcal'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      await tester.tap(find.text('식사 기록 완료'));
      await tester.pumpAndSettle();
      expect(s.records.last['nutrition']['calories'], 600);
      expect(tester.takeException(), isNull);
    },
  );
}
