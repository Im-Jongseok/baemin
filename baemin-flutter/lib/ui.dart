import 'dart:convert';

import 'package:flutter/material.dart';

import 'store.dart';

const mint = Color(0xff00d2b8),
    primary = Color(0xff007f72),
    purple = Color(0xff5925f8),
    ink = Color(0xff17191b),
    muted = Color(0xff889198),
    surface = Color(0xfff4f5f7);
// Compact metadata stays readable without competing with headings and energy values.
double readableSize(double size) => switch (size) {
  10 => 11,
  11 => 12,
  12 => 13,
  13 => 14,
  _ => size,
};
TextStyle textStyle([
  double size = 14,
  Color color = ink,
  FontWeight weight = FontWeight.w400,
]) => TextStyle(
  fontSize: readableSize(size),
  color: color,
  fontWeight: weight,
  height: size >= 18 ? 1.45 : 1.6,
  letterSpacing: -.35,
);
Widget txt(
  String s, {
  double size = 14,
  Color color = ink,
  FontWeight weight = FontWeight.w400,
  int? lines,
}) => Text(
  s,
  style: textStyle(size, color, weight),
  maxLines: lines,
  overflow: lines == null ? null : TextOverflow.ellipsis,
);
Widget gap([double n = 12]) => SizedBox(height: n);
Widget assetIcon(String name, {double size = 28}) => Image.asset(
  'assets/captured/$name.png',
  width: size,
  height: size,
  fit: BoxFit.contain,
  errorBuilder: (_, e, st) => Icon(Icons.circle_outlined, size: size),
);

String shopSummary(Json shop) => [
  if (shop['rating'] is num) '★ ${shop['rating']}',
  '${shop['category']}',
].join(' · ');

Widget calendarBenefitIcon(Json benefit, {double size = 28}) =>
    benefit['asset'] == 'points'
    ? ClipOval(
        child: Image.asset(
          'assets/captured/calendar-points.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          semanticLabel: '포인트 혜택',
        ),
      )
    : assetIcon('benefit-${benefit['asset']}', size: size);

class FoodImage extends StatelessWidget {
  const FoodImage(
    this.item, {
    super.key,
    this.width,
    this.height = 80,
    this.radius = 12,
    this.fit = BoxFit.cover,
  });
  final Json item;
  final double? width;
  final double height, radius;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    final source = item['image'] as String?;
    ImageProvider provider;
    try {
      provider = source != null && source.startsWith('data:image')
          ? MemoryImage(base64Decode(source.split(',').last))
          : AssetImage(
              source != null && source.startsWith('/assets/')
                  ? source.substring(1)
                  : 'assets/food/${item['kind'] ?? 'bowl'}.png',
            );
    } catch (_) {
      provider = const AssetImage('assets/food/bowl.png');
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image(
        image: provider,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, e, s) => Image.asset(
          'assets/food/bowl.png',
          width: width,
          height: height,
          fit: fit,
        ),
      ),
    );
  }
}

Widget pill(String label, {Color color = primary, Color? bg}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
  decoration: BoxDecoration(
    color: bg ?? color.withValues(alpha: .08),
    borderRadius: BorderRadius.circular(5),
  ),
  child: txt(label, size: 11, color: color, weight: FontWeight.w700),
);
Widget panel(
  Widget child, {
  EdgeInsets padding = const EdgeInsets.all(18),
  EdgeInsets margin = const EdgeInsets.fromLTRB(16, 0, 16, 12),
  Color color = Colors.white,
}) => Padding(
  padding: margin,
  child: Material(
    color: color,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  ),
);
Widget actionButton(
  String label,
  VoidCallback? action, {
  bool secondary = false,
  Color? color,
  IconData? icon,
}) => SizedBox(
  width: double.infinity,
  child: FilledButton(
    onPressed: action,
    style: FilledButton.styleFrom(
      backgroundColor: secondary ? Colors.white : color ?? mint,
      foregroundColor: secondary ? ink : const Color(0xff102d27),
      disabledBackgroundColor: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: secondary
            ? const BorderSide(color: Color(0xffdde1e4))
            : BorderSide.none,
      ),
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
        Flexible(child: txt(label, size: 13, weight: FontWeight.w700)),
      ],
    ),
  ),
);
void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ),
  );
}

Future<T?> sheet<T>(BuildContext context, String title, Widget child) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * .88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: txt(title, size: 19, weight: FontWeight.w800),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: muted),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: surface),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
Future<bool> confirm(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: txt('장바구니 변경', size: 19, weight: FontWeight.w700),
        content: txt(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('돌아가기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('비우고 담기'),
          ),
        ],
      ),
    ) ??
    false;

class Live extends StatelessWidget {
  const Live({super.key, required this.store, required this.builder});
  final AppStore store;
  final WidgetBuilder builder;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => builder(context),
  );
}

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.background = Colors.white,
  });
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Color background;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    appBar: AppBar(
      title: txt(title, size: 19, weight: FontWeight.w800),
      actions: actions,
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
    ),
    body: SafeArea(top: false, child: child),
  );
}

Widget field(
  TextEditingController c,
  String label, {
  TextInputType type = TextInputType.text,
  int lines = 1,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 14),
  child: TextField(
    controller: c,
    keyboardType: type,
    maxLines: lines,
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
  ),
);
