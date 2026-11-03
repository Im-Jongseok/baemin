import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:baemin_flutter/core/state/app_store.dart';
import 'package:baemin_flutter/shared/widgets/ui.dart';
import 'package:baemin_flutter/shared/widgets/tab_page.dart';
import 'package:baemin_flutter/features/orders/presentation/commerce.dart';
import 'package:baemin_flutter/features/walking/presentation/walking.dart';
import 'package:baemin_flutter/features/nutrition/presentation/nutrition.dart';
import 'package:baemin_flutter/core/network/analysis_service.dart';

class MyBaeminScreen extends StatefulWidget {
  const MyBaeminScreen({
    super.key,
    required this.store,
    required this.walking,
    required this.onPickup,
    required this.onSelectTab,
  });
  final AppStore store;
  final WalkingSync walking;
  final VoidCallback onPickup;
  final ValueChanged<int> onSelectTab;
  @override
  State<MyBaeminScreen> createState() => _MyBaeminScreenState();
}

class _MyBaeminScreenState extends State<MyBaeminScreen> {
  AppStore get s => widget.store;
  @override
  Widget build(BuildContext context) => Live(
    store: s,
    builder: (_) => TabPage(
      header: TabHeader(
        store: s,
        title: '마이배민',
        background: surface,
        actions: [
          IconButton(
            icon: assetIcon('headset'),
            onPressed: () => sheet(
              context,
              '고객센터',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  txt('무엇을 도와드릴까요?', size: 22, weight: FontWeight.w700),
                  gap(),
                  txt('주문 관련 문의는 주문내역에서 주문을 선택해 주세요.'),
                  actionButton('주문내역 보기', () {
                    Navigator.pop(context);
                    widget.onSelectTab(3);
                  }, secondary: true),
                ],
              ),
            ),
          ),
          IconButton(onPressed: settings, icon: assetIcon('settings')),
        ],
      ),
      scrollKey: const PageStorageKey('profile'),
      children: my(),
    ),
  );
  List<Widget> my() {
    final favorites = s.shops
            .where(
              (shop) => (s.state['favorites'] as List).contains(shop['id']),
            )
            .toList(),
        available = s.coupons
            .where((c) => s.couponStatus(c) == 'available')
            .length;
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 17),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xffe8e9ec),
            borderRadius: BorderRadius.circular(22),
          ),
          child: txt('ⓘ 배민의 음식주문 경험, 어떠셨나요?', size: 11, color: muted),
        ),
      ),
      gap(16),
      Center(child: assetIcon('profile-mascot', size: 96)),
      gap(),
      Center(child: txt('민수', size: 20, weight: FontWeight.w800)),
      WalkingCard(store: s, sync: widget.walking, onPickup: widget.onPickup),
      panel(
        Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: txt('쿠폰함', weight: FontWeight.w800),
              trailing: txt('$available개', weight: FontWeight.w800),
              onTap: () => couponsSheet(context, s),
            ),
            InkWell(
              onTap: () => couponsSheet(context, s),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: purple,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: txt(
                  '받은 쿠폰을 한곳에서 확인해요',
                  size: 12,
                  color: Colors.white,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: txt('포인트', weight: FontWeight.w700),
              trailing: txt('${number(s.points)}원', weight: FontWeight.w800),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: txt('선물함', weight: FontWeight.w700),
              trailing: txt('0원', weight: FontWeight.w800),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: txt('배민페이', weight: FontWeight.w700),
              subtitle: txt('결제수단을 간편하게 관리해요', size: 12, color: muted),
              trailing: txt('결제수단 관리', size: 12),
              onTap: () =>
                  sheet(context, '배민페이', txt('저장된 결제수단이 없어요.', color: muted)),
            ),
          ],
        ),
      ),
      panel(
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: txt('우리 학교 급식표', weight: FontWeight.w800),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              sheet(context, '우리 학교 급식표', txt('등록된 급식표가 없어요.', color: muted)),
        ),
      ),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: txt('찜한 가게·상품', weight: FontWeight.w800),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => widget.onSelectTab(2),
            ),
            Row(
              children: favorites.take(3).map((shop) {
                final m = s.catalog.firstWhere(
                  (m) => m['shopId'] == shop['id'],
                );
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () => openShop(context, s, shop['id']),
                    child: Column(
                      children: [
                        FoodImage(m, width: 80, height: 76),
                        txt(shop['name'], size: 10, color: muted),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      panel(
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: txt('나의 한 끼 기록', weight: FontWeight.w800),
          subtitle: txt('캘린더에서 기록한 식사를 확인해요', size: 12, color: muted),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => widget.onSelectTab(3),
        ),
      ),
      panel(
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: txt('배민클럽', weight: FontWeight.w800),
          subtitle: txt(
            s.club ? '클럽 회원 전용 리포트를 확인해요' : '한 끼를 더 자세히 돌아보세요',
            size: 12,
            color: muted,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => sheet(
            context,
            '배민클럽',
            Column(
              children: [
                txt('식사 구성과 영양 정보를 더 자세히', size: 20, weight: FontWeight.w800),
                gap(18),
                actionButton(s.club ? '식습관 리포트 보기' : '배민클럽 시작하기', () {
                  s.state['membership'] = {'baeminClub': true};
                  s.save();
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ReportScreen(store: s)),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Future<void> settings() async {
    await sheet(
      context,
      '설정',
      Column(
        children: [
          ListTile(
            title: txt('기록 가져오기'),
            subtitle: txt('기존 웹 기록 JSON을 붙여넣어요', size: 12, color: muted),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pop(context);
              importRecords();
            },
          ),
          ListTile(
            title: txt('사진 분석 연결'),
            subtitle: txt(analysisBase, size: 12, color: muted),
            trailing: const Icon(Icons.wifi_find),
            onTap: () async {
              Navigator.pop(context);
              try {
                final config = await analysisConnection();
                if (!mounted) return;
                toast(
                  context,
                  config['hfConfigured'] == true
                      ? '사진 분석 서버 연결됨 · Hugging Face 토큰 설정됨'
                      : '사진 분석 서버 연결됨 · Hugging Face 설정 필요',
                );
              } on StateError catch (e) {
                if (mounted) toast(context, e.message);
              }
            },
          ),
          if (s.lastError.isNotEmpty)
            txt(s.lastError, size: 12, color: Colors.redAccent),
        ],
      ),
    );
  }

  Future<void> importRecords() async {
    final controller = TextEditingController();
    await sheet(
      context,
      '기록 가져오기',
      Column(
        children: [
          txt('가져오면 앱의 현재 기록이 교체돼요. 웹 기록은 변경되지 않아요.', size: 12, color: muted),
          gap(),
          field(controller, '웹 기록 JSON', lines: 7),
          actionButton('기록 가져오기', () {
            try {
              final incoming = obj(jsonDecode(controller.text));
              s.restore(incoming);
              s.save();
              Navigator.pop(context);
              widget.onSelectTab(3);
              toast(context, '기록을 가져왔어요.');
            } catch (_) {
              toast(context, '기록 JSON 형식을 확인해 주세요.');
            }
          }),
        ],
      ),
    );
    controller.dispose();
  }
}
