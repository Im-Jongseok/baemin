import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:baemin_flutter/category.dart';
import 'package:baemin_flutter/commerce.dart';
import 'package:baemin_flutter/main.dart';
import 'package:baemin_flutter/store.dart';
import 'package:baemin_flutter/walking.dart';
import 'package:baemin_flutter/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final seed = obj(jsonDecode(File('assets/seed.json').readAsStringSync()));
  AppStore fresh() {
    final s = AppStore(seed);
    s.state['orders'] = [];
    s.state['pointLedger'] = [];
    return s;
  }

  setUpAll(() async {
    await (FontLoader(
      'NotoSansKR',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  void phone(WidgetTester tester, [double width = 393]) {
    tester.view.physicalSize = Size(width, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> capture(
    WidgetTester tester,
    GlobalKey boundary,
    String name,
  ) async {
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('qa/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  test('walking rewards persist, claim only the new amount and cap at 10,000 steps', () {
    final s = fresh();
    s.updateWalking(
      3665,
      date: todayKey(),
      source: 'preview',
      previewBoost: true,
    );
    expect(s.walkingAvailable, 24);
    expect(s.claimWalkingReward(), 24);
    expect(s.claimWalkingReward(), 0);
    s.updateWalking(
      4000,
      date: todayKey(),
      source: 'preview',
      previewBoost: true,
    );
    expect(s.claimWalkingReward(), 8);
    s.updateWalking(
      20000,
      date: todayKey(),
      source: 'preview',
      previewBoost: true,
    );
    expect(s.claimWalkingReward(), 48);
    expect(s.walkingClaimed, 80);
    final restored = AppStore(seed)..restore({'state': s.state});
    expect(restored.walkingAvailable, 0);
    expect(restored.points, 80);
    restored.updateWalking(9999, date: '2020-01-01');
    expect(restored.walkingToday['steps'], 20000);
  });

  test('only a completed food pickup activates the walking booster', () {
    final s = fresh();
    s.updateWalking(3000, date: todayKey());
    expect(s.claimWalkingReward(), 12);
    s.addCart('salmon');
    s.fulfillment = 'pickup';
    final o = s.checkout();
    s.advance(o['id']);
    s.advance(o['id']);
    expect(s.walkingBoost, false);
    s.advance(o['id']);
    expect(s.walkingBoost, true);
    expect(s.claimWalkingReward(), 12);
    s.state['walking'] = {
      'date': '2020-01-01',
      'steps': 9999,
      'source': 'device',
    };
    expect(s.walkingToday['steps'], 0);
    expect(s.claimWalkingReward(), 0);
  });

  test(
    'native motion permission is requested only by explicit connection',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final calls = <MethodCall>[];
      var status = 'unlinked';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(walkingChannel, (call) async {
            if (call.method == 'takeOpenWalking') return false;
            calls.add(call);
            return {'status': status, 'steps': 4321, 'date': todayKey()};
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(walkingChannel, null),
      );
      final s = fresh(), sync = WalkingSync(s);
      addTearDown(sync.dispose);
      await sync.refresh();
      expect(calls.single.arguments, {'request': false});
      expect(s.walkingToday['source'], 'unlinked');
      status = 'authorized';
      await sync.refresh(request: true);
      expect(calls.last.arguments, {'request': true});
      expect(s.walkingToday['steps'], 4321);
      status = 'denied';
      expect(await sync.refresh(), contains('접근을 허용'));
      expect(s.walkingToday['steps'], 0);
      expect(s.walkingToday['source'], 'unlinked');
    },
  );

  test(
    'live activity sends today values and respects dismissal and deep links',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final calls = <MethodCall>[];
      var active = true, pending = false, opens = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(walkingChannel, (call) async {
            calls.add(call);
            if (call.method == 'takeOpenWalking') {
              final value = pending;
              pending = false;
              return value;
            }
            if (call.method == 'today') {
              return {
                'status': 'authorized',
                'date': todayKey(),
                'steps': 7068,
              };
            }
            if (call.method == 'liveStart') return true;
            if (call.method == 'liveUpdate') return active;
            if (call.method == 'liveStop') return false;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(walkingChannel, null),
      );
      final s = fresh()..updateWalking(7068, date: todayKey());
      final sync = WalkingSync(s, onOpen: () => opens++);
      addTearDown(sync.dispose);
      expect(await sync.setLiveEnabled(true), isNull);
      expect(sync.liveEnabled, true);
      final start = calls.firstWhere((c) => c.method == 'liveStart');
      expect(start.arguments, {
        'date': todayKey(),
        'steps': 7068,
        'calories': 231,
        'points': 28,
        'claimed': 0,
        'boosted': false,
      });
      pending = true;
      await sync.refresh();
      expect(opens, 1);
      active = false;
      await sync.refresh();
      expect(sync.liveEnabled, false);
      await sync.refresh();
      expect(calls.where((c) => c.method == 'liveStart').length, 1);
      expect(opens, 1);
      await sync.setLiveEnabled(false);
      expect(calls.last.method, 'liveStop');
    },
  );

  testWidgets(
    'live step stream updates immediately and ignores an older query',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const codec = StandardMethodCodec();
      final calls = <MethodCall>[];
      var querySteps = 3665, queryTime = 1000;
      messenger.setMockMethodCallHandler(walkingChannel, (call) async {
        calls.add(call);
        if (call.method == 'takeOpenWalking') return false;
        if (call.method == 'today') {
          return {
            'status': 'authorized',
            'date': todayKey(),
            'steps': querySteps,
            'measuredAt': queryTime,
          };
        }
        return true;
      });
      messenger.setMockMethodCallHandler(
        const MethodChannel('hankki/walking/events'),
        (call) async {
          calls.add(call);
          return null;
        },
      );
      final s = fresh();
      final liveSync = WalkingSync(s);
      addTearDown(() {
        liveSync.dispose();
        messenger.setMockMethodCallHandler(walkingChannel, null);
        messenger.setMockMethodCallHandler(
          const MethodChannel('hankki/walking/events'),
          null,
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Live(
            store: s,
            builder: (_) => Text('${s.walkingToday['steps']}'),
          ),
        ),
      );
      liveSync.start();
      await tester.pump();
      await liveSync.setLiveEnabled(true);
      expect(s.walkingToday['steps'], 3665);
      await messenger.handlePlatformMessage(
        'hankki/walking/events',
        codec.encodeSuccessEnvelope({
          'status': 'authorized',
          'date': todayKey(),
          'steps': 4001,
          'measuredAt': 2000,
        }),
        (_) {},
      );
      await tester.pump();
      expect(s.walkingToday['steps'], 4001);
      expect(find.text('4001'), findsOneWidget);
      expect(s.walkingAvailable, 16);
      expect(
        calls.lastWhere((c) => c.method == 'liveUpdate').arguments['steps'],
        4001,
      );
      // No 30-second timer advance: the native event already updated the UI data.
      querySteps = 3700;
      queryTime = 1500;
      await liveSync.refresh();
      expect(s.walkingToday['steps'], 4001);
      querySteps = 4010;
      queryTime = 3000;
      await liveSync.refresh();
      expect(s.walkingToday['steps'], 4010);
      liveSync.dispose();
      await tester.pump();
      expect(calls.where((c) => c.method == 'cancel').length, 1);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  for (final width in [360.0, 393.0, 430.0]) {
    testWidgets('walking card reward and details fit ${width.toInt()}px', (
      tester,
    ) async {
      phone(tester, width);
      final s = fresh()
        ..updateWalking(
          3665,
          date: todayKey(),
          source: 'preview',
          previewBoost: true,
        );
      final sync = WalkingSync(s);
      addTearDown(sync.dispose);
      final boundary = GlobalKey();
      final cardBoundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: 'NotoSansKR'),
            home: Scaffold(
              body: Live(
                store: s,
                builder: (_) => Align(
                  alignment: Alignment.topCenter,
                  child: RepaintBoundary(
                    key: cardBoundary,
                    child: WalkingCard(store: s, sync: sync, onPickup: () {}),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/captured/walking-logo.png'),
          tester.element(find.byType(WalkingCard)),
        ),
      );
      await tester.pumpAndSettle();
      final logo = tester.widget<RawImage>(find.byType(RawImage).first);
      expect(logo.image, isNotNull);
      expect(find.text('24P'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(cardBoundary)).height, lessThan(180));
      if (width == 393) await capture(tester, cardBoundary, 'walking-card');
      await tester.tap(find.text('보상 받기'));
      await tester.pumpAndSettle();
      expect(find.text('+24 P'), findsOneWidget);
      expect(s.walkingClaimed, 24);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('자세히 보기'));
      await tester.pumpAndSettle();
      expect(find.text('배민 만보기'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (width == 393) await capture(tester, boundary, 'walking-detail');
    });
  }

  for (final category in ['치킨', '피자', '카페·디저트', '패스트푸드']) {
    testWidgets('home $category opens a dedicated store list then menu', (
      tester,
    ) async {
      phone(tester);
      final s = fresh();
      await tester.pumpWidget(BaeminApp(store: s));
      await tester.pumpAndSettle();
      await tester.tap(find.text(category).first);
      await tester.pumpAndSettle();
      expect(find.byType(FoodCategoryScreen), findsOneWidget);
      final shop = s.shops.firstWhere(
        (x) => x['category'] == category && x['open'] == true,
      );
      await tester.ensureVisible(find.text(shop['name']).last);
      await tester.tap(find.text(shop['name']).last);
      await tester.pumpAndSettle();
      expect(find.byType(ShopScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('fast food brand selection opens its menu and adds a full set', (
    tester,
  ) async {
    phone(tester, 360);
    final s = fresh(), boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'NotoSansKR'),
          home: FoodCategoryScreen(store: s, initialCategory: '패스트푸드'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('6개'), findsOneWidget);
    for (final brand in ['맥도날드', '버거킹', '롯데리아', '맘스터치', 'KFC']) {
      expect(find.widgetWithText(ChoiceChip, brand), findsOneWidget);
    }
    final chip = find.widgetWithText(ChoiceChip, '버거킹');
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.text('1개'), findsOneWidget);
    await capture(tester, boundary, 'category-fastfood');
    await tester.tap(find.text('버거킹').last);
    await tester.pumpAndSettle();
    expect(find.byType(ShopScreen), findsOneWidget);
    final menu = find.text('와퍼 세트');
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.byType(ItemScreen), findsOneWidget);
    expect(find.textContaining('일반 콜라 355mL 전체'), findsOneWidget);
    final add = find.text('장바구니에 담기 · 9,900원');
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(s.cart['burgerking-whopper-set'], 1);
    final order = s.checkout();
    expect(order['shopId'], 'burgerking');
    expect(order['items'][0]['nutrition']['calories'], 1100);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'category filters, search reset and pickup selection work at 360px',
    (tester) async {
      phone(tester, 360);
      final s = fresh(), boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: 'NotoSansKR'),
            home: FoodCategoryScreen(
              store: s,
              initialCategory: '치킨',
              pickup: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2개'), findsOneWidget);
      await tester.tap(find.text('영업 중'));
      await tester.pumpAndSettle();
      expect(find.text('1개'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '없는 메뉴');
      await tester.pumpAndSettle();
      expect(find.text('조건에 맞는 가게가 없어요'), findsOneWidget);
      await tester.tap(find.text('필터 초기화'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('추천순'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('최소주문 낮은 순'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(tester, boundary, 'category-chicken');
      await tester.tap(find.text('바삭한 치킨 연구소'));
      await tester.pumpAndSettle();
      expect(s.fulfillment, 'pickup');
      expect(find.byType(ShopScreen), findsOneWidget);
    },
  );
}
