import 'package:flutter/material.dart';
import 'package:baemin_flutter/core/state/app_store.dart';
import 'package:baemin_flutter/shared/widgets/ui.dart';

class TabPage extends StatelessWidget {
  const TabPage({
    super.key,
    required this.header,
    required this.children,
    this.tabs,
    this.scrollKey,
  });
  final Widget header;
  final List<Widget> children;
  final Widget? tabs;
  final Key? scrollKey;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      header,
      ?tabs,
      Expanded(
        child: ListView(
          key: scrollKey,
          padding: const EdgeInsets.only(bottom: 110),
          children: children,
        ),
      ),
    ],
  );
}

class TabHeader extends StatelessWidget {
  const TabHeader({
    super.key,
    required this.store,
    required this.title,
    this.search,
    this.hint,
    this.onSearch,
    this.actions,
    this.onCart,
    this.background = Colors.white,
  });
  final AppStore store;
  final String title;
  final TextEditingController? search;
  final String? hint;
  final ValueChanged<String>? onSearch;
  final List<Widget>? actions;
  final Color background;
  final VoidCallback? onCart;
  @override
  Widget build(BuildContext context) => Container(
    color: background,
    padding: const EdgeInsets.fromLTRB(17, 12, 17, 12),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  txt(
                    title,
                    size: search == null ? 22 : 18,
                    weight: FontWeight.w800,
                  ),
                  if (search != null)
                    const Icon(Icons.keyboard_arrow_down, size: 18),
                ],
              ),
            ),
            ...?actions,
            if (actions == null) ...[
              if (search != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: ink,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      txt(
                        '배민클럽',
                        size: 10,
                        color: Colors.white,
                        weight: FontWeight.w800,
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.auto_awesome,
                        size: 11,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      sheet(context, '알림', txt('새로운 알림이 없어요.', color: muted)),
                  icon: assetIcon('bell'),
                ),
              ],
              IconButton(
                onPressed: onCart,
                icon: Badge(
                  isLabelVisible: store.cart.isNotEmpty,
                  label: Text(
                    '${store.cart.values.fold<int>(0, (n, v) => n + v)}',
                  ),
                  child: assetIcon('cart'),
                ),
              ),
            ],
          ],
        ),
        if (search != null) ...[
          gap(10),
          SizedBox(
            height: 45,
            child: TextField(
              controller: search,
              onChanged: onSearch,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: textStyle(14, muted),
                suffixIcon: Padding(
                  padding: const EdgeInsets.all(9),
                  child: assetIcon('search'),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: ink, width: .8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: ink, width: 1.2),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class ServiceTabs extends StatelessWidget {
  const ServiceTabs({
    super.key,
    required this.shopping,
    required this.onChanged,
  });
  final bool shopping;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 17),
    child: Row(
      children: [
        for (final value in [false, true])
          Expanded(
            child: InkWell(
              onTap: () => onChanged(value),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: shopping == value ? ink : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Center(
                  child: txt(
                    value ? '장보기·쇼핑' : '배달·픽업',
                    size: 16,
                    color: shopping == value ? ink : muted,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

Widget sectionTitle(String title, {String? note}) => Padding(
  padding: const EdgeInsets.fromLTRB(17, 20, 17, 12),
  child: Row(
    children: [
      Expanded(child: txt(title, size: 18, weight: FontWeight.w800)),
      if (note != null) txt(note, size: 11, color: muted),
    ],
  ),
);

Widget sectionDivider() =>
    const Divider(height: 10, thickness: 10, color: surface);
