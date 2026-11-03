import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:baemin_flutter/core/state/app_store.dart';
import 'package:baemin_flutter/shared/widgets/ui.dart';

import 'home_shell.dart';

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
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansKR',
      scaffoldBackgroundColor: surface,
      colorScheme: ColorScheme.fromSeed(
        seedColor: mint,
        primary: primary,
        surface: Colors.white,
      ),
      dividerColor: const Color(0xffedf0ef),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          minimumSize: const Size(0, 40),
          tapTargetSize: MaterialTapTargetSize.padded,
          side: const BorderSide(color: Color(0xffe5e7e9)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: const BorderSide(color: Color(0xffe1e5e7)),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      textTheme: const TextTheme(bodyMedium: TextStyle(color: ink)),
      expansionTileTheme: const ExpansionTileThemeData(iconColor: primary),
    ),
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
