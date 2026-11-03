import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baemin_flutter/core/network/analysis_service.dart';
import 'package:baemin_flutter/core/state/app_store.dart';
import 'package:baemin_flutter/features/food_record/application/photo_record_controller.dart';
import 'package:baemin_flutter/features/food_record/presentation/photo_screen.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();
  final image = foodPhotoDataUrl(
    File('assets/food/burger.png').readAsBytesSync(),
  );
  final result = <String, dynamic>{
    'name': '비빔밥',
    'source': 'hf-estimate',
    'modelId': 'test/model',
    'basis': 'whole-photo',
    'ingredients': ['밥', '달걀', '채소'],
    'nutrition': {'calories': 800, 'carbs': 100, 'protein': 30, 'fat': 31.1},
  };
  AppStore fresh() {
    final s = AppStore(loadSeed());
    s.state['records'] = [];
    return s;
  }

  PhotoRecordController draft(AppStore s) => PhotoRecordController(
    store: s,
    date: s.selected,
    analyzer: (_, {required consent}) async => result,
  );
  test('analysis is consent-gated, records actual portion and preserves original model metadata', () async {
    final s = fresh();
    final d = draft(s);
    d.setImage(image);
    await d.analyze();
    expect(d.analysis, isNull);
    d.setConsent(true);
    await d.analyze();
    d.setPortion(.5);
    expect(d.nutrition['calories'], 400);
    d.save();
    final record = s.records.single;
    expect(record['nutrition']['carbs'], 50);
    expect(record['date'], s.selected);
    expect(record['source'], 'hf-estimate');
    expect(record['analysis']['modelId'], 'test/model');
    expect(record['analysis']['wholePhotoNutrition']['calories'], 800);
    expect(record['analysis']['consumedFraction'], .5);
    expect(record['analysis']['userEdited'], false);
    expect(() => d.save(), throwsStateError);
    expect(s.records.length, 1);
    final restored = AppStore(loadSeed())..restore({'state': s.state});
    expect(restored.records.single['analysis']['modelId'], 'test/model');
    d.dispose();
  });
  test('changing photo invalidates pending response and clears previous nutrition and consent', () async {
    final pending = Completer<Json>();
    final s = fresh();
    final d = PhotoRecordController(
      store: s,
      date: s.selected,
      analyzer: (_, {required consent}) => pending.future,
    );
    d.setImage(image);
    d.setConsent(true);
    final call = d.analyze();
    expect(d.busy, true);
    d.setImage(image);
    pending.complete(result);
    await call;
    expect(d.analysis, isNull);
    expect(d.nutrition, isEmpty);
    expect(d.name, isEmpty);
    expect(d.consent, false);
    expect(d.busy, false);
    expect(d.canSave, false);
    d.dispose();
  });
  test(
    'leaving during inference does not notify a disposed controller',
    () async {
      final pending = Completer<Json>();
      final s = fresh();
      final d = PhotoRecordController(
        store: s,
        date: s.selected,
        analyzer: (_, {required consent}) => pending.future,
      );
      d.setImage(image);
      d.setConsent(true);
      final call = d.analyze();
      d.dispose();
      pending.complete(result);
      await call;
      expect(s.records, isEmpty);
    },
  );
  test('billing errors keep manual input and do not create analysis or invented nutrients', () async {
    final s = fresh();
    final d = PhotoRecordController(
      store: s,
      date: s.selected,
      analyzer: (_, {required consent}) async {
        throw PhotoAnalysisException(
          '추론 한도를 확인해 주세요.',
          code: 'provider_billing',
        );
      },
    );
    d.setImage(image);
    d.setConsent(true);
    d.editName('직접 입력');
    await d.analyze();
    expect(d.errorCode, 'provider_billing');
    expect(d.name, '직접 입력');
    expect(d.nutrition, isEmpty);
    expect(d.analysis, isNull);
    expect(d.canSave, false);
    expect(s.records, isEmpty);
    d.dispose();
  });
  test('direct edits stay explicit and cannot be silently overwritten by a portion change', () async {
    final s = fresh();
    final c = draft(s);
    c.setImage(image);
    c.setConsent(true);
    await c.analyze();
    c.editName('이름을 고친 음식');
    c.setPortion(.5);
    expect(c.nutrition['calories'], 400);
    c.editNutrient('calories', '420');
    c.setPortion(1);
    expect(c.nutrition['calories'], 420);
    c.save();
    expect(s.records.single['analysis']['userEdited'], true);
    expect(s.records.single['analysis']['consumedFraction'], .5);
    c.dispose();
  });
  test(
    'quick food input uses the curated catalog instead of stale copied numbers',
    () {
      final s = fresh();
      final c = draft(s);
      for (final entry in {
        '비빔밥': 'bibimbap',
        '국수': 'noodles',
        '샐러드': 'salad-poke',
      }.entries) {
        c.selectFood(entry.key);
        expect(c.nutrition, s.item(entry.value)['nutrition']);
        expect(c.source, 'photo-demo');
      }
      c.dispose();
    },
  );
  test(
    'photo encoding checks content signature and size rather than filename',
    () {
      expect(
        foodPhotoDataUrl(
          File('assets/captured/nav-home.png').readAsBytesSync(),
        ),
        startsWith('data:image/png;base64,'),
      );
      expect(
        () => foodPhotoDataUrl(base64Decode('aGVsbG8=')),
        throwsStateError,
      );
    },
  );
  testWidgets(
    'photo analysis result can be reviewed, portioned and saved from the screen',
    (tester) async {
      tester.view.physicalSize = const Size(393, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = fresh();
      final c = draft(s)..setImage(image);
      final boundary = GlobalKey();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            fontFamily: 'NotoSansKR',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xff00d2b8),
              primary: const Color(0xff007f72),
              surface: Colors.white,
            ),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RepaintBoundary(
                      key: boundary,
                      child: PhotoScreen(
                        store: s,
                        date: s.selected,
                        controller: c,
                      ),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('사진 분석'));
      await tester.pumpAndSettle();
      expect(find.text('사진 분석 추정값'), findsOneWidget);
      final portion = find.widgetWithText(ChoiceChip, '50%');
      await tester.ensureVisible(portion);
      await tester.tap(portion);
      await tester.pumpAndSettle();
      expect(find.text('먹은 양 기준 400 kcal'), findsOneWidget);
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('qa/photo-analysis-review.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      final save = find.text('음식 기록 완료');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(s.records.single['nutrition']['calories'], 400);
      expect(find.byType(PhotoScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
