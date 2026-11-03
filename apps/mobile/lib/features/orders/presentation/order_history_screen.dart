import 'widgets/recorded_food_card.dart';

import 'package:flutter/material.dart';
import 'package:baemin_flutter/core/state/app_store.dart';
import 'package:baemin_flutter/shared/widgets/ui.dart';
import 'package:baemin_flutter/shared/widgets/tab_page.dart';
import 'package:baemin_flutter/features/orders/presentation/commerce.dart';
import 'package:baemin_flutter/features/catalog/presentation/widgets/catalog_widgets.dart';
import 'package:baemin_flutter/features/nutrition/presentation/nutrition.dart';
import 'package:baemin_flutter/features/food_record/presentation/photo_screen.dart';

import 'widgets/meal_calendar.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({
    super.key,
    required this.store,
    required this.onMarket,
    required this.onSelectTab,
  });
  final AppStore store;
  final MarketNavigator onMarket;
  final ValueChanged<int> onSelectTab;
  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  bool shoppingOrders = false;
  String filter = 'all';
  AppStore get s => widget.store;
  @override
  Widget build(BuildContext context) => Live(
    store: s,
    builder: (_) => TabPage(
      header: TabHeader(
        store: s,
        onCart: () => openCart(context, s),
        title: '주문내역',
      ),
      tabs: ServiceTabs(
        shopping: shoppingOrders,
        onChanged: (v) => setState(() => shoppingOrders = v),
      ),
      scrollKey: PageStorageKey('orders-$shoppingOrders'),
      children: orders(),
    ),
  );
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
      sectionDivider(),
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
      MealCalendar(
        store: s,
        filter: filter,
        onDay: daySheet,
        onBenefit: benefitSheet,
      ),
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
      ...photos.map((r) => RecordedFoodCard(record: r)),
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
              widget.onMarket('bmart');
            } else {
              s.fulfillment = b['type'] == 'pickup' ? 'pickup' : 'delivery';
              s.save();
              widget.onSelectTab(0);
            }
          }),
        ],
      ),
    );
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
}
