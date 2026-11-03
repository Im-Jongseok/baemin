import 'package:flutter/material.dart';

import 'package:baemin_flutter/core/state/app_store.dart';
import 'package:baemin_flutter/shared/widgets/ui.dart';
import 'package:baemin_flutter/features/orders/presentation/commerce.dart';

class NutritionPreview extends StatefulWidget {
  const NutritionPreview({
    super.key,
    required this.store,
    this.full = false,
    this.onRecord,
  });
  final AppStore store;
  final bool full;
  final VoidCallback? onRecord;
  @override
  State<NutritionPreview> createState() => _NutritionState();
}

class _NutritionState extends State<NutritionPreview> {
  int index = 0;
  bool prepOpen = false;
  final pages = PageController();
  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  void detail() {
    final s = widget.store;
    if (!s.club) {
      sheet(
        context,
        '배민클럽 회원 전용',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            pill('배민클럽', color: purple),
            gap(),
            txt(
              '나의 한 끼를 더 자세히,\n클럽 회원 전용 리포트',
              size: 24,
              weight: FontWeight.w800,
            ),
            gap(),
            txt('주간·월간 식사 구성과 영양 정보를 확인해요.', color: muted),
            gap(20),
            actionButton('배민클럽 시작하고 자세히 보기', () {
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
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReportScreen(store: s)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store,
        r = s.report(),
        suggestions = s.suggestions(r),
        count = suggestions.length;
    index = index.clamp(0, count - 1);
    final selected = suggestions[index], dates = s.reportDays();
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.full) ...[
            InkWell(
              onTap: detail,
              child: Row(
                children: [
                  txt('나의 식습관 리포트', size: 15, weight: FontWeight.w800),
                  const SizedBox(width: 6),
                  pill('NEW'),
                  const Spacer(),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
            gap(14),
            InkWell(
              onTap: detail,
              child: Row(
                children: [
                  pill('배민클럽', color: Colors.white, bg: ink),
                  const SizedBox(width: 7),
                  Expanded(
                    child: txt(
                      s.club ? '회원 전용 리포트 자세히 보기' : '클럽 회원만 자세히 볼 수 있어요',
                      size: 11,
                      color: muted,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 14, color: muted),
                ],
              ),
            ),
            gap(14),
          ],
          txt(
            '${dates.first.substring(5).replaceAll('-', '.')} — ${dates.last.substring(5).replaceAll('-', '.')} ${s.state['view'] == 'month' ? '월간' : '주간'}',
            size: 12,
            color: muted,
          ),
          gap(18),
          macroStats(r),
          gap(10),
          txt('기록한 식사의 에너지 구성', size: 11, color: muted),
          gap(20),
          txt('민수님의 영양 균형에 맞춘 제안', size: 13, weight: FontWeight.w700),
          gap(12),
          SizedBox(
            height:
                390 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.8),
            child: PageView.builder(
              controller: pages,
              itemCount: count,
              onPageChanged: (i) => setState(() {
                index = i;
                prepOpen = false;
              }),
              itemBuilder: (ctx, i) => suggestionCard(suggestions[i]),
            ),
          ),
          gap(8),
          Row(
            children: [
              Expanded(
                child: txt('내 기록에 맞는 $count가지 제안', size: 11, color: muted),
              ),
              IconButton(
                onPressed: index > 0
                    ? () => pages.previousPage(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                      )
                    : null,
                icon: const Icon(Icons.chevron_left),
                visualDensity: VisualDensity.compact,
              ),
              txt(
                '${index + 1} / $count',
                size: 12,
                color: muted,
                weight: FontWeight.w700,
              ),
              IconButton(
                onPressed: index < count - 1
                    ? () => pages.nextPage(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                      )
                    : null,
                icon: const Icon(Icons.chevron_right),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          Preparation(
            store: s,
            suggestion: selected,
            open: prepOpen,
            onChanged: (v) => setState(() => prepOpen = v),
          ),
        ],
      ),
      padding: const EdgeInsets.all(17),
    );
  }

  Widget suggestionCard(Json q) {
    final s = widget.store, target = q['target'];
    Json? food;
    if (target == 'menu' || target == 'product') {
      food = s.item(q['id']);
    } else if (target == 'recipe') {
      food = {'kind': 'bowl', 'name': '달걀 채소 볶음밥'};
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          if (target == 'recipe') {
            setState(() => prepOpen = !prepOpen);
          } else if (food != null && q['id'] != null) {
            openItem(context, s, q['id']);
          } else {
            widget.onRecord?.call();
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xfffcfdfd),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xffdfe5e5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              pill(q['label']),
              gap(13),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: txt(q['title'], size: 20, weight: FontWeight.w800),
                  ),
                  const SizedBox(width: 8),
                  if (food != null)
                    FoodImage(food, width: 66, height: 66, radius: 17)
                  else
                    const Icon(
                      Icons.camera_alt_outlined,
                      size: 40,
                      color: primary,
                    ),
                ],
              ),
              gap(18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xfff3f6f5),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: const Color(0xffe1e7e4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    txt(
                      q['target'] == 'product'
                          ? '간편식 한 팩'
                          : q['target'] == 'recipe'
                          ? '집밥 한 끼 구성'
                          : '기록한 식사의 영양 구성',
                      size: 12,
                      color: const Color(0xff56645e),
                      weight: FontWeight.w600,
                    ),
                    if (q['value'] != null) ...[
                      gap(8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text.rich(
                            TextSpan(
                              text: decimal(numOf(q['value'])),
                              style: textStyle(34, primary, FontWeight.w800),
                              children: [
                                TextSpan(
                                  text: q['unit'],
                                  style: textStyle(
                                    14,
                                    primary,
                                    FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: txt(
                              q['metric'],
                              size: 12,
                              color: const Color(0xff46534f),
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                    gap(8),
                    txt(q['evidence'], size: 13, weight: FontWeight.w600),
                  ],
                ),
              ),
              gap(13),
              txt(q['reason'], size: 13, color: const Color(0xff4d5954)),
            ],
          ),
        ),
      ),
    );
  }
}

Widget macroStats(Json report) => Row(
  children: [
    for (final e in {'carbs': '탄수화물', 'protein': '단백질', 'fat': '지방'}.entries)
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            txt(e.value, size: 11, color: ink),
            gap(6),
            Text.rich(
              TextSpan(
                text: report['shares'] == null
                    ? '—'
                    : decimal(numOf(report['shares'][e.key])),
                style: textStyle(26, ink, FontWeight.w800),
                children: [
                  if (report['shares'] != null)
                    TextSpan(text: '%', style: textStyle(11, ink)),
                ],
              ),
            ),
          ],
        ),
      ),
  ],
);

class Preparation extends StatelessWidget {
  const Preparation({
    super.key,
    required this.store,
    required this.suggestion,
    this.open = false,
    this.onChanged,
  });
  final AppStore store;
  final Json suggestion;
  final bool open;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) {
    final target = suggestion['target'];
    Json? recipe;
    final products = <Json>[];
    if (target == 'recipe') {
      recipe = store.recipes.firstWhere((r) => r['id'] == suggestion['id']);
    } else if (target == 'product') {
      products.add(store.item(suggestion['id']));
    } else if (suggestion['id'] == 'soy-bowl') {
      products.add(store.item('baemin-easy-tofu'));
    }
    if (recipe == null && products.isEmpty) {
      return const SizedBox.shrink();
    }
    final name =
        recipe?['name'] ?? (products.isNotEmpty ? products.first['name'] : '');
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xffa4e7d9)),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: ValueKey('${suggestion['id']}-$open'),
        initiallyExpanded: open,
        onExpansionChanged: onChanged,
        shape: const Border(),
        collapsedShape: const Border(),
        backgroundColor: Colors.white,
        collapsedBackgroundColor: const Color(0xffe5faf5),
        iconColor: primary,
        textColor: primary,
        title: txt(
          target == 'product' ? '간편하게 한 끼 준비하기' : '직접 만들어 먹기',
          color: primary,
          weight: FontWeight.w800,
        ),
        subtitle: txt(
          target == 'recipe' ? '$name · 레시피와 PB 재료' : '$name · 배민이지',
          size: 11,
          color: const Color(0xff416b60),
        ),
        childrenPadding: const EdgeInsets.all(13),
        children: [
          if (recipe != null)
            RecipeContent(store: store, recipe: recipe, suggestion: suggestion)
          else
            ...products.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    FoodImage(p, width: 85, height: 85),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          pill('배민이지'),
                          txt(
                            p['name']
                                .toString()
                                .replaceAll('[냉동]', '')
                                .replaceAll('[배민이지]', ''),
                            size: 13,
                            weight: FontWeight.w700,
                          ),
                          txt('${p['unit']} · ${won(p['price'])}', size: 12),
                          TextButton(
                            onPressed: () => addItem(context, store, p['id']),
                            child: const Text('＋ 담기'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class RecipeContent extends StatelessWidget {
  const RecipeContent({
    super.key,
    required this.store,
    required this.recipe,
    this.suggestion,
  });
  final AppStore store;
  final Json recipe;
  final Json? suggestion;
  @override
  Widget build(BuildContext context) {
    final items = rows(recipe['items']), half = suggestion?['riceHalf'] == true;
    final quote = store.quote(
      items
          .map((i) => {...i, 'unitPrice': store.item(i['menuId'])['price']})
          .toList(),
      couponId: recipe['couponId'],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        txt(
          '${recipe['minutes']}분 · ${recipe['servings']}인분 · ${recipe['difficulty']}',
          size: 12,
          color: primary,
          weight: FontWeight.w700,
        ),
        gap(8),
        txt(recipe['name'], size: 22, weight: FontWeight.w800),
        txt(
          recipe['description'].toString().replaceAll(
            '밥 한 공기',
            half ? '밥 반 공기' : '밥 한 공기',
          ),
          size: 13,
          color: muted,
        ),
        gap(18),
        Row(
          children: [
            Expanded(child: txt('이 레시피에 필요한 재료', weight: FontWeight.w700)),
            txt('B마트 · PB 포함', size: 11, color: muted),
          ],
        ),
        gap(12),
        SizedBox(
          height: 90 + 190 * MediaQuery.textScalerOf(context).scale(1),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, i) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final p = store.item(items[i]['menuId']);
              return Container(
                width: 106,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xffe1e7e4)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FoodImage(p, width: 90, height: 90, radius: 7),
                    gap(7),
                    txt('${recipe['amounts'][i]} 사용', size: 10, color: primary),
                    txt(p['name'], size: 12, weight: FontWeight.w700, lines: 2),
                    txt('판매 단위 ${p['unit']}', size: 10, color: muted),
                    const Spacer(),
                    txt(won(p['price']), size: 13, weight: FontWeight.w800),
                    InkWell(
                      onTap: () => openItem(context, store, p['id']),
                      child: txt('상품 보기 ›', size: 11, color: primary),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        gap(12),
        txt('집에 있는 재료', size: 12, color: primary, weight: FontWeight.w700),
        txt(
          '${half ? '밥 반 공기로 준비해요. ' : ''}${recipe['pantry']}',
          size: 12,
          color: muted,
        ),
        gap(12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xffdfe7e3)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            title: txt(
              '레시피 · ${(recipe['steps'] as List).length}단계',
              weight: FontWeight.w700,
            ),
            trailing: txt(
              '자세히 보기',
              size: 12,
              color: primary,
              weight: FontWeight.w700,
            ),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              for (var i = 0; i < (recipe['steps'] as List).length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      txt(
                        (i + 1).toString().padLeft(2, '0'),
                        size: 18,
                        color: primary,
                        weight: FontWeight.w800,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            txt(
                              recipe['stepTitles'][i],
                              weight: FontWeight.w700,
                            ),
                            gap(5),
                            txt(
                              recipe['steps'][i].toString().replaceAll(
                                '밥 한 공기',
                                half ? '밥 반 공기' : '밥 한 공기',
                              ),
                              size: 13,
                              color: muted,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              txt('맛있게 만드는 팁', weight: FontWeight.w700),
              txt(recipe['tips'], size: 12, color: muted),
              gap(16),
            ],
          ),
        ),
        gap(18),
        Row(
          children: [
            txt('재료 한 팩씩 구매하면', size: 12, color: muted),
            const Spacer(),
            txt(won(quote['subtotal']), weight: FontWeight.w700),
          ],
        ),
        if (quote['eligible'] == true) ...[
          gap(8),
          Row(
            children: [
              txt('내 보유 쿠폰 적용', size: 12, color: primary),
              const Spacer(),
              txt(
                '−${won(quote['discount'])}',
                color: primary,
                weight: FontWeight.w700,
              ),
            ],
          ),
        ],
        gap(10),
        txt(recipe['note'], size: 11, color: muted),
        gap(12),
        actionButton('재료 한 번에 담기 · ${won(quote['total'])}', () async {
          final different =
              store.cart.isNotEmpty &&
              store.item(store.cart.keys.first)['shopId'] != recipe['shopId'];
          if (different &&
              !await confirm(context, '기존 장바구니를 비우고 레시피 재료를 담을까요?')) {
            return;
          }
          try {
            store.addRecipe(recipe, replace: different);
          } catch (error) {
            if (context.mounted) {
              toast(context, error.toString().replaceFirst('Bad state: ', ''));
            }
            return;
          }
          if (context.mounted) {
            openCart(context, store);
          }
        }),
      ],
    );
  }
}

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key, required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) => Live(
    store: store,
    builder: (context) {
      final r = store.report(),
          rs = rows(r['records']),
          total = obj(r['totals']),
          dates = List<String>.from(r['days']);
      final buckets = dates.length > 7
          ? List.generate(
              (dates.length / 4).ceil(),
              (i) => dates.skip(i * 4).take(4).toList(),
            )
          : dates.map((d) => [d]).toList();
      final bucketMax = buckets.fold<double>(1, (best, group) {
        final value = numOf(
          store.totals(
            rs.where((r) => group.contains(r['date'])).toList(),
          )['calories'],
        );
        return value > best ? value : best;
      });
      final sources = <String, int>{'배달': 0, '픽업': 0, '직접 기록': 0, '연결 미확인': 0};
      int vegetableMeals = 0, knownMenuMeals = 0;
      for (final record in rs) {
        final order = store.orders
            .where((o) => o['id'] == record['orderId'])
            .firstOrNull;
        final source = record['orderId'] == null
            ? '직접 기록'
            : order == null
            ? '연결 미확인'
            : order['fulfillment'] == 'pickup'
            ? '픽업'
            : '배달';
        sources[source] = sources[source]! + 1;
        if (order != null) {
          knownMenuMeals++;
          if (rows(order['items']).any(
            (i) => [
              'bibimbap',
              'salmon',
              'salad-poke',
              'soy-bowl',
            ].contains(i['menuId']),
          )) {
            vegetableMeals++;
          }
        }
      }
      final suggestions = store.suggestions(r), personal = suggestions.first;
      final recipeAnchor = GlobalKey(),
          menuAnchor = GlobalKey(),
          couponAnchor = GlobalKey();
      void jump(GlobalKey key) {
        final ctx = key.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            alignment: .08,
            duration: const Duration(milliseconds: 230),
            curve: Curves.easeOut,
          );
        }
      }

      final matches = <Json>[];
      for (final suggestion in suggestions) {
        if (suggestion['target'] == 'recipe') {
          final recipe = store.recipes.firstWhere(
            (r) => r['id'] == suggestion['id'],
          );
          final q = store.quote(
            rows(recipe['items'])
                .map(
                  (line) => {
                    ...line,
                    'unitPrice': store.item(line['menuId'])['price'],
                  },
                )
                .toList(),
            couponId: recipe['couponId'],
          );
          if (q['eligible'] == true) {
            matches.add({
              'discount': q['discount'],
              'name': recipe['name'],
              'key': recipeAnchor,
            });
          }
        }
        if (suggestion['target'] == 'menu') {
          final m = store.item(suggestion['id']);
          for (final c in store.coupons) {
            final q = store.quote([
              {'menuId': m['id'], 'quantity': 1, 'unitPrice': m['price']},
            ], couponId: c['id']);
            if (q['eligible'] == true) {
              matches.add({
                'discount': q['discount'],
                'name': m['name'],
                'key': menuAnchor,
              });
            }
          }
        }
      }
      matches.sort(
        (a, b) => numOf(b['discount']).compareTo(numOf(a['discount'])),
      );
      final completed = store.orders
          .where(
            (o) =>
                o['service'] != 'shopping' &&
                o['status'] == 'delivered' &&
                dates.contains(orderDay(o)),
          )
          .toList();
      final unconfirmed = completed
          .where((o) => store.recordedOrder(o['id']) == null)
          .length;
      return PageFrame(
        title: '식습관 리포트',
        actions: [
          IconButton(
            tooltip: '계산 기준',
            onPressed: () => reportMethod(context),
            icon: const Icon(Icons.info_outline, size: 22, color: muted),
          ),
        ],
        background: surface,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 16, bottom: 30),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'week', label: Text('주간')),
                        ButtonSegment(value: 'month', label: Text('월간')),
                      ],
                      selected: {store.state['view'] ?? 'week'},
                      onSelectionChanged: (v) => store.setView(v.first),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => store.shiftPeriod(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      onPressed: () => store.shiftPeriod(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
              gap(16),
              panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    txt(
                      '${dates.first.substring(5).replaceAll('-', '.')} — ${dates.last.substring(5).replaceAll('-', '.')} ${store.state['view'] == 'month' ? '월간' : '주간'}',
                      size: 12,
                      color: muted,
                    ),
                    gap(18),
                    txt(
                      '민수님의 한 끼 돌아보기',
                      size: 12,
                      color: primary,
                      weight: FontWeight.w700,
                    ),
                    gap(8),
                    txt(
                      '영양 균형을 살펴보고\n다음 한 끼를 골라요',
                      size: 25,
                      weight: FontWeight.w800,
                    ),
                    gap(10),
                    txt('기록을 돌아보고, 오늘의 선택을 조금 다르게.', size: 12, color: muted),
                    gap(24),
                    macroStats(r),
                    gap(12),
                    txt(
                      '기록한 식사의 에너지 구성 · 일반 성인 참고 범위와 비교',
                      size: 11,
                      color: muted,
                    ),
                  ],
                ),
              ),
              panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        txt(
                          '다음 한 끼 제안',
                          size: 12,
                          color: primary,
                          weight: FontWeight.w700,
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => reportMethod(context),
                          child: txt('계산 기준 ⓘ', size: 11, color: muted),
                        ),
                      ],
                    ),
                    txt(personal['title'], size: 20, weight: FontWeight.w800),
                    gap(12),
                    txt(
                      personal['evidence'],
                      size: 13,
                      weight: FontWeight.w600,
                    ),
                    gap(7),
                    txt(personal['reason'], size: 13, color: muted),
                    gap(14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (suggestions.any((q) => q['target'] == 'recipe'))
                          OutlinedButton(
                            onPressed: () => jump(recipeAnchor),
                            child: const Text('내게 맞춘 집밥 제안'),
                          ),
                        if (suggestions.any((q) => q['target'] == 'menu'))
                          OutlinedButton(
                            onPressed: () => jump(menuAnchor),
                            child: const Text('추천 메뉴 보기'),
                          ),
                      ],
                    ),
                    if (unconfirmed > 0) ...[
                      gap(14),
                      const Divider(),
                      txt(
                        '완료 주문 $unconfirmed개는 먹은 날짜·양을 아직 확인하지 않았어요.',
                        size: 11,
                        color: muted,
                      ),
                    ],
                  ],
                ),
              ),
              panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    txt('확인한 식사의 영양 요약', size: 17, weight: FontWeight.w800),
                    gap(16),
                    Center(
                      child: Column(
                        children: [
                          txt('총 열량', size: 12, color: muted),
                          txt(
                            '${number(numOf(total['calories']))} kcal',
                            size: 33,
                            weight: FontWeight.w800,
                          ),
                          txt(
                            rs.isEmpty
                                ? '아직 기록한 식사가 없어요.'
                                : '한 끼 평균 ${number(numOf(total['calories']) / rs.length)} kcal',
                            size: 12,
                            color: muted,
                          ),
                        ],
                      ),
                    ),
                    gap(18),
                    Row(
                      children: [
                        for (final e in {
                          'carbs': '탄수화물',
                          'protein': '단백질',
                          'fat': '지방',
                        }.entries)
                          Expanded(
                            child: Column(
                              children: [
                                txt(e.value, size: 12, color: muted),
                                txt(
                                  '${decimal(numOf(total[e.key]))}g',
                                  size: 18,
                                  weight: FontWeight.w700,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    gap(14),
                    txt(
                      '나트륨·당류 정보는 아직 없어요. 기록된 영양값만 합산해요.',
                      size: 11,
                      color: muted,
                    ),
                  ],
                ),
              ),
              panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    txt('날짜별 기록한 열량', size: 17, weight: FontWeight.w800),
                    gap(20),
                    SizedBox(
                      height: 165,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(buckets.length, (i) {
                          final group = buckets[i],
                              items = rs
                                  .where((r) => group.contains(r['date']))
                                  .toList(),
                              value = numOf(store.totals(items)['calories']);
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  txt(
                                    items.isEmpty ? '—' : number(value),
                                    size: 9,
                                    color: muted,
                                  ),
                                  Container(
                                    height: items.isEmpty
                                        ? 4
                                        : (value / bucketMax * 110).clamp(
                                            6,
                                            115,
                                          ),
                                    decoration: BoxDecoration(
                                      color: items.isEmpty
                                          ? const Color(0xffdde2df)
                                          : mint,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                  gap(7),
                                  txt(
                                    '${parseDay(group.isEmpty ? dates.last : group.first).day}',
                                    size: 10,
                                    color: muted,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    gap(),
                    txt(
                      '열량은 확인한 식사만 포함해요. 회색 표시는 미기록이에요.',
                      size: 11,
                      color: muted,
                    ),
                  ],
                ),
              ),
              panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    txt('어떤 한 끼를 기록했나요?', size: 17, weight: FontWeight.w800),
                    gap(18),
                    if (rs.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          children: sources.entries
                              .where((e) => e.value > 0)
                              .map(
                                (e) => Expanded(
                                  flex: e.value,
                                  child: Container(
                                    height: 11,
                                    color: e.key == '직접 기록'
                                        ? const Color(0xff8c74df)
                                        : e.key == '픽업'
                                        ? const Color(0xff5b88c2)
                                        : mint,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    gap(12),
                    Row(
                      children: sources.entries
                          .map(
                            (e) => Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  txt(e.key, size: 10, color: muted),
                                  txt(
                                    '${e.value}끼',
                                    size: 14,
                                    weight: FontWeight.w700,
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    gap(20),
                    const Divider(),
                    gap(12),
                    txt('포케·샐러드·채소덮밥으로 기록한 메뉴', size: 12, color: muted),
                    Text.rich(
                      TextSpan(
                        text: '$vegetableMeals',
                        style: textStyle(26, ink, FontWeight.w800),
                        children: [
                          TextSpan(
                            text: ' / 구성 확인 $knownMenuMeals끼',
                            style: textStyle(12, muted),
                          ),
                        ],
                      ),
                    ),
                    gap(12),
                    txt(
                      '메뉴 분류 기준이에요. 직접 기록의 재료 구성을 추정하지 않아요.',
                      size: 11,
                      color: muted,
                    ),
                  ],
                ),
              ),
              if (matches.isNotEmpty)
                panel(
                  InkWell(
                    onTap: () => jump(matches.first['key'] as GlobalKey),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        txt(
                          '받아둔 쿠폰, 이번 한 끼에 쓰세요',
                          size: 12,
                          color: const Color(0xffe9d9ff),
                        ),
                        gap(7),
                        Row(
                          children: [
                            Expanded(
                              child: txt(
                                '민수님의 다음 한 끼,\n${won(matches.first['discount'])} 덜 쓰고 준비해요',
                                size: 22,
                                color: Colors.white,
                                weight: FontWeight.w800,
                              ),
                            ),
                            assetIcon('benefit-coupon', size: 62),
                          ],
                        ),
                        gap(8),
                        txt(
                          '${matches.first['name']} · 쿠폰 적용 가능',
                          size: 12,
                          color: const Color(0xffe9d9ff),
                        ),
                        gap(12),
                        txt(
                          '추천한 한 끼에 쿠폰 쓰기  ›',
                          size: 13,
                          color: const Color(0xffb9fff4),
                          weight: FontWeight.w700,
                        ),
                      ],
                    ),
                  ),
                  color: purple,
                ),
              if (suggestions.any((q) => q['target'] == 'recipe'))
                Padding(
                  key: recipeAnchor,
                  padding: const EdgeInsets.only(bottom: 12),
                  child: panel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        txt(
                          '다음 한 끼 · 직접 만들어볼까요?',
                          size: 12,
                          color: primary,
                          weight: FontWeight.w700,
                        ),
                        gap(10),
                        txt(
                          '민수님을 위한\n다음 한 끼 레시피',
                          size: 23,
                          weight: FontWeight.w800,
                        ),
                        ...suggestions
                            .where((q) => q['target'] == 'recipe')
                            .map(
                              (q) => Preparation(store: store, suggestion: q),
                            ),
                      ],
                    ),
                  ),
                ),
              if (suggestions.any((q) => q['target'] == 'menu'))
                Padding(
                  key: menuAnchor,
                  padding: const EdgeInsets.only(bottom: 12),
                  child: panel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        txt(
                          '오늘은 주문하는 게 편하다면',
                          size: 12,
                          color: primary,
                          weight: FontWeight.w700,
                        ),
                        gap(10),
                        txt(
                          '내 기록에 맞춰 고른 한 끼',
                          size: 23,
                          weight: FontWeight.w800,
                        ),
                        gap(8),
                        txt(
                          '기록한 영양 구성과 메뉴의 영양정보를 비교해 골랐어요.',
                          size: 12,
                          color: muted,
                        ),
                        ...suggestions
                            .where((q) => q['target'] == 'menu')
                            .map(
                              (q) =>
                                  ReportMenuOption(store: store, suggestion: q),
                            ),
                      ],
                    ),
                  ),
                ),
              if (suggestions.any((q) => q['target'] == 'product'))
                panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      txt(
                        '바쁜 날엔 간편하게 준비해요',
                        size: 12,
                        color: primary,
                        weight: FontWeight.w700,
                      ),
                      gap(10),
                      txt('배민이지로 준비하는 한 끼', size: 23, weight: FontWeight.w800),
                      ...suggestions
                          .where((q) => q['target'] == 'product')
                          .map((q) => Preparation(store: store, suggestion: q)),
                    ],
                  ),
                ),
              Padding(
                key: couponAnchor,
                padding: EdgeInsets.zero,
                child: const SizedBox.shrink(),
              ),
              panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    txt('이미 받은 쿠폰, 다음 한 끼에', size: 20, weight: FontWeight.w800),
                    gap(),
                    ...store.coupons
                        .where((c) => store.couponStatus(c) == 'available')
                        .map(
                          (c) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: assetIcon('benefit-coupon', size: 45),
                            title: txt(
                              c['title'],
                              color: purple,
                              weight: FontWeight.w700,
                            ),
                            subtitle: txt(
                              '${won(c['minOrder'])} 이상 · ${c['expiresAt']}까지',
                              size: 11,
                              color: muted,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => openShop(context, store, c['shopId']),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void reportMethod(BuildContext context) => sheet(
  context,
  '식습관 리포트 계산 기준',
  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      txt('확인한 식사의 영양정보만 사용해요', size: 20, weight: FontWeight.w800),
      gap(14),
      txt('탄수화물·단백질은 1g당 4kcal, 지방은 1g당 9kcal로 에너지 비중을 계산해요.'),
      gap(14),
      txt(
        '2025 한국인 영양소 섭취기준 · 일반 성인 참고 범위',
        size: 13,
        color: primary,
        weight: FontWeight.w700,
      ),
      txt('탄수화물 50~65% · 단백질 10~20% · 지방 15~30%'),
      gap(14),
      txt(
        '미기록 날짜를 0kcal 섭취로 보지 않아요. 주문 완료와 실제 먹은 양은 구분해요. 상품 영양성분이 없는 배민이지 상품은 영양 균형 순위에 포함하지 않아요.',
        size: 13,
        color: muted,
      ),
    ],
  ),
);

class ReportMenuOption extends StatelessWidget {
  const ReportMenuOption({
    super.key,
    required this.store,
    required this.suggestion,
  });
  final AppStore store;
  final Json suggestion;
  @override
  Widget build(BuildContext context) {
    final m = store.item(suggestion['id']),
        matches =
            store.coupons
                .where(
                  (c) =>
                      store.quote([
                        {
                          'menuId': m['id'],
                          'quantity': 1,
                          'unitPrice': m['price'],
                        },
                      ], couponId: c['id'])['eligible'] ==
                      true,
                )
                .toList()
              ..sort(
                (a, b) => numOf(b['discount']).compareTo(numOf(a['discount'])),
              );
    final coupon = matches.firstOrNull;
    final quote = store.quote([
      {'menuId': m['id'], 'quantity': 1, 'unitPrice': m['price']},
    ], couponId: coupon?['id']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FoodImage(m, width: 86, height: 86),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                txt(store.shop(m['shopId'])['name'], size: 11, color: muted),
                txt(m['name'], size: 16, weight: FontWeight.w800),
                gap(5),
                if (coupon != null)
                  Text(
                    won(m['price']),
                    style: textStyle(
                      11,
                      muted,
                    ).copyWith(decoration: TextDecoration.lineThrough),
                  ),
                txt(won(quote['total']), size: 16, weight: FontWeight.w800),
                if (coupon != null) txt('보유 쿠폰 적용 시', size: 11, color: purple),
                TextButton(
                  onPressed: () => openItem(
                    context,
                    store,
                    m['id'],
                    couponId: coupon?['id'],
                  ),
                  child: txt(
                    coupon == null ? '메뉴 보기  ›' : '보유 쿠폰으로 메뉴 보기  ›',
                    size: 12,
                    color: primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
