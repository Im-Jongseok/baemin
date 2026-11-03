import 'package:flutter/material.dart';
import 'package:baemin_flutter/core/state/app_store.dart';
import 'package:baemin_flutter/shared/widgets/ui.dart';

import '../commerce.dart';

class RecordedFoodCard extends StatelessWidget {
  const RecordedFoodCard({super.key, required this.record});
  final Json record;
  @override
  Widget build(BuildContext context) => panel(
    InkWell(
      onTap: () => recordedMealSheet(context, record),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FoodImage(record, width: 49, height: 49),
              const SizedBox(width: 12),
              Expanded(
                child: txt(record['name'], size: 16, weight: FontWeight.w800),
              ),
              pill('기록 완료'),
            ],
          ),
          gap(),
          if (record['image'] != null)
            FoodImage(record, height: 210, width: double.infinity),
          gap(),
          txt(
            '${number(numOf(record['nutrition']['calories']))} kcal · 탄 ${decimal(numOf(record['nutrition']['carbs']))}g · 단 ${decimal(numOf(record['nutrition']['protein']))}g · 지 ${decimal(numOf(record['nutrition']['fat']))}g',
            size: 13,
          ),
          if (record['analysis'] is Map) ...[
            gap(8),
            txt(
              record['analysis']['userEdited'] == true
                  ? '사진 분석 후 수정 · 기록 보기 ›'
                  : '사진 분석 · 먹은 양 ${(numOf(record['analysis']['consumedFraction']) * 100).round()}% · 기록 보기 ›',
              size: 12,
              color: primary,
            ),
          ],
        ],
      ),
    ),
  );
}
