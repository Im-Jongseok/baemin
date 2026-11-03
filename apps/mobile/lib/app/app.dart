import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:baemin_flutter/core/state/app_store.dart';

import 'home_shell.dart';
import 'app_theme.dart';

class BaeminApp extends StatelessWidget {
  const BaeminApp({super.key, required this.store, this.initialTab = 0});
  final AppStore store;
  final int initialTab;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '한 끼 캘린더',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ko'),
    supportedLocales: const [Locale('ko'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: buildAppTheme(),
    builder: (ctx, child) => ColoredBox(
      color: const Color(0xffeef1f3),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: kIsWeb ? 430 : 500),
          child: child,
        ),
      ),
    ),
    home: HomeShell(store: store, initialTab: initialTab),
  );
}
