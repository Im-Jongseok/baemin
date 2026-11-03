import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef Json = Map<String, dynamic>;
Json obj(dynamic v) => Map<String, dynamic>.from(v as Map);
List<Json> rows(dynamic v) => (v as List? ?? []).map(obj).toList();
double numOf(dynamic v) => v is num ? v.toDouble() : 0;
Json copy(Json v) => obj(jsonDecode(jsonEncode(v)));
String dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime parseDay(String d) => DateTime.parse('${d}T12:00:00');
String todayKey() =>
    dateKey(DateTime.now().toUtc().add(const Duration(hours: 9)));
String orderDay(Json o) => dateKey(
  DateTime.parse(o['placedAt']).toUtc().add(const Duration(hours: 9)),
);
String number(num n) => n.round().toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);
String won(dynamic n) => '${number(numOf(n))}원';
String decimal(num n) =>
    n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1);
const nutrients = ['calories', 'carbs', 'protein', 'fat'];
const statuses = ['pending', 'preparing', 'delivering', 'delivered'];
const statusLabels = {
  'pending': '접수 대기',
  'preparing': '조리 중',
  'delivering': '배달 중',
  'delivered': '배달 완료',
  'cancelled': '전체 취소',
};
String orderStatusLabel(Json order) {
  final status = order['status'];
  if (order['service'] == 'shopping') {
    return {
          'preparing': '상품 준비 중',
          'delivering': '배송 중',
          'delivered': '배송 완료',
        }[status] ??
        statusLabels[status]!;
  }
  if (order['fulfillment'] == 'pickup') {
    return {'delivering': '픽업 준비 완료', 'delivered': '픽업 완료'}[status] ??
        statusLabels[status]!;
  }
  return statusLabels[status]!;
}

bool validN(dynamic v) =>
    v is Map &&
    nutrients.every(
      (k) =>
          v[k] is num &&
          (v[k] as num).isFinite &&
          v[k] >= 0 &&
          v[k] <= (k == 'calories' ? 20000 : 3000),
    );

class AppStore extends ChangeNotifier {
  AppStore(this.seed, {this.preferences}) {
    state = copy(obj(seed['state']));
    migrateEstimatedNutrition();
  }
  final Json seed;
  final SharedPreferences? preferences;
  late Json state;
  Map<String, int> cart = {};
  String? cartCoupon;
  String fulfillment = 'delivery';
  String lastError = '';
  static const storageKey = 'baemin_flutter_state_v1';
  static Future<AppStore> load() async {
    final seed = obj(
      jsonDecode(await rootBundle.loadString('assets/seed.json')),
    );
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore(seed, preferences: prefs);
    final saved = prefs.getString(storageKey);
    if (saved != null) {
      try {
        final incoming = obj(jsonDecode(saved));
        final previousRevision = incoming['state']?['nutritionRevision'];
        store.restore(incoming);
        if (previousRevision != store.state['nutritionRevision']) {
          await store.save();
        }
      } catch (_) {
        store.lastError = '저장한 기록을 불러오지 못했어요. 기존 데이터는 보존했어요.';
      }
    }
    return store;
  }

  List<Json> get shops => rows(seed['shops']);
  List<Json> get catalog => [...rows(seed['menus']), ...rows(seed['products'])];
  List<Json> get recipes => rows(seed['recipes']);
  List<Json> get orders => rows(state['orders']);
  List<Json> get records => rows(state['records']);
  List<Json> get coupons => rows(state['coupons']);
  Json item(String id) => catalog.firstWhere((p) => p['id'] == id);
  Json shop(String id) => shops.firstWhere((p) => p['id'] == id);
  Json order(String id) => orders.firstWhere((p) => p['id'] == id);
  String get selected => state['selectedDate'];
  bool get club => state['membership']?['baeminClub'] == true;
  int get points =>
      rows(state['pointLedger'])
          .fold(0, (n, p) => n + (p['points'] as num).toInt());
  String uid() => DateTime.now().microsecondsSinceEpoch.toString();
  void restore(Json incoming) {
    final data = incoming['state'] is Map ? obj(incoming['state']) : incoming;
    if (data['version'] != 1 ||
        ![
          'orders',
          'records',
          'favorites',
          'reviews',
          'events',
        ].every((k) => data[k] is List)) {
      throw const FormatException('기록 형식을 확인해 주세요.');
    }
    for (final r in rows(data['records'])) {
      if (!validN(r['nutrition']) ||
          DateTime.tryParse(r['date'] ?? '') == null) {
        throw const FormatException('식사 영양정보를 확인해 주세요.');
      }
    }
    for (final o in rows(data['orders'])) {
      if (!statusLabels.containsKey(o['status']) ||
          rows(o['items']).isEmpty ||
          o['amount'] is! Map ||
          DateTime.tryParse(o['placedAt'] ?? '') == null) {
        throw const FormatException('주문 형식을 확인해 주세요.');
      }
      for (final i in rows(o['items'])) {
        if ((!validN(i['nutrition']) &&
                !(o['service'] == 'shopping' && i['nutrition'] == null)) ||
            numOf(i['quantity']) <= 0) {
          throw const FormatException('주문 메뉴를 확인해 주세요.');
        }
      }
    }
    if (DateTime.tryParse(data['selectedDate'] ?? '') == null) {
      throw const FormatException('선택 날짜를 확인해 주세요.');
    }
    state = copy(data);
    state['view'] = 'week';
    cart = {};
    if (incoming['cart'] is Map) {
      for (final e in obj(incoming['cart']).entries) {
        if (catalog.any((p) => p['id'] == e.key) &&
            e.value is int &&
            e.value > 0 &&
            e.value <= 10) {
          cart[e.key] = e.value;
        }
      }
      if (cart.keys.map((k) => item(k)['shopId']).toSet().length > 1) {
        cart.clear();
      }
    }
    cartCoupon = incoming['cartCoupon'];
    fulfillment = incoming['fulfillment'] == 'pickup' ? 'pickup' : 'delivery';
    migrateEstimatedNutrition();
  }

  // Refresh only known prototype estimates; preserve manually changed/photo data.
  void migrateEstimatedNutrition() {
    final revision = seed['nutritionRevision'];
    if (revision == null || state['nutritionRevision'] == revision) return;
    bool same(dynamic a, dynamic b) =>
        validN(a) &&
        validN(b) &&
        nutrients.every((k) => (numOf(a[k]) - numOf(b[k])).abs() < .01);
    Json total(Json o) => {
      for (final k in nutrients)
        k: rows(o['items']).fold<double>(
          0,
          (sum, i) => sum + numOf(i['nutrition']?[k]) * numOf(i['quantity']),
        ),
    };
    final previous = <String, Json>{}, revised = <String, Json>{};
    final all = orders;
    for (final o in all) {
      if (o['service'] == 'shopping' ||
          (o['nutritionSource'] != null &&
              o['nutritionSource']['type'] != 'baemin-fixture')) {
        continue;
      }
      final before = total(o);
      var changed = false;
      final lines = rows(o['items']);
      for (final line in lines) {
        final m = catalog.where((m) => m['id'] == line['menuId']).firstOrNull;
        if (m == null || !same(line['nutrition'], m['legacyNutrition'])) {
          continue;
        }
        line['nutrition'] = copy(obj(m['nutrition']));
        line['nutritionBasis'] = m['nutritionBasis'];
        line['servings'] = m['servings'];
        line['nutritionStatus'] = 'estimated';
        changed = true;
      }
      if (changed) {
        o['items'] = lines;
        o['nutritionSource'] = {
          'type': 'baemin-fixture',
          'label': '일반 음식 기준 영양 추정',
          'version': revision,
        };
        previous[o['id']] = before;
        revised[o['id']] = total(o);
      }
    }
    state['orders'] = all;
    final meals = records;
    for (final r in meals) {
      final id = r['orderId'];
      if (r['source'] != 'baemin-fixture' || !previous.containsKey(id)) {
        continue;
      }
      final portion = numOf(r['portion']);
      final before = {
        for (final k in nutrients) k: numOf(previous[id]![k]) * portion,
      };
      if (!same(r['nutrition'], before)) continue;
      r['nutrition'] = {
        for (final k in nutrients) k: numOf(revised[id]![k]) * portion,
      };
      r['nutritionStatus'] = 'estimated';
      r['sourceLabel'] = '일반 음식 기준 영양 추정';
    }
    state['records'] = meals;
    state['nutritionRevision'] = revision;
  }

  Future<void> save() async {
    notifyListeners();
    if (preferences == null) return;
    try {
      if (!await preferences!.setString(
        storageKey,
        jsonEncode({
          'state': state,
          'cart': cart,
          'cartCoupon': cartCoupon,
          'fulfillment': fulfillment,
        }),
      )) {
        throw StateError('저장 실패');
      }
    } catch (_) {
      lastError = '저장 공간을 확인해 주세요. 현재 기록은 앱에 유지돼요.';
      notifyListeners();
    }
  }

  void choose(String day) {
    state['selectedDate'] = day;
    state['month'] = day.substring(0, 7);
    save();
  }

  void shiftPeriod(int step) {
    final day = parseDay(selected);
    final target = DateTime(day.year, day.month + step);
    final lastDay = DateTime(target.year, target.month + 1, 0).day;
    choose(
      dateKey(
        state['view'] == 'month'
            ? DateTime(target.year, target.month, day.day.clamp(1, lastDay))
            : day.add(Duration(days: 7 * step)),
      ),
    );
  }

  void setView(String v) {
    state['view'] = v;
    save();
  }

  void favorite(String id) {
    final a = List<String>.from(state['favorites']);
    a.contains(id) ? a.remove(id) : a.add(id);
    state['favorites'] = a;
    save();
  }

  List<Json> dayRecords(String date, [String filter = 'all']) => records
      .where(
        (r) =>
            r['confirmed'] == true &&
            r['date'] == date &&
            (filter != 'photo' || r['orderId'] == null) &&
            (filter != 'delivery' || r['orderId'] != null) &&
            (r['orderId'] == null ||
                orders.any(
                  (o) =>
                      o['id'] == r['orderId'] &&
                      o['status'] == 'delivered' &&
                      o['service'] != 'shopping',
                )),
      )
      .toList();
  Json totals(List<Json> rs) => {
    for (final k in nutrients)
      k: rs.fold<double>(0, (n, r) => n + numOf(r['nutrition']?[k])),
  };
  Json calendarSummary(String date, {String filter = 'all'}) {
    final meals = dayRecords(date, filter);
    final dayOrders = filter == 'photo'
        ? <Json>[]
        : orders
              .where((o) => o['service'] != 'shopping' && orderDay(o) == date)
              .toList();
    final active = dayOrders.where((o) => o['status'] != 'cancelled').toList();
    final cover =
        meals.firstOrNull ??
        (active.isEmpty ? null : rows(active.first['items']).firstOrNull);
    return {
      'meals': meals,
      'orders': dayOrders,
      'cover': cover,
      'calories': totals(meals)['calories'],
      'unconfirmed': cover != null && meals.isEmpty,
      'cancelled': dayOrders.isNotEmpty && active.isEmpty && meals.isEmpty,
    };
  }

  Json? recordedOrder(String id) =>
      records.where((r) => r['orderId'] == id).firstOrNull;
  Json? reviewFor(String id) =>
      rows(state['reviews']).where((r) => r['orderId'] == id).firstOrNull;
  void reorder(Json order, {bool replace = false}) {
    final requests = rows(order['items']);
    if (requests.isEmpty || shop(order['shopId'])['open'] != true) {
      throw StateError('지금은 준비 중인 가게예요.');
    }
    final different =
        cart.isNotEmpty && item(cart.keys.first)['shopId'] != order['shopId'];
    if (different && !replace) {
      throw StateError('다른 가게의 장바구니가 있어요.');
    }
    final next = different ? <String, int>{} : Map<String, int>.from(cart);
    for (final line in requests) {
      final id = line['menuId'] as String,
          quantity = (line['quantity'] as num).toInt();
      if (item(id)['shopId'] != order['shopId'] ||
          quantity < 1 ||
          (next[id] ?? 0) + quantity > 10) {
        throw StateError('수량은 10개까지 담을 수 있어요.');
      }
      next[id] = (next[id] ?? 0) + quantity;
    }
    cart = next;
    if (different) {
      cartCoupon = null;
    }
    save();
  }

  String couponStatus(Json c) => c['usedAt'] != null
      ? 'used'
      : todayKey().compareTo(c['issuedAt']) < 0
      ? 'future'
      : todayKey().compareTo(c['expiresAt']) > 0
      ? 'expired'
      : 'available';
  Json quote(List<Json> items, {String? couponId}) {
    final subtotal = items.fold<double>(
      0,
      (n, i) => n + numOf(i['unitPrice']) * numOf(i['quantity']),
    );
    final c = coupons.where((c) => c['id'] == couponId).firstOrNull;
    double discount = 0;
    String reason = '';
    if (c != null && items.isNotEmpty) {
      final first = item(items.first['menuId']);
      if (couponStatus(c) != 'available') {
        reason = '사용했거나 기간이 지난 쿠폰이에요.';
      } else if (first['shopId'] != c['shopId'] ||
          (first['service'] ?? 'delivery') != c['service']) {
        reason = '이 가게에서 사용할 수 없는 쿠폰이에요.';
      } else if (subtotal < numOf(c['minOrder'])) {
        reason = '${won(c['minOrder'])} 이상 주문에 사용할 수 있어요.';
      } else if (c['requiredMenuIds'] is List &&
          !items.any(
            (i) =>
                (c['requiredMenuIds'] as List).contains(i['menuId']) ||
                c['id'] == 'issued-pb' && item(i['menuId'])['pb'] == true,
          )) {
        reason = 'PB 상품이 한 개 이상 필요해요.';
      } else {
        final eligible = items
            .where(
              (i) =>
                  c['allowedMenuIds'] == null ||
                  (c['allowedMenuIds'] as List).contains(i['menuId']),
            )
            .fold<double>(
              0,
              (n, i) => n + numOf(i['unitPrice']) * numOf(i['quantity']),
            );
        if (eligible > 0) {
          discount = numOf(c['discount']).clamp(0, eligible);
        } else {
          reason = '쿠폰 대상 메뉴를 담아주세요.';
        }
      }
    }
    return {
      'subtotal': subtotal,
      'discount': discount,
      'total': subtotal - discount,
      'eligible': c != null && reason.isEmpty && discount > 0,
      'reason': reason,
    };
  }

  List<Json> get cartItems => cart.entries
      .map(
        (e) => {
          'menuId': e.key,
          'quantity': e.value,
          'unitPrice': item(e.key)['price'],
        },
      )
      .toList();
  Json get cartQuote => quote(cartItems, couponId: cartCoupon);
  void addCart(String id, {int quantity = 1, bool replace = false}) {
    final p = item(id);
    if (shop(p['shopId'])['open'] != true) {
      throw StateError('지금은 준비 중인 가게예요.');
    }
    final different =
        cart.isNotEmpty && item(cart.keys.first)['shopId'] != p['shopId'];
    if (quantity < 1 || (different ? 0 : cart[id] ?? 0) + quantity > 10) {
      throw StateError('수량은 1개부터 10개까지 선택할 수 있어요.');
    }
    if (different) {
      if (!replace) {
        throw StateError('다른 가게의 장바구니가 있어요.');
      }
      cart.clear();
      cartCoupon = null;
    }
    cart[id] = (cart[id] ?? 0) + quantity;
    save();
  }

  void addRecipe(Json recipe, {bool replace = false}) {
    final ingredients = rows(recipe['items']);
    if (ingredients.isEmpty || shop(recipe['shopId'])['open'] != true) {
      throw StateError('재료를 담을 수 없어요.');
    }
    final different =
        cart.isNotEmpty && item(cart.keys.first)['shopId'] != recipe['shopId'];
    if (different && !replace) {
      throw StateError('다른 가게의 장바구니가 있어요.');
    }
    final next = different ? <String, int>{} : Map<String, int>.from(cart);
    for (final line in ingredients) {
      final id = line['menuId'] as String,
          quantity = (line['quantity'] as num).toInt();
      if (item(id)['shopId'] != recipe['shopId'] ||
          quantity < 1 ||
          (next[id] ?? 0) + quantity > 10) {
        throw StateError('재료 수량은 10개까지 담을 수 있어요.');
      }
      next[id] = (next[id] ?? 0) + quantity;
    }
    final proposed = next.entries
        .map(
          (e) => <String, dynamic>{
            'menuId': e.key,
            'quantity': e.value,
            'unitPrice': item(e.key)['price'],
          },
        )
        .toList();
    final eligible =
        quote(proposed, couponId: recipe['couponId'])['eligible'] == true;
    cart = next;
    cartCoupon = eligible
        ? recipe['couponId']
        : different
        ? null
        : cartCoupon;
    save();
  }

  void changeQuantity(String id, int delta) {
    final n = (cart[id] ?? 0) + delta;
    if (n <= 0) {
      cart.remove(id);
    } else if (n <= 10) {
      cart[id] = n;
    }
    if (cartCoupon != null && cartQuote['eligible'] != true) {
      cartCoupon = null;
    }
    save();
  }

  Json checkout({String deliveryRequest = '문 앞에 놓아주세요'}) {
    if (cart.isEmpty) {
      throw StateError('메뉴를 담아주세요.');
    }
    final first = item(cart.keys.first),
        s = shop(first['shopId']),
        q = cartQuote;
    if (s['open'] != true || numOf(q['subtotal']) < numOf(s['minOrder'])) {
      throw StateError('최소주문금액 ${won(s['minOrder'])}을 확인해 주세요.');
    }
    final requiredMain = numOf(s['minMainServings']);
    final mainServings = cart.entries.fold<double>(
      0,
      (sum, e) => sum + numOf(item(e.key)['mainServings']) * e.value,
    );
    if (requiredMain > 0 && mainServings < requiredMain) {
      throw StateError('닭갈비는 2인분부터 주문할 수 있어요.');
    }
    if (cartCoupon != null && q['eligible'] != true) {
      throw StateError(q['reason']);
    }
    final id = 'order-${uid()}', at = DateTime.now().toUtc().toIso8601String();
    final items = cart.entries.map((e) {
      final p = item(e.key);
      return {
        'id': '$id-${e.key}',
        'menuId': e.key,
        'name': p['name'],
        'kind': p['kind'],
        'image': p['image'],
        'unitPrice': p['price'],
        'quantity': e.value,
        'nutrition': p['nutrition'],
        'nutritionBasis': p['nutritionBasis'],
        'nutritionStatus': p['nutritionStatus'],
        'servings': p['servings'] ?? 1,
      };
    }).toList();
    final o = <String, dynamic>{
      'id': id,
      'attemptId': id,
      'shopId': s['id'],
      'shopName': s['name'],
      'nutritionSource': {
        'type': 'baemin-fixture',
        'label': '일반 음식 기준 영양 추정',
        'version': seed['nutritionRevision'],
      },
      'service': s['service'] ?? 'delivery',
      'fulfillment': s['service'] == 'shopping' ? 'delivery' : fulfillment,
      'placedAt': at,
      'status': 'pending',
      'items': items,
      'amount': {
        'subtotal': q['subtotal'],
        'discount': q['discount'],
        'paid': q['total'],
        'deliveryFee': 0,
        'refunded': 0,
      },
      'history': [
        {'status': 'pending', 'at': at},
      ],
      'completedAt': null,
      'deliveryAddress': '우리집',
      'deliveryRequest': deliveryRequest.trim().isEmpty
          ? (s['service'] != 'shopping' && fulfillment == 'pickup'
                ? '가게에서 직접 받을게요'
                : '문 앞에 놓아주세요')
          : deliveryRequest.trim(),
      'paymentMethod': '배민페이',
    };
    if (cartCoupon != null) {
      final cs = coupons;
      final c = cs.firstWhere((c) => c['id'] == cartCoupon);
      c['usedAt'] = at;
      c['usedOrderId'] = id;
      state['coupons'] = cs;
      o['coupon'] = {'id': c['id'], 'title': c['title']};
    }
    state['orders'] = [o, ...orders];
    cart.clear();
    cartCoupon = null;
    state['selectedDate'] = todayKey();
    state['month'] = todayKey().substring(0, 7);
    save();
    return o;
  }

  void advance(String id, {bool cancel = false}) {
    final all = orders,
        o = all.firstWhere((o) => o['id'] == id),
        status = o['status'];
    if (status == 'delivered' || status == 'cancelled') {
      return;
    }
    if (cancel && status != 'pending') {
      throw StateError('접수 대기 중에만 취소할 수 있어요.');
    }
    o['status'] = cancel ? 'cancelled' : statuses[statuses.indexOf(status) + 1];
    final at = DateTime.now().toUtc().toIso8601String();
    o['history'] = [
      ...rows(o['history']),
      {'status': o['status'], 'at': at},
    ];
    if (cancel) {
      o['amount']['refunded'] = o['amount']['paid'];
      final cs = coupons;
      for (final c in cs) {
        if (c['usedOrderId'] == id) {
          c['usedAt'] = null;
          c['usedOrderId'] = null;
        }
      }
      state['coupons'] = cs;
    }
    if (o['status'] == 'delivered') {
      o['completedAt'] = at;
      if (o['service'] != 'shopping') {
        final ledger = rows(state['pointLedger']);
        for (final b in benefits(orderDay(o), includePast: true)) {
          if (b['points'] != null &&
              numOf(o['amount']['subtotal']) >= numOf(b['minOrder']) &&
              (b['type'] != 'pickup' || o['fulfillment'] == 'pickup') &&
              !ledger.any((l) => l['benefitId'] == b['id'])) {
            ledger.add({
              'id': b['id'],
              'benefitId': b['id'],
              'orderId': id,
              'points': b['points'],
              'at': at,
              'title': b['title'],
            });
          }
        }
        state['pointLedger'] = ledger;
      }
    }
    state['orders'] = all;
    save();
  }

  void recordOrder(String id, String date, double portion) {
    final o = order(id);
    if (o['status'] != 'delivered' || o['service'] == 'shopping') {
      throw StateError('배달 완료된 음식만 기록할 수 있어요.');
    }
    if (records.any((r) => r['orderId'] == id)) {
      return;
    }
    if (!portion.isFinite || portion <= 0 || portion > 1) {
      throw StateError('먹은 양을 확인해 주세요.');
    }
    final n = {
      for (final k in nutrients)
        k:
            rows(o['items']).fold<double>(
              0,
              (sum, i) =>
                  sum + numOf(i['nutrition']?[k]) * numOf(i['quantity']),
            ) *
            portion,
    };
    if (!validN(n)) {
      throw StateError('영양값을 확인해 주세요.');
    }
    state['records'] = [
      ...records,
      {
        'id': 'record-${uid()}',
        'orderId': id,
        'date': date,
        'name': rows(o['items']).map((i) => i['name']).join(' · '),
        'kind': o['items'][0]['kind'],
        'image': o['items'][0]['image'],
        'confirmed': true,
        'portion': portion,
        'nutrition': n,
        'source': 'baemin-fixture',
        'nutritionStatus': 'estimated',
        'sourceLabel': '일반 음식 기준 영양 추정',
      },
    ];
    save();
  }

  void recordPhoto({
    required String name,
    required String date,
    required Json nutrition,
    String? image,
    String source = 'manual',
    Json? analysis,
  }) {
    if (name.trim().isEmpty || !validN(nutrition)) {
      throw StateError('음식 이름과 영양값을 확인해 주세요.');
    }
    state['records'] = [
      ...records,
      {
        'id': 'photo-${uid()}',
        'analysisId': uid(),
        'orderId': null,
        'date': date,
        'name': name,
        'kind': 'bowl',
        'nutrition': nutrition,
        'image': image,
        'confirmed': true,
        'source': source,
        if (analysis != null) 'analysis': copy(analysis),
      },
    ];
    save();
  }

  void review(String id, int rating, String text) {
    if (order(id)['status'] != 'delivered' || rating < 1 || rating > 5) {
      throw StateError('완료한 주문의 별점을 선택해 주세요.');
    }
    if (rows(state['reviews']).any((r) => r['orderId'] == id)) {
      return;
    }
    state['reviews'] = [
      ...rows(state['reviews']),
      {'id': uid(), 'orderId': id, 'rating': rating, 'text': text},
    ];
    save();
  }

  Json get walkingToday {
    final saved = state['walking'];
    return saved is Map && saved['date'] == todayKey()
        ? obj(saved)
        : {'date': todayKey(), 'steps': 0, 'source': 'unlinked'};
  }

  void updateWalking(
    int steps, {
    required String date,
    String source = 'device',
    bool previewBoost = false,
  }) {
    if (date != todayKey() || steps < 0 || steps > 200000) return;
    state['walking'] = {
      'date': date,
      'steps': steps,
      'source': source,
      'previewBoost': source == 'preview' && previewBoost,
    };
    save();
  }

  bool get walkingBoost =>
      walkingToday['previewBoost'] == true ||
      orders.any(
        (o) =>
            o['status'] == 'delivered' &&
            o['service'] != 'shopping' &&
            o['fulfillment'] == 'pickup' &&
            o['completedAt'] != null &&
            dateKey(
                  DateTime.parse(o['completedAt'])
                      .toUtc()
                      .add(const Duration(hours: 9)),
                ) ==
                todayKey(),
      );
  int get walkingEarned =>
      ((numOf(walkingToday['steps']).toInt().clamp(0, 10000) ~/ 1000) * 4) *
      (walkingBoost ? 2 : 1);
  int get walkingClaimed =>
      rows(state['pointLedger'])
          .where((l) => l['source'] == 'walking' && l['date'] == todayKey())
          .fold<int>(0, (sum, l) => sum + numOf(l['points']).toInt());
  int get walkingAvailable => (walkingEarned - walkingClaimed).clamp(0, 80);
  int claimWalkingReward() {
    final points = walkingAvailable;
    if (walkingToday['source'] == 'unlinked' || points == 0) return 0;
    state['pointLedger'] = [
      ...rows(state['pointLedger']),
      {
        'id': 'walk-${todayKey()}-$walkingEarned',
        'source': 'walking',
        'date': todayKey(),
        'points': points,
        'at': DateTime.now().toUtc().toIso8601String(),
        'title': walkingBoost ? '만보기 · 픽업 부스터 X2' : '만보기 보상',
      },
    ];
    save();
    return points;
  }

  List<Json> benefits(String date, {bool includePast = false}) {
    if (!includePast && date.compareTo(todayKey()) < 0) {
      return [];
    }
    final d = parseDay(date).day, a = <Json>[];
    if ([18, 19, 26, 28].contains(d)) {
      a.add({
        'id': 'order-points-$date',
        'type': 'points',
        'title': '주문하면 500P',
        'points': 500,
        'minOrder': 10000,
        'asset': 'points',
        'description': '음식배달·픽업 10,000원 이상 주문 완료 시',
      });
    }
    if ([22, 23, 29].contains(d)) {
      a.add({
        'id': 'market-coupon-$date',
        'type': 'coupon',
        'title': 'B마트 장보기 쿠폰',
        'discount': 3000,
        'minOrder': 9000,
        'asset': 'coupon',
        'description': '당일 받기 · B마트 9,000원 이상 장보기 시 3,000원 할인',
      });
    }
    if ([20, 25, 30].contains(d)) {
      a.add({
        'id': 'pickup-points-$date',
        'type': 'pickup',
        'title': '픽업하면 1,000P',
        'points': 1000,
        'minOrder': 9000,
        'asset': 'pickup',
        'description': '픽업 9,000원 이상 주문 완료 시 추가 적립',
      });
    }
    return a;
  }

  void claimCoupon(String date) {
    if (date != todayKey()) {
      throw StateError('표시된 날짜에 받을 수 있어요.');
    }
    final b = benefits(date).where((b) => b['type'] == 'coupon').firstOrNull;
    if (b == null) {
      return;
    }
    if (coupons.any((c) => c['id'] == b['id'])) {
      return;
    }
    state['coupons'] = [
      ...coupons,
      {
        'id': b['id'],
        'title': '캘린더 B마트 3,000원',
        'description': b['description'],
        'shopId': 'bmart',
        'service': 'shopping',
        'discount': 3000,
        'minOrder': 9000,
        'issuedAt': date,
        'expiresAt': date,
        'usedAt': null,
        'source': 'fixture',
      },
    ];
    save();
  }

  List<String> reportDays({String? mode}) {
    final d = parseDay(selected);
    final month = (mode ?? state['view']) == 'month';
    final start = month
        ? DateTime(d.year, d.month)
        : d.subtract(Duration(days: d.weekday % 7));
    final count = month ? DateTime(d.year, d.month + 1, 0).day : 7;
    return List.generate(count, (i) => dateKey(start.add(Duration(days: i))));
  }

  Json report({String? mode}) {
    final dates = reportDays(mode: mode),
        rs = records
            .where((r) => r['confirmed'] == true && dates.contains(r['date']))
            .toList(),
        total = totals(rs);
    final energy =
        numOf(total['carbs']) * 4 +
        numOf(total['protein']) * 4 +
        numOf(total['fat']) * 9;
    final shares = energy == 0
        ? null
        : {
            for (final k in ['carbs', 'protein', 'fat'])
              k:
                  (numOf(total[k]) * (k == 'fat' ? 9 : 4) / energy * 1000)
                      .round() /
                  10,
          };
    final ranges = {
          'carbs': [50, 65],
          'protein': [10, 20],
          'fat': [15, 30],
        },
        flags = <Json>[];
    if (shares != null) {
      for (final k in ranges.keys) {
        final v = shares[k]!, range = ranges[k]!;
        if (v < range[0] || v > range[1]) {
          flags.add({
            'key': k,
            'value': v,
            'direction': v < range[0] ? 'low' : 'high',
            'gap': v < range[0] ? range[0] - v : v - range[1],
          });
        }
      }
      flags.sort((a, b) => numOf(b['gap']).compareTo(numOf(a['gap'])));
    }
    return {
      'days': dates,
      'records': rs,
      'totals': total,
      'shares': shares,
      'flags': flags,
      'status': shares == null
          ? 'unknown'
          : flags.isEmpty
          ? 'balanced'
          : 'adjust',
    };
  }

  List<Json> suggestions(Json r) {
    final shares = r['shares'] as Map?;
    if (shares == null) {
      return [
        {
          'target': 'record',
          'label': '한 끼의 영양정보부터',
          'title': '먹은 양을 남기고\n다음 한 끼를 골라요',
          'evidence': '아직 확인한 영양정보가 없어요.',
          'reason': '사진으로 남기거나 주문 음식의 먹은 양을 확인해요.',
        },
      ];
    }
    final flags = rows(r['flags']),
        primary = flags.firstOrNull,
        labels = {'carbs': '탄수화물', 'protein': '단백질', 'fat': '지방'},
        range = {
          'carbs': [50, 65],
          'protein': [10, 20],
          'fat': [15, 30],
        };
    double distance(Map x) => range.entries.fold<double>(
      0,
      (n, e) =>
          n +
          (numOf(x[e.key]) < e.value[0]
              ? e.value[0] - numOf(x[e.key])
              : numOf(x[e.key]) > e.value[1]
              ? numOf(x[e.key]) - e.value[1]
              : 0),
    );
    Json? profile(dynamic n) {
      if (!validN(n)) {
        return null;
      }
      final x = obj(n),
          e =
              numOf(x['carbs']) * 4 +
              numOf(x['protein']) * 4 +
              numOf(x['fat']) * 9;
      if (e == 0) {
        return null;
      }
      return {
        for (final k in ['carbs', 'protein', 'fat'])
          k: numOf(x[k]) * (k == 'fat' ? 9 : 4) / e * 100,
      };
    }

    final candidates = <Json>[];
    for (final m in catalog.where(
      (m) => m['service'] != 'shopping' && shop(m['shopId'])['open'] == true,
    )) {
      final own = profile(m['nutrition']);
      if (own == null || distance(own) > 0) {
        continue;
      }
      final after = profile({
        for (final k in nutrients)
          k: numOf(r['totals'][k]) + numOf(m['nutrition'][k]),
      });
      if (after == null) {
        continue;
      }
      final dist = distance(after);
      final primaryGap = primary == null
          ? 0.0
          : (numOf(after[primary['key']]) < range[primary['key']]![0]
                ? range[primary['key']]![0] - numOf(after[primary['key']])
                : numOf(after[primary['key']]) > range[primary['key']]![1]
                ? numOf(after[primary['key']]) - range[primary['key']]![1]
                : 0.0);
      if (primary == null
          ? dist == 0
          : dist < distance(shares) - .05 &&
                primaryGap < numOf(primary['gap'])) {
        candidates.add({'item': m, 'distance': dist});
      }
    }
    candidates.sort(
      (a, b) => numOf(a['distance']).compareTo(numOf(b['distance'])),
    );
    final key = primary?['key'] ?? 'carbs', ref = range[key]!, out = <Json>[];
    final title = primary == null
        ? '탄단지 구성,\n참고 범위 안이에요'
        : primary['direction'] == 'high'
        ? '${labels[key]} 비중을\n조금 조절해볼까요?'
        : '${labels[key]}을\n함께 챙겨볼까요?';
    if (candidates.isNotEmpty) {
      out.add({
        'target': 'menu',
        'id': candidates.first['item']['id'],
        'label': primary == null
            ? '탄단지 구성 유지'
            : '${labels[key]} 비중 ${primary['direction'] == 'high' ? '조절' : '보완'}',
        'title': title,
        'value': shares[key],
        'unit': '%',
        'metric': '${labels[key]} 비중 · 참고 ${ref[0]}~${ref[1]}%',
        'evidence':
            '탄수화물 ${shares['carbs']}% · 단백질 ${shares['protein']}% · 지방 ${shares['fat']}%',
        'reason': primary == null
            ? '현재의 구성을 이어가며, 곡류·반찬·채소를 고루 챙겨요.'
            : '곡류·반찬·채소를 함께 골라 한 끼 구성을 맞춰요.',
      });
    }
    final highProtein = flags.any(
          (f) => f['key'] == 'protein' && f['direction'] == 'high',
        ),
        highCarbs = flags.any(
          (f) => f['key'] == 'carbs' && f['direction'] == 'high',
        ),
        lowProtein = flags.any(
          (f) => f['key'] == 'protein' && f['direction'] == 'low',
        );
    if (!highProtein && (primary == null || highCarbs || lowProtein)) {
      out.add({
        'target': 'recipe',
        'id': 'pb-rice',
        'label': '집밥으로 균형 챙기기',
        'title': highCarbs ? '밥은 조금 줄이고,\n달걀·채소를 함께' : '달걀·채소로\n간단한 집밥 한 끼',
        'value': shares['protein'],
        'unit': '%',
        'metric': '단백질 비중 · 참고 10~20%',
        'evidence': highCarbs ? '밥 반 공기와 달걀 2개로 준비해요.' : '밥·달걀·채소를 함께 챙겨요.',
        'reason': '먹을 양을 정하고 기름·양념은 계량해요.',
        'riceHalf': highCarbs,
      });
    }
    if (out.isEmpty) {
      out.add({
        'target': 'record',
        'label': '영양 구성 살펴보기',
        'title': title,
        'evidence': '먹은 양과 메뉴 영양정보를 확인해요.',
        'reason': '기록한 식사를 바탕으로 다음 한 끼를 골라요.',
      });
    }
    out.add({
      'target': 'product',
      'id': 'baemin-easy-pork-gukbap',
      'label': '배민이지 간편식 제안',
      'title': '바쁜 날엔 간편하게,\n배민이지 국밥 한 끼',
      'value': 700,
      'unit': 'g',
      'metric': '판매 용량 · 한 끼 분량과 달라요',
      'evidence': '밥·채소 반찬을 함께 준비해요.',
      'reason': '먹을 만큼 덜어 드세요. 영양성분은 미확인이에요.',
    });
    return out;
  }
}
