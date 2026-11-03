import 'support/fixtures.dart';

import 'package:baemin_flutter/app/home_shell.dart';

import 'package:baemin_flutter/features/orders/presentation/commerce.dart';
import 'package:baemin_flutter/app/app.dart';
import 'package:baemin_flutter/core/state/app_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'NotoSansKR',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  final seed = loadSeed();
  AppStore fresh() => AppStore(seed);
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(393, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  test(
    'month navigation clamps only to the last real day of the target month',
    () {
      final s = fresh();
      s.choose('2026-03-31');
      s.setView('month');
      s.shiftPeriod(1);
      expect(s.selected, '2026-04-30');
      s.choose('2028-01-31');
      s.shiftPeriod(1);
      expect(s.selected, '2028-02-29');
    },
  );

  test('removing the coupon menu clears the now-ineligible cart coupon', () {
    final s = fresh();
    s.addCart('bibimbap');
    s.addCart('salmon');
    s.cartCoupon = 'issued-greens';
    expect(s.cartQuote['eligible'], true);
    s.changeQuantity('salmon', -1);
    expect(s.cartCoupon, isNull);
    expect(s.checkout()['amount']['paid'], 11000);
  });

  test(
    'invalid replacement quantity preserves the existing cart and coupon',
    () {
      final s = fresh();
      s.addCart('salmon');
      s.cartCoupon = 'issued-greens';
      expect(
        () => s.addCart('milk', quantity: 11, replace: true),
        throwsStateError,
      );
      expect(s.cart, {'salmon': 1});
      expect(s.cartCoupon, 'issued-greens');
      expect(() => s.addCart('salmon', quantity: -1), throwsStateError);
      expect(s.cart, {'salmon': 1});
    },
  );

  testWidgets(
    'favorites and order history keep their service tabs independent',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(BaeminApp(store: fresh(), initialTab: 2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('장보기·쇼핑').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('주문내역').last);
      await tester.pumpAndSettle();
      expect(find.text('나의 한 끼 캘린더'), findsOneWidget);
      expect(find.text('장보기·쇼핑 주문내역'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pickup checkout uses the store and pickup request instead of a home address',
    (tester) async {
      phone(tester);
      final s = fresh();
      s.addCart('salmon');
      s.fulfillment = 'pickup';
      await tester.pumpWidget(BaeminApp(store: s));
      await tester.pumpAndSettle();
      Navigator.push(
        tester.element(find.byType(HomeShell)),
        MaterialPageRoute(builder: (_) => CheckoutScreen(store: s)),
      );
      await tester.pumpAndSettle();
      expect(find.text('가게에서 픽업'), findsOneWidget);
      expect(find.text('저장된 기본 배달 주소'), findsNothing);
    },
  );

  testWidgets('pickup ready never appears as out for delivery', (tester) async {
    phone(tester);
    final s = fresh();
    s.addCart('salmon');
    s.fulfillment = 'pickup';
    final o = s.checkout();
    s.advance(o['id']);
    s.advance(o['id']);
    await tester.pumpWidget(
      MaterialApp(
        home: OrderScreen(store: s, id: o['id']),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('픽업 준비 완료'), findsWidgets);
    expect(find.text('배달 중'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'completed checkout back navigation does not reopen an emptied cart',
    (tester) async {
      phone(tester);
      final s = fresh();
      s.addCart('salmon');
      await tester.pumpWidget(BaeminApp(store: s));
      await tester.pumpAndSettle();
      openCart(tester.element(find.byType(HomeShell)), s);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('주문하기').last);
      await tester.tap(find.textContaining('주문하기').last);
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(CheckoutScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(CartScreen), findsOneWidget);
      expect(s.cart, {'salmon': 1});
      await tester.tap(find.textContaining('주문하기').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('주문 완료하기'));
      await tester.pumpAndSettle();
      expect(find.byType(OrderScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(OrderScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.byType(CartScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an expired selected coupon has an explicit removal action', (
    tester,
  ) async {
    phone(tester);
    final s = fresh();
    s.addCart('salmon');
    s.cartCoupon = 'issued-greens';
    final cs = s.coupons;
    cs.firstWhere((c) => c['id'] == 'issued-greens')['expiresAt'] =
        '2020-01-01';
    s.state['coupons'] = cs;
    await tester.pumpWidget(MaterialApp(home: CartScreen(store: s)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('쿠폰 적용 해제'));
    await tester.tap(find.text('쿠폰 적용 해제'));
    await tester.pumpAndSettle();
    expect(s.cartCoupon, isNull);
    expect(s.cartQuote['total'], 13500);
    expect(tester.takeException(), isNull);
  });
}
