import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:baemin_flutter/store.dart';

void main() {
  final seed = obj(jsonDecode(File('assets/seed.json').readAsStringSync()));
  AppStore fresh() {
    final s = AppStore(seed);
    s.state['orders'] = [];
    s.state['records'] = [];
    s.state['events'] = [];
    s.state['pointLedger'] = [];
    return s;
  }

  test(
    'checkout snapshots and order progression record consumed food once',
    () {
      final s = fresh();
      s.addCart('bibimbap', quantity: 2);
      final o = s.checkout();
      expect(o['amount']['paid'], 22000);
      expect(s.cart, isEmpty);
      s.advance(o['id']);
      s.advance(o['id']);
      s.advance(o['id']);
      s.advance(o['id']);
      s.recordOrder(o['id'], todayKey(), .5);
      s.recordOrder(o['id'], todayKey(), 1);
      expect(s.records.length, 1);
      expect(
        s.records.single['nutrition']['calories'],
        s.item('bibimbap')['nutrition']['calories'],
      );
      expect(s.order(o['id'])['items'][0]['quantity'], 2);
    },
  );
  test('different shops cannot silently replace a cart and minimum amounts are enforced', () {
    final s = fresh();
    s.addCart('bibimbap');
    expect(() => s.addCart('milk'), throwsStateError);
    expect(s.cart.keys, ['bibimbap']);
    s.addCart('milk', replace: true);
    expect(s.cart.keys, ['milk']);
    s.cart.clear();
    s.addCart('salad-poke');
    s.cart['salad-poke'] = 1;
    expect(s.checkout()['amount']['paid'], 12500);
  });
  test(
    'issued coupons are used exactly once and cancellation restores them',
    () {
      final s = fresh();
      s.addCart('salmon');
      s.cartCoupon = 'issued-greens';
      final o = s.checkout();
      expect(o['amount']['discount'], 2000);
      expect(
        s.coupons.firstWhere((c) => c['id'] == 'issued-greens')['usedOrderId'],
        o['id'],
      );
      s.advance(o['id'], cancel: true);
      expect(s.order(o['id'])['amount']['refunded'], 11500);
      expect(
        s.coupons.firstWhere((c) => c['id'] == 'issued-greens')['usedAt'],
        isNull,
      );
      expect(() => s.recordOrder(o['id'], todayKey(), 1), throwsStateError);
    },
  );
  test('grocery with unknown nutrition can be purchased but never counted as consumed meals', () {
    final s = fresh();
    s.addCart('baemin-easy-pork-gukbap', quantity: 2);
    s.cartCoupon = 'issued-pb';
    final o = s.checkout();
    expect(o['items'][0]['nutrition'], isNull);
    expect(o['amount']['paid'], 7920);
    for (var i = 0; i < 3; i++) {
      s.advance(o['id']);
    }
    expect(() => s.recordOrder(o['id'], todayKey(), 1), throwsStateError);
    expect(s.records, isEmpty);
    expect(s.points, 0);
  });
  test('coupon eligibility rejects unrelated stores, minimum amount, expiry and missing PB', () {
    final s = fresh();
    expect(
      s.quote([
        {'menuId': 'milk', 'quantity': 1, 'unitPrice': 1990},
      ], couponId: 'issued-pb')['eligible'],
      false,
    );
    expect(
      s.quote([
        {'menuId': 'eggs', 'quantity': 2, 'unitPrice': 4980},
      ], couponId: 'issued-pb')['eligible'],
      false,
    );
    expect(
      s.quote([
        {'menuId': 'salmon', 'quantity': 1, 'unitPrice': 13500},
      ], couponId: 'issued-pb')['eligible'],
      false,
    );
  });
  test('nutrition direction uses measured energy, and PB pack size is not a nutrient estimate', () {
    final s = fresh();
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
    final r = s.report(), a = s.suggestions(r);
    expect(r['status'], 'balanced');
    expect(r['shares']['carbs'], 60.4);
    expect(r['shares']['protein'], 13.6);
    expect(a.first['value'], 60.4);
    expect(a.firstWhere((a) => a['target'] == 'recipe')['value'], 13.6);
    expect(a.last['id'], 'baemin-easy-pork-gukbap');
    expect(a.last['value'], 700);
    expect(a.last['unit'], 'g');
    expect(s.item(a.last['id'])['nutrition'], isNull);
  });
  test('unknown or invalid nutrition is not treated as zero intake', () {
    final s = fresh();
    expect(s.report()['status'], 'unknown');
    expect(s.suggestions(s.report()).single['target'], 'record');
    expect(
      () => s.recordPhoto(
        name: '음식',
        date: s.selected,
        nutrition: {'calories': -1, 'carbs': 0, 'protein': 0, 'fat': 0},
      ),
      throwsStateError,
    );
  });
  test('restoring and importing do not mutate source seed or discard nutrition absence', () {
    final s = fresh(), original = jsonEncode(seed);
    s.addCart('milk');
    final o = s.checkout();
    final restored = AppStore(seed);
    restored.restore({
      'state': s.state,
      'cart': {'milk': 1},
    });
    expect(restored.order(o['id'])['items'][0]['nutrition'], isNull);
    expect(restored.cart['milk'], 1);
    expect(jsonEncode(seed), original);
    expect(() => restored.restore({'version': 1}), throwsFormatException);
    expect(restored.orders.length, 1);
  });
  test('benefits are hidden in the past and claiming requires the exact current date', () {
    final s = fresh();
    expect(s.benefits('2020-10-29'), isEmpty);
    expect(
      s.benefits('2026-10-29', includePast: true).single['type'],
      'coupon',
    );
    expect(() => s.claimCoupon('2020-10-29'), throwsStateError);
  });
  test('reviews require a completed order and are idempotent', () {
    final s = fresh();
    s.state['reviews'] = [];
    s.addCart('bibimbap');
    final o = s.checkout();
    expect(() => s.review(o['id'], 5, '좋아요'), throwsStateError);
    for (var i = 0; i < 3; i++) {
      s.advance(o['id']);
    }
    s.review(o['id'], 5, '좋아요');
    s.review(o['id'], 4, '다시');
    expect(rows(s.state['reviews']).length, 1);
  });
  test('recipe ingredients are added atomically and invalid quantities preserve the cart', () {
    final s = fresh(), recipe = s.recipes.first;
    s.addCart('pb-eggs', quantity: 10);
    final before = Map<String, int>.from(s.cart);
    expect(() => s.addRecipe(recipe), throwsStateError);
    expect(s.cart, before);
    s.cart.clear();
    s.addRecipe(recipe);
    expect(s.cart.length, 3);
    expect(s.cartCoupon, 'issued-pb');
  });
  test('calendar distinguishes unconfirmed orders, consumed meals, cancelled orders and groceries', () {
    final s = fresh();
    s.addCart('salmon');
    final o = s.checkout();
    final date = orderDay(o);
    expect(s.calendarSummary(date)['cover']['menuId'], 'salmon');
    expect(s.calendarSummary(date)['unconfirmed'], true);
    expect(s.calendarSummary(date)['meals'], isEmpty);
    for (var i = 0; i < 3; i++) {
      s.advance(o['id']);
    }
    expect(s.calendarSummary(date)['unconfirmed'], true);
    s.recordOrder(o['id'], date, .5);
    expect(s.calendarSummary(date)['unconfirmed'], false);
    expect(
      s.calendarSummary(date)['calories'],
      numOf(s.item('salmon')['nutrition']['calories']) / 2,
    );
    expect(s.recordedOrder(o['id']), isNotNull);
    s.state['records'] = [];
    s.state['orders'] = [];
    s.addCart('bibimbap');
    final cancelled = s.checkout();
    s.advance(cancelled['id'], cancel: true);
    expect(s.calendarSummary(date)['cancelled'], true);
    expect(s.calendarSummary(date)['cover'], isNull);
    s.addCart('milk');
    s.checkout();
    expect(rows(s.calendarSummary(date)['orders']).length, 1);
    expect(s.calendarSummary(date, filter: 'photo')['cover'], isNull);
  });
  test('reordering is atomic and protects a different-store cart', () {
    final s = fresh();
    s.addCart('bibimbap');
    s.addCart('salmon');
    final o = s.checkout(), beforeOrder = jsonEncode(o);
    s.addCart('salmon', quantity: 10);
    final before = Map<String, int>.from(s.cart);
    expect(() => s.reorder(o), throwsStateError);
    expect(s.cart, before);
    s.cart.clear();
    s.addCart('milk');
    expect(() => s.reorder(o), throwsStateError);
    expect(s.cart, {'milk': 1});
    s.reorder(o, replace: true);
    expect(s.cart, {'bibimbap': 1, 'salmon': 1});
    expect(jsonEncode(o), beforeOrder);
  });
  test('checkout snapshots the delivery request and supplies an empty-request default', () {
    final s = fresh();
    s.addCart('bibimbap');
    final o = s.checkout(deliveryRequest: '  벨 누르지 말아주세요  ');
    expect(o['deliveryRequest'], '벨 누르지 말아주세요');
    expect(o['deliveryAddress'], '우리집');
    expect(o['paymentMethod'], '배민페이');
    s.addCart('bibimbap');
    expect(s.checkout(deliveryRequest: ' ')['deliveryRequest'], '문 앞에 놓아주세요');
  });
  test('menu estimates use a named portion and consistent macro energy', () {
    final s = fresh();
    for (final m in rows(s.seed['menus'])) {
      final n = m['nutrition'];
      final energy =
          4 * (numOf(n['carbs']) + numOf(n['protein'])) + 9 * numOf(n['fat']);
      expect(
        (energy - numOf(n['calories'])).abs(),
        lessThan(numOf(n['calories']) * .05),
        reason: m['id'],
      );
      expect(m['nutritionBasis'], isNotEmpty);
      expect(m['nutritionStatus'], 'estimated');
    }
    expect(s.item('milk')['nutrition'], isNull);
    expect(s.item('baemin-easy-pork-gukbap')['nutrition'], isNull);
  });

  test('migration updates old defaults while preserving edited and photo nutrition', () {
    final s = fresh();
    s.addCart('bibimbap', quantity: 2);
    final o = copy(s.checkout());
    o['status'] = 'delivered';
    o.remove('nutritionSource'); // Early Flutter orders had no source bundle.
    o['items'][0]['nutrition'] = copy(
      obj(s.item('bibimbap')['legacyNutrition']),
    );
    final old = copy(obj(o['items'][0]['nutrition']));
    final saved = copy(s.state)..remove('nutritionRevision');
    saved['orders'] = [o];
    saved['records'] = [
      {
        'id': 'legacy',
        'orderId': o['id'],
        'date': todayKey(),
        'name': '비빔밥',
        'portion': .5,
        'source': 'baemin-fixture',
        'nutrition': old,
      },
      {
        'id': 'edited',
        'orderId': o['id'],
        'date': todayKey(),
        'name': '수정한 식사',
        'portion': .5,
        'source': 'baemin-fixture',
        'nutrition': {...old, 'calories': 999},
      },
      {
        'id': 'photo',
        'date': todayKey(),
        'name': '사진 식사',
        'source': 'manual',
        'nutrition': old,
      },
    ];
    final restored = AppStore(seed)..restore({'state': saved});
    expect(restored.order(o['id'])['amount'], o['amount']);
    expect(restored.records.first['nutrition']['calories'], 707);
    expect(restored.records[1]['nutrition']['calories'], 999);
    expect(restored.records[2]['nutrition'], old);
    final once = jsonEncode(restored.state);
    restored.migrateEstimatedNutrition();
    expect(jsonEncode(restored.state), once);
  });

  test('Mongchon requires two main servings and records half of a two-person order', () {
    final s = fresh();
    s.addCart('mongchon-herbal');
    s.addCart('mongchon-perilla-noodles', quantity: 2);
    expect(() => s.checkout(), throwsStateError);
    s.addCart('mongchon-herbal');
    final o = s.checkout();
    expect(o['amount']['paid'], 53000);
    s.advance(o['id']);
    s.advance(o['id']);
    s.advance(o['id']);
    expect(() => s.recordOrder(o['id'], todayKey(), 1.5), throwsStateError);
    s.recordOrder(o['id'], todayKey(), .5);
    expect(s.records.single['nutrition']['calories'], 1250);
    final takeout = fresh()..addCart('mongchon-takeout');
    expect(takeout.checkout()['amount']['paid'], 30000);
  });
}
