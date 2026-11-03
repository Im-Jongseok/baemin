import 'package:flutter/material.dart';
import 'package:baemin_flutter/shared/widgets/ui.dart';

ThemeData buildAppTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'NotoSansKR',
  scaffoldBackgroundColor: surface,
  colorScheme: const ColorScheme.light(
    primary: primary,
    onPrimary: Colors.white,
    primaryContainer: mint,
    onPrimaryContainer: ink,
    secondary: primary,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xffe8f7f3),
    onSecondaryContainer: ink,
    surface: Colors.white,
    onSurface: ink,
    onSurfaceVariant: muted,
    outline: Color(0xffdfe3e5),
    outlineVariant: Color(0xffedf0f2),
    surfaceTint: Colors.transparent,
  ),
  dividerColor: const Color(0xffedf0f2),
  dividerTheme: const DividerThemeData(color: Color(0xffedf0f2), thickness: .6),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: ink,
      backgroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      minimumSize: const Size(0, 40),
      tapTargetSize: MaterialTapTargetSize.padded,
      side: const BorderSide(color: Color(0xffe4e7e9)),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(
        fontFamily: 'NotoSansKR',
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: mint,
      foregroundColor: ink,
      disabledBackgroundColor: surface,
      disabledForegroundColor: muted,
      minimumSize: const Size(44, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      textStyle: const TextStyle(
        fontFamily: 'NotoSansKR',
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    ),
  ),
  chipTheme: ChipThemeData(
    shape: const StadiumBorder(),
    side: const BorderSide(color: Color(0xffe4e7e9)),
    backgroundColor: Colors.white,
    selectedColor: ink,
    disabledColor: surface,
    checkmarkColor: Colors.white,
    showCheckmark: false,
    color: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? surface
          : states.contains(WidgetState.selected)
          ? ink
          : Colors.white,
    ),
    labelStyle: TextStyle(
      fontFamily: 'NotoSansKR',
      color: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? muted
            : states.contains(WidgetState.selected)
            ? Colors.white
            : ink,
      ),
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    labelPadding: const EdgeInsets.symmetric(horizontal: 3),
  ),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? const Color(0xffeef0f2)
            : Colors.white,
      ),
      foregroundColor: const WidgetStatePropertyAll(ink),
      side: const WidgetStatePropertyAll(BorderSide(color: Color(0xffe4e7e9))),
      textStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'NotoSansKR',
          fontSize: 13,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12),
      ),
      minimumSize: const WidgetStatePropertyAll(Size(44, 38)),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: primary,
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(
      minimumSize: const Size(44, 44),
      foregroundColor: ink,
    ),
  ),
  badgeTheme: const BadgeThemeData(
    backgroundColor: Color(0xffff3b9a),
    textColor: Colors.white,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    foregroundColor: ink,
  ),
  listTileTheme: const ListTileThemeData(
    minTileHeight: 52,
    minVerticalPadding: 2,
    iconColor: muted,
  ),
  inputDecorationTheme: InputDecorationTheme(
    isDense: true,
    labelStyle: const TextStyle(
      fontFamily: 'NotoSansKR',
      color: muted,
      fontSize: 14,
    ),
    floatingLabelStyle: const TextStyle(
      fontFamily: 'NotoSansKR',
      color: primary,
      fontSize: 13,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xffdfe3e5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: primary, width: 1.3),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xffedf0f2)),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontFamily: 'NotoSansKR', color: ink),
  ),
  expansionTileTheme: const ExpansionTileThemeData(
    iconColor: primary,
    collapsedIconColor: muted,
  ),
);
