import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'app/app.dart';
import 'core/state/app_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.load();
  final fontLicense = await rootBundle.loadString('assets/fonts/OFL.txt');
  LicenseRegistry.addLicense(
    () =>
        Stream.value(LicenseEntryWithLineBreaks(['Noto Sans KR'], fontLicense)),
  );
  runApp(BaeminApp(store: store));
}
