import 'package:flutter/material.dart';
import 'package:baemin_flutter/core/state/app_store.dart';
import 'package:baemin_flutter/shared/widgets/ui.dart';

class MealCalendar extends StatelessWidget {
  const MealCalendar({
    super.key,
    required this.store,
    required this.filter,
    required this.onDay,
    required this.onBenefit,
  });
  final AppStore store;
  final String filter;
  final ValueChanged<String> onDay;
  final void Function(String, Json) onBenefit;
  AppStore get s => store;
  void daySheet(String date) => onDay(date);
  void benefitSheet(String date, Json benefit) => onBenefit(date, benefit);
  @override
  Widget build(BuildContext context) {
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
}
