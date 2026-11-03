import 'dart:convert';
import 'dart:io';

import 'package:baemin_flutter/core/state/app_store.dart';

Json loadSeed() {
  final seed = obj(jsonDecode(File('assets/seed.json').readAsStringSync()));
  final today = parseDay(todayKey());
  for (final coupon in seed['state']['coupons'] as List) {
    coupon['issuedAt'] = dateKey(today.subtract(const Duration(days: 7)));
    coupon['expiresAt'] = dateKey(today.add(const Duration(days: 5)));
  }
  return seed;
}
