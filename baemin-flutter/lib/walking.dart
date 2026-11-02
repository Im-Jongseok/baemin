import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'store.dart';
import 'ui.dart';

const walkingChannel = MethodChannel('hankki/walking');
const walkingEvents = EventChannel('hankki/walking/events');

class WalkingSync with WidgetsBindingObserver {
  WalkingSync(this.store, {this.onOpen});
  final AppStore store;
  final VoidCallback? onOpen;
  Timer? timer;
  StreamSubscription<dynamic>? subscription;
  int lastMeasurement = 0;
  bool started = false;
  bool busy = false;
  bool disposed = false;
  bool get native => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  void start() {
    if (started) return;
    started = true;
    WidgetsBinding.instance.addObserver(this);
    if (kIsWeb && store.walkingToday['source'] == 'unlinked') {
      store.updateWalking(
        3665,
        date: todayKey(),
        source: 'preview',
        previewBoost: true,
      );
    }
    if (native) {
      subscription = walkingEvents.receiveBroadcastStream().listen(
        (event) {
          if (event is Map && !disposed) {
            if (event['status'] == 'denied') {
              store.updateWalking(0, date: todayKey(), source: 'unlinked');
            } else {
              acceptMeasurement(obj(event));
            }
          }
        },
        onError: (Object _) {
          // The history query remains a fallback; never replace device data
          // with simulated steps when streaming is unavailable.
        },
      );
      refresh();
      timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    }
  }

  Future<String?> refresh({bool request = false}) async {
    if (!native) return '실제 걸음 수는 아이폰 앱에서 연결할 수 있어요.';
    if (busy || disposed) return null;
    busy = true;
    try {
      final open = await walkingChannel.invokeMethod<bool>('takeOpenWalking');
      if (!disposed && open == true) onOpen?.call();
      final value = await walkingChannel.invokeMapMethod<String, dynamic>(
        'today',
        {'request': request},
      );
      if (disposed) return null;
      if (value?['status'] == 'authorized') {
        await acceptMeasurement(value!);
        return null;
      }
      if (store.walkingToday['source'] == 'device') {
        store.updateWalking(0, date: todayKey(), source: 'unlinked');
      }
      return switch (value?['status']) {
        'denied' || 'restricted' => '설정에서 운동 및 피트니스 접근을 허용해 주세요.',
        'unsupported' => '이 기기는 걸음 수 측정을 지원하지 않아요.',
        _ => '걸음 수 연결을 눌러 오늘의 걸음을 불러오세요.',
      };
    } on PlatformException catch (error) {
      return error.message ?? '걸음 수를 불러오지 못했어요. 다시 시도해 주세요.';
    } on MissingPluginException {
      return '걸음 수 연동이 포함된 최신 아이폰 앱을 실행해 주세요.';
    } finally {
      busy = false;
    }
  }

  Future<void> acceptMeasurement(Json value) async {
    if (disposed ||
        value['status'] != 'authorized' ||
        value['steps'] is! int ||
        value['date'] != todayKey()) {
      return;
    }
    final measured = numOf(value['measuredAt']).toInt();
    // A history query started before a stream event must not roll it back.
    if (measured > 0 && measured < lastMeasurement) return;
    if (measured > 0) lastMeasurement = measured;
    store.updateWalking(value['steps'], date: value['date']);
    await updateLive();
  }

  Future<void> updateLive() async {
    if (!liveEnabled || disposed) return;
    try {
      final active = await walkingChannel.invokeMethod<bool>(
        'liveUpdate',
        liveData,
      );
      if (!disposed && active != true) {
        store.state['walkingLiveEnabled'] = false;
        store.save();
      }
    } on PlatformException {
      if (!disposed) {
        store.state['walkingLiveEnabled'] = false;
        store.save();
      }
    }
  }

  bool get liveEnabled => store.state['walkingLiveEnabled'] == true;
  Json get liveData => {
    'date': todayKey(),
    'steps': numOf(store.walkingToday['steps']).toInt(),
    'calories': (numOf(store.walkingToday['steps']) * .0327).round(),
    'points': store.walkingAvailable,
    'claimed': store.walkingClaimed,
    'boosted': store.walkingBoost,
  };
  Future<String?> setLiveEnabled(bool enabled) async {
    if (!native) return '잠금화면 표시는 아이폰 앱에서 사용할 수 있어요.';
    try {
      final active = await walkingChannel.invokeMethod<bool>(
        enabled ? 'liveStart' : 'liveStop',
        liveData,
      );
      if (!disposed) {
        store.state['walkingLiveEnabled'] = enabled && active == true;
        store.save();
      }
      return null;
    } on PlatformException catch (e) {
      return e.message ?? '잠금화면 표시 설정을 변경하지 못했어요.';
    } on MissingPluginException {
      return '잠금화면 표시가 포함된 최신 아이폰 앱을 실행해 주세요.';
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  void dispose() {
    disposed = true;
    timer?.cancel();
    subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}

// A dark, translucent surface keeps the existing white and mint content legible.
class _WalkingGlass extends StatelessWidget {
  const _WalkingGlass({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x18334449),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xe65b7074),
                  Color(0xe638494e),
                  Color(0xf02c3c40),
                ],
                stops: [0, .48, 1],
              ),
              border: Border.all(color: const Color(0x5cffffff), width: .75),
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}

class WalkingCard extends StatelessWidget {
  const WalkingCard({
    super.key,
    required this.store,
    required this.sync,
    required this.onPickup,
  });
  final AppStore store;
  final WalkingSync sync;
  final VoidCallback onPickup;
  void open(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          WalkingScreen(store: store, sync: sync, onPickup: onPickup),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final linked = store.walkingToday['source'] != 'unlinked';
    final steps = numOf(store.walkingToday['steps']).toInt();
    const accent = Color(0xff0cefd3);
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 14, 13, 16),
      child: _WalkingGlass(
        child: InkWell(
          onTap: () => open(context),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Image.asset(
                  'assets/captured/walking-logo.png',
                  width: 50,
                  height: 48,
                  fit: BoxFit.contain,
                  semanticLabel: '배민 만보기',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text.rich(
                          TextSpan(
                            style: const TextStyle(
                              fontSize: 24,
                              height: 1.25,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            children: [
                              TextSpan(text: linked ? number(steps) : '오늘의 걸음'),
                              if (linked)
                                const TextSpan(
                                  text: ' 걸음',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Color(0xffe0e9e8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text.rich(
                          TextSpan(
                            style: const TextStyle(
                              fontSize: 10,
                              height: 1.25,
                              color: Colors.white,
                            ),
                            children: [
                              TextSpan(
                                text: linked ? '소비 칼로리  ' : '걸으며 포인트를 모아요',
                              ),
                              if (linked)
                                TextSpan(
                                  text:
                                      '${number((steps * .0327).round())} kcal',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 88,
                  constraints: const BoxConstraints(minHeight: 86),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0x26ffffff), Color(0x0affffff)],
                    ),
                    border: Border.all(
                      color: const Color(0x24ffffff),
                      width: .5,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        child: Text(
                          store.walkingBoost ? '픽업 부스터 X2' : '오늘의 걸음 보상',
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${store.walkingAvailable}P',
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 5),
                      SizedBox(
                        width: 64,
                        height: 28,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: accent,
                            foregroundColor: ink,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => linked && store.walkingAvailable > 0
                              ? claimWalking(context, store, sync: sync)
                              : open(context),
                          child: Text(
                            linked && store.walkingAvailable > 0
                                ? '보상 받기'
                                : '자세히 보기',
                            style: const TextStyle(
                              fontSize: 10,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> claimWalking(
  BuildContext context,
  AppStore store, {
  WalkingSync? sync,
}) async {
  final earned = store.claimWalkingReward();
  if (earned == 0) return;
  await sync?.updateLive();
  if (!context.mounted) return;
  HapticFeedback.lightImpact();
  await sheet(
    context,
    '오늘의 걸음 보상',
    TweenAnimationBuilder<double>(
      tween: Tween(begin: .8, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Transform.scale(scale: v, child: child),
      child: Column(
        children: [
          assetIcon('benefit-points', size: 108),
          gap(18),
          txt('+$earned P', size: 36, color: primary, weight: FontWeight.w800),
          gap(8),
          txt('오늘 걸은 만큼 포인트를 받았어요', size: 17, weight: FontWeight.w700),
          gap(6),
          txt('내 포인트 ${number(store.points)}P', color: muted),
          gap(22),
          actionButton('확인', () => Navigator.pop(context)),
        ],
      ),
    ),
  );
}

class WalkingScreen extends StatefulWidget {
  const WalkingScreen({
    super.key,
    required this.store,
    required this.sync,
    required this.onPickup,
  });
  final AppStore store;
  final WalkingSync sync;
  final VoidCallback onPickup;
  @override
  State<WalkingScreen> createState() => _WalkingScreenState();
}

class _WalkingScreenState extends State<WalkingScreen> {
  bool busy = false;
  bool liveBusy = false;
  String? error;
  Future<void> connect() async {
    if (busy) return;
    setState(() => busy = true);
    final message = await widget.sync.refresh(request: true);
    if (mounted) {
      setState(() {
        busy = false;
        error = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Live(
    store: widget.store,
    builder: (_) {
      final s = widget.store,
          steps = numOf(s.walkingToday['steps']).toInt(),
          linked = s.walkingToday['source'] != 'unlinked';
      return PageFrame(
        title: '배민 만보기',
        background: surface,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          children: [
            panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  txt(
                    '오늘도 한 걸음씩',
                    size: 14,
                    color: primary,
                    weight: FontWeight.w700,
                  ),
                  gap(10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      txt(number(steps), size: 42, weight: FontWeight.w800),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: txt('걸음', color: muted),
                      ),
                    ],
                  ),
                  gap(12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (steps / 10000).clamp(0, 1),
                      minHeight: 10,
                      backgroundColor: surface,
                      color: mint,
                    ),
                  ),
                  gap(8),
                  Row(
                    children: [
                      txt('오늘의 목표', size: 12, color: muted),
                      const Spacer(),
                      txt('10,000걸음', size: 12, weight: FontWeight.w700),
                    ],
                  ),
                  gap(20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            txt('소비 칼로리', size: 12, color: muted),
                            txt(
                              '${number((steps * .0327).round())} kcal',
                              size: 22,
                              weight: FontWeight.w800,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            txt('오늘 받은 포인트', size: 12, color: muted),
                            txt(
                              '${s.walkingClaimed}P',
                              size: 22,
                              color: primary,
                              weight: FontWeight.w800,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  gap(22),
                  actionButton(
                    s.walkingAvailable > 0
                        ? '${s.walkingAvailable}P 보상 받기'
                        : steps >= 10000
                        ? '오늘의 걸음 보상 완료'
                        : '다음 보상까지 ${number(1000 - steps % 1000)}걸음',
                    !linked || s.walkingAvailable == 0
                        ? null
                        : () => claimWalking(context, s, sync: widget.sync),
                  ),
                  if (syncSupported) ...[
                    gap(8),
                    actionButton(
                      busy
                          ? '걸음 수 불러오는 중…'
                          : linked
                          ? '걸음 수 새로고침'
                          : '아이폰 걸음 수 연결',
                      busy ? null : connect,
                      secondary: true,
                    ),
                  ],
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: txt(error!, size: 12, color: muted),
                    ),
                ],
              ),
            ),
            if (syncSupported)
              panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: txt(
                        '잠금화면에 걸음 수 표시',
                        size: 15,
                        weight: FontWeight.w700,
                      ),
                      subtitle: txt(
                        '실시간 현황 · 다이내믹 아일랜드',
                        size: 12,
                        color: muted,
                      ),
                      value: widget.sync.liveEnabled,
                      activeThumbColor: primary,
                      onChanged: !linked || liveBusy
                          ? null
                          : (value) async {
                              setState(() => liveBusy = true);
                              final message = await widget.sync.setLiveEnabled(
                                value,
                              );
                              if (mounted) {
                                setState(() {
                                  liveBusy = false;
                                  error = message;
                                });
                              }
                            },
                    ),
                    txt(
                      '앱 사용 중에는 걸음 변화가 자동 반영돼요. 잠금 중 iOS가 앱 실행을 정지하면 갱신이 멈추고, 다시 열면 누적 걸음을 반영해요.',
                      size: 12,
                      color: muted,
                    ),
                  ],
                ),
              ),
            panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      assetIcon('benefit-pickup', size: 50),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            txt('픽업 부스터 X2', size: 19, weight: FontWeight.w800),
                            txt(
                              s.walkingBoost
                                  ? '오늘의 걸음 보상이 두 배예요'
                                  : '음식 픽업을 완료하면 오늘 보상이 두 배',
                              size: 12,
                              color: muted,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  gap(16),
                  actionButton(
                    s.walkingBoost ? '픽업할 가게 더 보기' : '가까운 가게에서 픽업하기',
                    () {
                      Navigator.pop(context);
                      widget.onPickup();
                    },
                    secondary: true,
                  ),
                ],
              ),
            ),
            panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  txt('걸음 보상 안내', size: 17, weight: FontWeight.w800),
                  gap(10),
                  txt(
                    '1,000걸음마다 4P, 하루 10,000걸음까지 받아요. 오늘 음식 픽업을 완료하면 2배로 최대 80P를 받을 수 있어요.',
                    size: 13,
                  ),
                  gap(8),
                  txt(
                    '칼로리는 걸음 수 × 0.0327 kcal로 계산한 참고값이에요. 체중·걸음 속도에 따라 실제 소비량은 달라요.',
                    size: 12,
                    color: muted,
                  ),
                  gap(8),
                  txt(
                    kIsWeb
                        ? '웹의 걸음 수는 미리보기 값이에요. 아이폰 앱에서 실제 걸음 수를 연결할 수 있어요.'
                        : '운동 및 피트니스 권한으로 오늘의 걸음 수만 읽어요. 걸음 데이터는 기기에 저장해요.',
                    size: 12,
                    color: muted,
                  ),
                ],
              ),
            ),
            if (kIsWeb)
              panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    txt('미리보기 걸음 수', weight: FontWeight.w700),
                    gap(8),
                    Wrap(
                      spacing: 8,
                      children: [1000, 3665, 10000]
                          .map(
                            (v) => OutlinedButton(
                              onPressed: () => s.updateWalking(
                                v,
                                date: todayKey(),
                                source: 'preview',
                                previewBoost: s.walkingBoost,
                              ),
                              child: Text('${number(v)}걸음'),
                            ),
                          )
                          .toList(),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: txt('픽업 부스터'),
                      value: s.walkingBoost,
                      onChanged: (v) => s.updateWalking(
                        steps,
                        date: todayKey(),
                        source: 'preview',
                        previewBoost: v,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
  bool get syncSupported => widget.sync.native;
}
