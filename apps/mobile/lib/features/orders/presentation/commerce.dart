import 'package:flutter/material.dart';

import 'package:baemin_flutter/core/state/app_store.dart';
import 'package:baemin_flutter/shared/widgets/ui.dart';

Future<bool> addItem(
  BuildContext context,
  AppStore store,
  String id, {
  int count = 1,
}) async {
  try {
    store.addCart(id, quantity: count);
    toast(context, '장바구니에 담았어요.');
    return true;
  } catch (e) {
    if (store.cart.isNotEmpty &&
        store.item(store.cart.keys.first)['shopId'] !=
            store.item(id)['shopId']) {
      if (await confirm(context, '기존 장바구니를 비우고 이 가게의 상품을 담을까요?') &&
          context.mounted) {
        store.addCart(id, quantity: count, replace: true);
        toast(context, '장바구니에 담았어요.');
        return true;
      }
    } else if (context.mounted) {
      toast(context, e.toString().replaceFirst('Bad state: ', ''));
    }
  }
  return false;
}

void openItem(BuildContext c, AppStore s, String id, {String? couponId}) =>
    Navigator.push(
      c,
      MaterialPageRoute(
        builder: (_) => ItemScreen(store: s, id: id, couponId: couponId),
      ),
    );
void openShop(BuildContext c, AppStore s, String id) => Navigator.push(
  c,
  MaterialPageRoute(
    builder: (_) => ShopScreen(store: s, id: id),
  ),
);
void openCart(BuildContext c, AppStore s) =>
    Navigator.push(c, MaterialPageRoute(builder: (_) => CartScreen(store: s)));
void openOrder(BuildContext c, AppStore s, String id) => Navigator.push(
  c,
  MaterialPageRoute(
    builder: (_) => OrderScreen(store: s, id: id),
  ),
);

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key, required this.store, required this.id});
  final AppStore store;
  final String id;
  @override
  Widget build(BuildContext context) => Live(
    store: store,
    builder: (context) {
      final s = store.shop(id),
          items = store.catalog.where((m) => m['shopId'] == id).toList(),
          favorite = (store.state['favorites'] as List).contains(id);
      return PageFrame(
        title: s['name'],
        actions: [
          IconButton(
            onPressed: () => openCart(context, store),
            icon: assetIcon('cart'),
          ),
        ],
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (items.isNotEmpty)
              FoodImage(items.first, height: 240, radius: 0),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: txt(
                          s['name'],
                          size: 25,
                          weight: FontWeight.w800,
                        ),
                      ),
                      IconButton(
                        onPressed: () => store.favorite(id),
                        icon: Icon(
                          favorite ? Icons.favorite : Icons.favorite_border,
                          color: favorite ? Colors.pink : ink,
                        ),
                      ),
                    ],
                  ),
                  txt(shopSummary(s), color: muted),
                  gap(),
                  txt(
                    store.fulfillment == 'pickup' && s['service'] != 'shopping'
                        ? '가게에서 직접 픽업'
                        : '배달팁 0원',
                    weight: FontWeight.w700,
                  ),
                  if (s['address'] != null)
                    txt(s['address'], size: 12, color: muted),
                  txt(
                    '${s['eta'] ?? '20~35분'}${numOf(s['minOrder']) > 0 ? ' · 최소주문 ${won(s['minOrder'])}' : ''}',
                    size: 12,
                    color: muted,
                  ),
                ],
              ),
            ),
            const Divider(thickness: 9, color: surface),
            Padding(
              padding: const EdgeInsets.all(20),
              child: txt('인기 메뉴', size: 18, weight: FontWeight.w800),
            ),
            ...items.map(
              (m) => InkWell(
                onTap: () => openItem(context, store, m['id']),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (m['pb'] == true) pill(m['brand'] ?? 'PB'),
                            txt(m['name'], size: 15, weight: FontWeight.w700),
                            txt(
                              m['unit'] ??
                                  m['description'] ??
                                  '맛있고 든든하게 준비한 한 끼',
                              size: 12,
                              color: muted,
                            ),
                            gap(5),
                            txt(won(m['price']), weight: FontWeight.w800),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      FoodImage(m, width: 94, height: 94),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class ItemScreen extends StatefulWidget {
  const ItemScreen({
    super.key,
    required this.store,
    required this.id,
    this.couponId,
  });
  final AppStore store;
  final String id;
  final String? couponId;
  @override
  State<ItemScreen> createState() => _ItemState();
}

class _ItemState extends State<ItemScreen> {
  late int count = numOf(widget.store.item(widget.id)['defaultQuantity'] ?? 1)
      .toInt();
  late String? coupon = widget.couponId;
  @override
  Widget build(BuildContext context) {
    final s = widget.store,
        m = s.item(widget.id),
        shop = s.shop(m['shopId']),
        available = s.coupons
            .where(
              (c) =>
                  s.quote([
                    {
                      'menuId': m['id'],
                      'unitPrice': m['price'],
                      'quantity': count,
                    },
                  ], couponId: c['id'])['eligible'] ==
                  true,
            )
            .toList();
    final shown =
        available.where((c) => c['id'] == coupon).firstOrNull ??
        available.firstOrNull;
    return PageFrame(
      title: m['service'] == 'shopping' ? '상품 상세' : '메뉴 상세',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 25),
        children: [
          FoodImage(m, height: 300, radius: 0),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                txt(shop['name'], size: 12, color: muted),
                gap(6),
                txt(m['name'], size: 23, weight: FontWeight.w800),
                gap(8),
                txt(m['unit'] ?? m['description'] ?? '신선하게 준비해요', color: muted),
                gap(14),
                txt(won(m['price']), size: 24, weight: FontWeight.w800),
                if (m['nutritionStatus'] == 'estimated' &&
                    validN(m['nutrition'])) ...[
                  gap(16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        txt(
                          '주문 1개 전체 약 ${number(m['nutrition']['calories'])} kcal',
                          weight: FontWeight.w700,
                        ),
                        txt(m['nutritionBasis'], size: 12, color: muted),
                        txt('일반 음식 기준 추정값', size: 11, color: muted),
                      ],
                    ),
                  ),
                ],
                gap(20),
                if (shown != null) ...[
                  InkWell(
                    onTap: () => setState(
                      () => coupon = coupon == shown['id'] ? null : shown['id'],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xfff7f0ff),
                        border: Border.all(color: const Color(0xffd2b5ff)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                pill('내 보유 쿠폰', color: purple),
                                txt(
                                  '${won(shown['discount'])} 할인',
                                  size: 22,
                                  color: primary,
                                  weight: FontWeight.w800,
                                ),
                                txt(
                                  '${shown['expiresAt']}까지',
                                  size: 11,
                                  color: muted,
                                ),
                              ],
                            ),
                          ),
                          txt(
                            coupon == null ? '＋ 적용' : '✓ 적용 중',
                            color: primary,
                            weight: FontWeight.w700,
                          ),
                        ],
                      ),
                    ),
                  ),
                  gap(22),
                ],
                Row(
                  children: [
                    txt('수량', weight: FontWeight.w700),
                    const Spacer(),
                    IconButton(
                      onPressed: count > 1
                          ? () => setState(() => count--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    txt('$count개', size: 17),
                    IconButton(
                      onPressed: count < 10
                          ? () => setState(() => count++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                gap(20),
                actionButton(
                  '장바구니에 담기 · ${won(numOf(m['price']) * count)}',
                  shop['open'] == true
                      ? () async {
                          final added = await addItem(
                            context,
                            s,
                            m['id'],
                            count: count,
                          );
                          if (added) {
                            if (coupon != null &&
                                available.any((c) => c['id'] == coupon)) {
                              s.cartCoupon = coupon;
                              s.save();
                            }
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          }
                        }
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CartScreen extends StatelessWidget {
  const CartScreen({super.key, required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) => Live(
    store: store,
    builder: (context) {
      if (store.cart.isEmpty) {
        return PageFrame(
          title: '장바구니',
          child: Center(
            child: txt('장바구니가 비어 있어요.\n홈에서 먹고 싶은 메뉴를 골라보세요.', color: muted),
          ),
        );
      }
      final shop = store.shop(store.item(store.cart.keys.first)['shopId']),
          q = store.cartQuote,
          available = store.coupons
              .where(
                (c) =>
                    store.quote(
                      store.cartItems,
                      couponId: c['id'],
                    )['eligible'] ==
                    true,
              )
              .toList();
      return PageFrame(
        title: '장바구니',
        background: surface,
        child: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 30),
          children: [
            panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  txt(shop['name'], size: 20, weight: FontWeight.w800),
                  ...store.cart.entries.map((e) {
                    final m = store.item(e.key);
                    return Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Row(
                        children: [
                          FoodImage(m, width: 65, height: 65),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                txt(m['name'], weight: FontWeight.w700),
                                txt(won(numOf(m['price']) * e.value)),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () =>
                                          store.changeQuantity(e.key, -1),
                                      icon: const Icon(Icons.remove, size: 18),
                                    ),
                                    txt('${e.value}'),
                                    IconButton(
                                      onPressed: e.value < 10
                                          ? () => store.changeQuantity(e.key, 1)
                                          : null,
                                      icon: const Icon(Icons.add, size: 18),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            if (shop['service'] != 'shopping')
              panel(
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'delivery', label: Text('배달')),
                    ButtonSegment(value: 'pickup', label: Text('픽업')),
                  ],
                  selected: {store.fulfillment},
                  onSelectionChanged: (v) {
                    store.fulfillment = v.first;
                    store.save();
                  },
                ),
              ),
            panel(
              Column(
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      '${store.cartCoupon}-${available.map((c) => c['id']).join(',')}',
                    ),
                    isExpanded: true,
                    initialValue:
                        available.any((c) => c['id'] == store.cartCoupon)
                        ? store.cartCoupon
                        : null,
                    decoration: const InputDecoration(labelText: '보유 쿠폰'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('쿠폰 선택 안 함'),
                      ),
                      ...available.map(
                        (c) => DropdownMenuItem(
                          value: c['id'] as String,
                          child: txt(
                            c['title'],
                            size: 12,
                            color: purple,
                            lines: 1,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      store.cartCoupon = v;
                      store.save();
                    },
                  ),
                  if (store.cartCoupon != null && q['eligible'] != true) ...[
                    gap(8),
                    txt(q['reason'] as String, size: 12, color: purple),
                    TextButton(
                      onPressed: () {
                        store.cartCoupon = null;
                        store.save();
                      },
                      child: const Text('쿠폰 적용 해제'),
                    ),
                  ],
                  gap(18),
                  _moneyRow('주문금액', q['subtotal']),
                  _moneyRow('배달팁', 0),
                  _moneyRow('쿠폰 할인', -numOf(q['discount']), color: purple),
                  const Divider(),
                  _moneyRow('결제금액', q['total'], large: true),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: actionButton('${won(q['total'])} 주문하기', () async {
                final order = await Navigator.push<Json>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CheckoutScreen(store: store, returnOrder: true),
                  ),
                );
                if (order != null && context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          OrderScreen(store: store, id: order['id']),
                    ),
                  );
                }
              }),
            ),
          ],
        ),
      );
    },
  );
}

Widget _moneyRow(
  String label,
  dynamic value, {
  bool large = false,
  Color color = ink,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Row(
    children: [
      txt(
        label,
        size: large ? 16 : 13,
        weight: large ? FontWeight.w700 : FontWeight.w400,
      ),
      const Spacer(),
      txt(
        won(value),
        size: large ? 23 : 14,
        color: large ? purple : color,
        weight: FontWeight.w700,
      ),
    ],
  ),
);

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.store,
    this.returnOrder = false,
  });
  final AppStore store;
  final bool returnOrder;
  @override
  State<CheckoutScreen> createState() => _CheckoutState();
}

class _CheckoutState extends State<CheckoutScreen> {
  bool submitted = false;
  final request = TextEditingController();
  @override
  void dispose() {
    request.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final shop = store.cart.isEmpty
        ? null
        : store.shop(store.item(store.cart.keys.first)['shopId']);
    final pickup =
        shop?['service'] != 'shopping' && store.fulfillment == 'pickup';
    return PageFrame(
      title: '주문하기',
      background: surface,
      child: ListView(
        padding: const EdgeInsets.only(top: 18),
        children: [
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                txt(
                  pickup ? '가게에서 픽업' : '우리집',
                  size: 21,
                  weight: FontWeight.w800,
                ),
                txt(
                  pickup ? (shop?['name'] ?? '') : '저장된 기본 배달 주소',
                  color: muted,
                ),
                gap(),
                txt(pickup ? '가게 요청사항' : '요청사항', weight: FontWeight.w700),
                TextField(
                  controller: request,
                  decoration: const InputDecoration(hintText: '요청사항을 입력해 주세요.'),
                ),
              ],
            ),
          ),
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                txt('결제수단', size: 18, weight: FontWeight.w700),
                gap(),
                txt('배민페이'),
                _moneyRow(
                  '총 결제금액',
                  widget.store.cartQuote['total'],
                  large: true,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: actionButton(
              '주문 완료하기',
              submitted
                  ? null
                  : () {
                      setState(() => submitted = true);
                      try {
                        final o = widget.store.checkout(
                          deliveryRequest: request.text,
                        );
                        if (widget.returnOrder) {
                          Navigator.pop(context, o);
                          return;
                        }
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                OrderScreen(store: widget.store, id: o['id']),
                          ),
                        );
                      } catch (e) {
                        setState(() => submitted = false);
                        toast(
                          context,
                          e.toString().replaceFirst('Bad state: ', ''),
                        );
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }
}

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key, required this.store, required this.id});
  final AppStore store;
  final String id;
  @override
  State<OrderScreen> createState() => _OrderState();
}

class _OrderState extends State<OrderScreen> {
  final anchors = List.generate(3, (_) => GlobalKey());
  int section = 0;
  AppStore get s => widget.store;
  Widget box(Widget child) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: Color(0xffe3e4e6)),
    ),
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
  Widget heading(String title, GlobalKey key) => Padding(
    key: key,
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: txt(title, size: 18, weight: FontWeight.w800),
  );
  @override
  Widget build(BuildContext context) => Live(
    store: s,
    builder: (context) {
      final o = s.order(widget.id),
          items = rows(o['items']),
          status = o['status'],
          shopping = o['service'] == 'shopping',
          pickup = o['fulfillment'] == 'pickup',
          record = s.recordedOrder(o['id']),
          review = s.reviewFor(o['id']);
      final label = status == 'delivered'
          ? (shopping
                ? '배송이 완료됐어요'
                : pickup
                ? '픽업이 완료됐어요'
                : '배달이 완료됐어요')
          : status == 'cancelled'
          ? '주문이 취소됐어요'
          : orderStatusLabel(o);
      final time = DateTime.parse(o['placedAt'])
          .toUtc()
          .add(const Duration(hours: 9));
      final total = {
        for (final k in nutrients)
          k: items.fold<double>(
            0,
            (n, i) => n + numOf(i['nutrition']?[k]) * numOf(i['quantity']),
          ),
      };
      final hasNutrition =
          !shopping && items.every((i) => validN(i['nutrition']));
      final favorite = (s.state['favorites'] as List).contains(o['shopId']);
      return PageFrame(
        title: '주문상세',
        actions: [
          IconButton(
            onPressed: () => openCart(context, s),
            icon: assetIcon('cart'),
          ),
        ],
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(17, 12, 17, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    if (s.coupons.any((c) => s.couponStatus(c) == 'available'))
                      InkWell(
                        onTap: () => couponsSheet(context, s),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xfff0edff),
                            border: Border.all(color: const Color(0xffaaa1fb)),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          child: txt(
                            '다음 주문에 쓸 수 있는 보유 쿠폰이 있어요!',
                            size: 12,
                            color: purple,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    box(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          txt(label, size: 26, weight: FontWeight.w800),
                          gap(8),
                          txt(
                            shopping
                                ? '장보기·쇼핑'
                                : pickup
                                ? '포장·픽업'
                                : '음식배달',
                            size: 13,
                            color: muted,
                          ),
                          txt(
                            '주문일시 ${time.year}년 ${time.month}월 ${time.day}일 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                            size: 12,
                            color: muted,
                          ),
                          txt(
                            '주문번호 ${o['id'].toString().replaceFirst('order-', '').toUpperCase()}',
                            size: 11,
                            color: muted,
                          ),
                          gap(18),
                          const Divider(),
                          Row(
                            children: [
                              FoodImage(items.first, width: 44, height: 44),
                              const SizedBox(width: 10),
                              Expanded(
                                child: InkWell(
                                  onTap: () =>
                                      openShop(context, s, o['shopId']),
                                  child: txt(
                                    o['shopName'],
                                    size: 18,
                                    weight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => s.favorite(o['shopId']),
                                icon: Icon(
                                  favorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: favorite ? Colors.pink : ink,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _OrderTabs(
                selected: section,
                onTap: (i) {
                  setState(() => section = i);
                  final ctx = anchors[i].currentContext;
                  if (ctx != null) {
                    Scrollable.ensureVisible(
                      ctx,
                      alignment: .12,
                      duration: const Duration(milliseconds: 230),
                      curve: Curves.easeOut,
                    );
                  }
                },
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(17, 0, 17, 30),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    heading('주문 메뉴', anchors[0]),
                    box(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final item in items) ...[
                            txt(
                              item['name'],
                              size: 17,
                              weight: FontWeight.w800,
                            ),
                            txt(
                              '· 가격: (${won(item['unitPrice'])})',
                              size: 12,
                              color: muted,
                            ),
                            gap(10),
                            Row(
                              children: [
                                txt(
                                  won(
                                    numOf(item['unitPrice']) *
                                        numOf(item['quantity']),
                                  ),
                                  size: 18,
                                  weight: FontWeight.w800,
                                ),
                                const Spacer(),
                                txt(
                                  '${item['quantity']}개',
                                  size: 13,
                                  color: muted,
                                ),
                              ],
                            ),
                            gap(18),
                          ],
                          if (!shopping)
                            Row(
                              children: [
                                Expanded(
                                  child: actionButton(
                                    '같은 메뉴 담기',
                                    s.shop(o['shopId'])['open'] == true
                                        ? () => reorderItems(context, s, o)
                                        : null,
                                    secondary: true,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: actionButton(
                                    '바로 주문',
                                    s.shop(o['shopId'])['open'] == true
                                        ? () => reorderItems(
                                            context,
                                            s,
                                            o,
                                            goCart: true,
                                          )
                                        : null,
                                  ),
                                ),
                              ],
                            )
                          else
                            actionButton(
                              '가게 둘러보기',
                              () => openShop(context, s, o['shopId']),
                              secondary: true,
                            ),
                          if (status == 'delivered') ...[
                            gap(10),
                            actionButton(
                              review == null
                                  ? '리뷰 쓰기'
                                  : '★ 내 리뷰 ${review['rating']}점 보기',
                              () => reviewSheet(context, s, o),
                              secondary: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (status != 'delivered' && status != 'cancelled') ...[
                      gap(12),
                      box(
                        Column(
                          children: [
                            txt(
                              orderStatusLabel(o),
                              size: 16,
                              weight: FontWeight.w700,
                            ),
                            gap(),
                            actionButton(
                              {
                                'pending': shopping ? '상품 준비 시작' : '주문 접수하기',
                                'preparing': shopping
                                    ? '배송 시작'
                                    : pickup
                                    ? '픽업 준비 완료'
                                    : '배달 시작',
                                'delivering': pickup ? '픽업 완료' : '도착 완료',
                              }[status]!,
                              () => s.advance(o['id']),
                            ),
                            if (status == 'pending') ...[
                              gap(8),
                              actionButton(
                                '주문 취소',
                                () => s.advance(o['id'], cancel: true),
                                secondary: true,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    heading('결제 정보', anchors[1]),
                    box(
                      Column(
                        children: [
                          _moneyRow('메뉴금액', o['amount']['subtotal']),
                          _moneyRow('배달팁', o['amount']['deliveryFee']),
                          if (numOf(o['amount']['discount']) > 0)
                            _moneyRow(
                              '쿠폰 할인',
                              -numOf(o['amount']['discount']),
                              color: purple,
                            ),
                          const Divider(),
                          _moneyRow('총 결제금액', o['amount']['paid'], large: true),
                          gap(8),
                          Row(
                            children: [
                              txt('결제수단', size: 12, color: muted),
                              const Spacer(),
                              txt(
                                o['paymentMethod'] ?? '배민페이',
                                size: 12,
                                color: muted,
                              ),
                            ],
                          ),
                          if (status == 'cancelled')
                            _moneyRow('취소금액', o['amount']['refunded']),
                        ],
                      ),
                    ),
                    heading(
                      shopping
                          ? '배송 정보'
                          : pickup
                          ? '픽업 정보'
                          : '배달 정보',
                      anchors[2],
                    ),
                    box(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          txt(
                            pickup ? '픽업 가게' : '받는 주소',
                            weight: FontWeight.w700,
                          ),
                          gap(4),
                          txt(
                            pickup
                                ? o['shopName']
                                : o['deliveryAddress'] ?? '우리집',
                            size: 13,
                            color: muted,
                          ),
                          gap(18),
                          const Divider(),
                          txt('배달 요청사항', weight: FontWeight.w700),
                          txt(
                            o['deliveryRequest'] ?? '문 앞에 놓아주세요',
                            size: 13,
                            color: muted,
                          ),
                          gap(18),
                          const Divider(),
                          txt('주문 방식', weight: FontWeight.w700),
                          txt(
                            shopping
                                ? '장보기·쇼핑'
                                : pickup
                                ? '픽업'
                                : '배달',
                            size: 13,
                            color: muted,
                          ),
                        ],
                      ),
                    ),
                    if (hasNutrition) ...[
                      gap(24),
                      txt('이 주문의 한 끼', size: 18, weight: FontWeight.w800),
                      gap(12),
                      box(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            txt('주문 메뉴 전체 영양정보', size: 12, color: muted),
                            gap(8),
                            txt(
                              '${number(numOf(total['calories']))} kcal',
                              size: 29,
                              weight: FontWeight.w800,
                            ),
                            txt(
                              '탄수화물 ${decimal(numOf(total['carbs']))}g · 단백질 ${decimal(numOf(total['protein']))}g · 지방 ${decimal(numOf(total['fat']))}g',
                              size: 12,
                              color: muted,
                            ),
                            if (status == 'delivered') ...[
                              gap(16),
                              actionButton(
                                record == null
                                    ? '먹은 양 확인하고 식사로 기록'
                                    : '기록한 식사 확인',
                                () => record == null
                                    ? consumeSheet(context, s, o)
                                    : recordedMealSheet(context, record),
                                secondary: true,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (rows(s.state['pointLedger'])
                        .any((p) => p['orderId'] == o['id'])) ...[
                      gap(12),
                      box(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            txt(
                              '이 주문으로 챙긴 혜택',
                              size: 14,
                              color: primary,
                              weight: FontWeight.w700,
                            ),
                            ...rows(s.state['pointLedger'])
                                .where((p) => p['orderId'] == o['id'])
                                .map(
                                  (p) => txt(
                                    '+${number(p['points'])}P · ${p['title']}',
                                    color: primary,
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _OrderTabs extends SliverPersistentHeaderDelegate {
  _OrderTabs({required this.selected, required this.onTap});
  final int selected;
  final ValueChanged<int> onTap;
  @override
  double get minExtent => 60;
  @override
  double get maxExtent => 60;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Material(
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
      child: Row(
        children: List.generate(
          3,
          (i) => Padding(
            padding: const EdgeInsets.only(right: 7),
            child: ChoiceChip(
              label: txt(
                ['주문 메뉴', '결제 정보', '배달 정보'][i],
                size: 12,
                color: i == selected ? Colors.white : ink,
              ),
              selected: i == selected,
              selectedColor: ink,
              showCheckmark: false,
              onSelected: (_) => onTap(i),
            ),
          ),
        ),
      ),
    ),
  );
  @override
  bool shouldRebuild(covariant _OrderTabs old) => selected != old.selected;
}

Future<void> reorderItems(
  BuildContext context,
  AppStore store,
  Json order, {
  bool goCart = false,
}) async {
  final different =
      store.cart.isNotEmpty &&
      store.item(store.cart.keys.first)['shopId'] != order['shopId'];
  if (different && !await confirm(context, '기존 장바구니를 비우고 같은 메뉴를 담을까요?')) {
    return;
  }
  try {
    store.reorder(order, replace: different);
    if (context.mounted) {
      if (goCart) {
        openCart(context, store);
      } else {
        toast(context, '같은 메뉴를 장바구니에 담았어요.');
      }
    }
  } catch (error) {
    if (context.mounted) {
      toast(context, error.toString().replaceFirst('Bad state: ', ''));
    }
  }
}

Future<void> recordedMealSheet(BuildContext context, Json record) => sheet(
  context,
  '기록한 식사 확인',
  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      pill('식사 기록 완료'),
      gap(12),
      txt(record['name'], size: 20, weight: FontWeight.w800),
      txt('먹은 날짜 ${record['date']}', size: 13, color: muted),
      gap(18),
      txt(
        '${number(numOf(record['nutrition']['calories']))} kcal',
        size: 28,
        color: primary,
        weight: FontWeight.w800,
      ),
      txt(
        '탄수화물 ${decimal(numOf(record['nutrition']['carbs']))}g · 단백질 ${decimal(numOf(record['nutrition']['protein']))}g · 지방 ${decimal(numOf(record['nutrition']['fat']))}g',
        size: 13,
      ),
      if (record['analysis'] is Map) ...[
        gap(12),
        pill(
          record['analysis']['userEdited'] == true ? '사진 분석 후 수정' : '사진 분석 추정값',
        ),
        txt(
          '사진 속 음식의 ${decimal(numOf(record['analysis']['consumedFraction']) * 100)}% 기준',
          size: 12,
          color: muted,
        ),
        if ((record['analysis']['ingredients'] as List? ?? []).isNotEmpty)
          txt(
            (record['analysis']['ingredients'] as List).join(' · '),
            size: 12,
            color: muted,
          ),
      ],
      if (record['portion'] != null)
        txt(
          '주문 음식의 ${decimal(numOf(record['portion']) * 100)}% 확인',
          size: 12,
          color: muted,
        ),
    ],
  ),
);

Future<void> consumeSheet(
  BuildContext context,
  AppStore store,
  Json order,
) async {
  final items = rows(order['items']);
  final servings = items.length == 1
      ? numOf(items.single['servings'] ?? 1) * numOf(items.single['quantity'])
      : 1.0;
  double portion = servings > 1 ? 1 / servings : 1;
  final portions = {
    ...[.1, .25, .5, .75, 1.0],
    portion,
  }.toList()..sort();
  final totalCalories = items.fold<double>(
    0,
    (sum, i) => sum + numOf(i['nutrition']?['calories']) * numOf(i['quantity']),
  );
  String date = store.selected;
  await sheet(
    context,
    '먹은 양 확인',
    StatefulBuilder(
      builder: (ctx, set) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          txt(order['items'][0]['name'], size: 20, weight: FontWeight.w800),
          gap(6),
          txt(
            '주문한 음식 전체 약 ${number(totalCalories)} kcal',
            size: 13,
            color: muted,
          ),
          if (servings > 1)
            txt('나눠 먹는 메뉴예요. 내가 먹은 몫을 선택해 주세요.', size: 13, color: muted),
          gap(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: txt('먹은 날짜'),
            trailing: txt(date, color: primary),
            onTap: () async {
              final d = await showDatePicker(
                context: ctx,
                initialDate: parseDay(date),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (d != null) {
                set(() => date = dateKey(d));
              }
            },
          ),
          DropdownButtonFormField<double>(
            initialValue: portion,
            decoration: const InputDecoration(labelText: '주문한 전체 음식 중 내가 먹은 양'),
            items: portions
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text('${decimal(v * 100)}%'),
                  ),
                )
                .toList(),
            onChanged: (v) => set(() => portion = v!),
          ),
          gap(12),
          txt(
            '기록할 열량 약 ${number(totalCalories * portion)} kcal',
            size: 18,
            weight: FontWeight.w700,
          ),
          gap(22),
          actionButton('식사 기록 완료', () {
            try {
              store.recordOrder(order['id'], date, portion);
              Navigator.pop(context);
            } catch (e) {
              toast(context, e.toString());
            }
          }),
        ],
      ),
    ),
  );
}

Future<void> reviewSheet(
  BuildContext context,
  AppStore store,
  Json order,
) async {
  final existing = store.reviewFor(order['id']);
  if (existing != null) {
    await sheet(
      context,
      '내 리뷰',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          txt(order['shopName'], size: 20, weight: FontWeight.w800),
          gap(12),
          txt(
            '★ ' * ((existing['rating'] as num).toInt()),
            size: 26,
            color: Colors.amber,
          ),
          gap(12),
          txt(existing['text'].toString().replaceAll(' (시연 리뷰)', '')),
        ],
      ),
    );
    return;
  }
  int rating = 5;
  final controller = TextEditingController();
  await sheet(
    context,
    '리뷰 쓰기',
    StatefulBuilder(
      builder: (ctx, set) => Column(
        children: [
          txt(order['shopName'], size: 20, weight: FontWeight.w700),
          gap(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (i) => IconButton(
                onPressed: () => set(() => rating = i + 1),
                icon: Icon(
                  i < rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 32,
                ),
              ),
            ),
          ),
          field(controller, '맛있게 드셨나요?', lines: 3),
          actionButton('리뷰 등록', () {
            store.review(order['id'], rating, controller.text);
            Navigator.pop(context);
            toast(context, '리뷰를 등록했어요.');
          }),
        ],
      ),
    ),
  );
  controller.dispose();
}

Future<void> couponsSheet(BuildContext context, AppStore store) async {
  await sheet(
    context,
    '보유 쿠폰',
    Column(
      children: store.coupons.map((c) {
        final available = store.couponStatus(c) == 'available';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: available ? const Color(0xfff7f0ff) : surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: available ? const Color(0xffc5a0ff) : surface,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              txt(
                c['title'],
                size: 17,
                color: available ? purple : muted,
                weight: FontWeight.w800,
              ),
              txt(c['description'] ?? '', size: 12, color: muted),
              txt(
                '${won(c['minOrder'])} 이상 · ${c['expiresAt']}까지',
                size: 11,
                color: muted,
              ),
              gap(9),
              if (available)
                actionButton('쓸 수 있는 곳 보기', () {
                  Navigator.pop(context);
                  openShop(context, store, c['shopId']);
                }, secondary: true)
              else
                txt(
                  store.couponStatus(c) == 'used' ? '사용 완료' : '기간 만료',
                  color: muted,
                ),
            ],
          ),
        );
      }).toList(),
    ),
  );
}

class BaeminEasyRail extends StatelessWidget {
  const BaeminEasyRail({
    super.key,
    required this.store,
    required this.onBrowse,
  });
  final AppStore store;
  final VoidCallback onBrowse;
  @override
  Widget build(BuildContext context) {
    final products =
        store.catalog
            .where((p) => p['brand'] == '배민이지' && p['service'] == 'shopping')
            .toList()
          ..sort(
            (a, b) =>
                numOf(a['featuredOrder'] ?? 99)
                    .compareTo(numOf(b['featuredOrder'] ?? 99)),
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 8, 17, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              pill('배민이지'),
              const SizedBox(width: 6),
              txt('B마트 PB', size: 11, color: primary),
              const Spacer(),
              TextButton(
                onPressed: onBrowse,
                child: txt('전체보기 ›', size: 11, color: muted),
              ),
            ],
          ),
          gap(10),
          txt(
            'B마트에서 만난 배민이지,\n한 끼 준비를 간편하게',
            size: 20,
            weight: FontWeight.w800,
          ),
          gap(6),
          txt('우유부터 냉동 국·탕까지, 식사 구성과 먹을 양에 맞춰 골라보세요.', size: 12, color: muted),
          gap(16),
          SizedBox(
            height: 340 * MediaQuery.textScalerOf(context).scale(1),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              separatorBuilder: (_, i) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final p = products[i];
                return Container(
                  width: 158,
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xffe1e7e4)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => openItem(context, store, p['id']),
                        child: FoodImage(p, width: 140, height: 140, radius: 9),
                      ),
                      gap(8),
                      pill(
                        p['storage'] == '냉동'
                            ? '냉동 · 간편국·탕'
                            : p['kind'] == 'tofu'
                            ? '두부 반찬 준비'
                            : '냉장 · 우유',
                      ),
                      gap(5),
                      txt(
                        p['name']
                            .toString()
                            .replaceAll('[냉동]', '')
                            .replaceAll('[배민이지]', '')
                            .trim(),
                        size: 12,
                        weight: FontWeight.w700,
                        lines: 2,
                      ),
                      txt(p['unit'], size: 11, color: muted),
                      const Spacer(),
                      Row(
                        children: [
                          if (p['discountPercent'] != null)
                            txt(
                              '${p['discountPercent']}% ',
                              size: 16,
                              color: primary,
                              weight: FontWeight.w800,
                            ),
                          txt(
                            won(p['price']),
                            size: 17,
                            weight: FontWeight.w800,
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 20,
                        child: p['listPrice'] != null
                            ? Text(
                                won(p['listPrice']),
                                style: textStyle(10, muted).copyWith(
                                  decoration: TextDecoration.lineThrough,
                                ),
                              )
                            : null,
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            foregroundColor: primary,
                            backgroundColor: const Color(0xfff0fbf7),
                            side: const BorderSide(color: Color(0xffbce5db)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                          onPressed: () => addItem(context, store, p['id']),
                          child: txt(
                            '＋ 담기',
                            size: 12,
                            color: primary,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          gap(12),
          actionButton('배민이지로 장보기  ›', onBrowse, secondary: true),
        ],
      ),
    );
  }
}
