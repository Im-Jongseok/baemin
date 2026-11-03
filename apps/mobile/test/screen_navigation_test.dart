import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baemin_flutter/app/app.dart';
import 'package:baemin_flutter/core/state/app_store.dart';

import 'support/fixtures.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'NotoSansKR',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets(
    'tabs preserve independent history filters and home market links reset the shopping category',
    (tester) async {
      tester.view.physicalSize = const Size(393, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = AppStore(loadSeed());
      await tester.pumpWidget(BaeminApp(store: s, initialTab: 3));
      await tester.pumpAndSettle();
      await tester.tap(find.text('장보기·쇼핑').first);
      await tester.pumpAndSettle();
      expect(find.text('장보기·쇼핑 주문내역'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav-2')));
      await tester.pumpAndSettle();
      expect(find.text('찜'), findsNWidgets(2));
      await tester.tap(find.byKey(const ValueKey('nav-3')));
      await tester.pumpAndSettle();
      expect(find.text('장보기·쇼핑 주문내역'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav-1')));
      await tester.pumpAndSettle();
      final fruit = find.widgetWithText(ChoiceChip, '과일·채소');
      await tester.ensureVisible(fruit);
      await tester.tap(fruit);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-0')));
      await tester.pumpAndSettle();
      final market = find.text('B마트');
      await tester.ensureVisible(market);
      await tester.tap(market);
      await tester.pumpAndSettle();
      expect(find.text('모든 가게 보기'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '전체'))
            .selected,
        true,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
