import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:baemin_flutter/core/state/app_store.dart';
import 'package:baemin_flutter/core/network/analysis_service.dart';
import 'package:baemin_flutter/features/food_record/application/photo_record_controller.dart';
import 'package:baemin_flutter/shared/widgets/ui.dart';

class PhotoScreen extends StatefulWidget {
  const PhotoScreen({
    super.key,
    required this.store,
    required this.date,
    this.controller,
  });
  final AppStore store;
  final String date;
  final PhotoRecordController? controller;
  @override
  State<PhotoScreen> createState() => _PhotoState();
}

class _PhotoState extends State<PhotoScreen> {
  late final draft =
      widget.controller ??
      PhotoRecordController(store: widget.store, date: widget.date);
  final name = TextEditingController();
  final fields = {for (final k in nutrients) k: TextEditingController()};
  int formRevision = -1;
  bool syncing = false;
  String pickerError = '', connection = '';
  @override
  void initState() {
    super.initState();
    name.addListener(() {
      if (!syncing) draft.editName(name.text);
    });
    for (final k in nutrients) {
      fields[k]!.addListener(() {
        if (!syncing) draft.editNutrient(k, fields[k]!.text);
      });
    }
    draft.addListener(syncForm);
    syncForm();
  }

  void syncForm() {
    if (formRevision == draft.formRevision) return;
    syncing = true;
    name.text = draft.name;
    for (final k in nutrients) {
      fields[k]!.text = draft.nutrition[k] == null
          ? ''
          : decimal(numOf(draft.nutrition[k]));
    }
    syncing = false;
    formRevision = draft.formRevision;
  }

  @override
  void dispose() {
    draft.removeListener(syncForm);
    if (widget.controller == null) draft.dispose();
    name.dispose();
    for (final f in fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> pick(ImageSource from) async {
    try {
      final file = await ImagePicker().pickImage(
        source: from,
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 85,
      );
      if (file == null) return;
      final image = foodPhotoDataUrl(await file.readAsBytes());
      if (mounted) {
        draft.setImage(image);
        setState(() => pickerError = '');
      }
    } on StateError catch (e) {
      if (mounted) setState(() => pickerError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => pickerError = '사진을 열지 못했어요. 앨범에서 선택하거나 권한을 확인해 주세요.');
      }
    }
  }

  Future<void> checkConnection() async {
    setState(() => connection = '연결을 확인하고 있어요…');
    try {
      final config = await analysisConnection();
      if (mounted) {
        setState(
          () => connection = config['hfConfigured'] == true
              ? '서버 연결됨 · 토큰 설정됨. 실제 이용 가능 여부는 분석 시 확인해요.'
              : '서버에 연결됐어요. Hugging Face 토큰 설정이 필요해요.',
        );
      }
    } on StateError catch (e) {
      if (mounted) setState(() => connection = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: draft,
    builder: (_, _) => PageFrame(
      title: '음식 촬영·등록',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          txt('${widget.date}의 한 끼', size: 20, weight: FontWeight.w800),
          gap(8),
          txt('사진을 분석하고, 실제 먹은 양을 확인해요.', color: muted, size: 13),
          gap(15),
          if (draft.image != null)
            FoodImage(
              {'image': draft.image},
              height: 230,
              width: double.infinity,
            ),
          gap(),
          Row(
            children: [
              Expanded(
                child: actionButton(
                  '앨범에서 선택',
                  draft.saved ? null : () => pick(ImageSource.gallery),
                  secondary: true,
                  icon: Icons.photo_outlined,
                ),
              ),
              if (!kIsWeb && defaultTargetPlatform != TargetPlatform.macOS) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: actionButton(
                    '촬영하기',
                    draft.saved ? null : () => pick(ImageSource.camera),
                    icon: Icons.camera_alt_outlined,
                  ),
                ),
              ],
            ],
          ),
          if (pickerError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: txt(pickerError, color: Colors.redAccent),
            ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: draft.consent,
            onChanged: draft.busy || draft.saved
                ? null
                : (v) => draft.setConsent(v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: txt(
              '사진 분석을 위해 Hugging Face와 추론 제공자에게 사진을 전송하는 데 동의해요.',
              size: 12,
              color: muted,
            ),
          ),
          actionButton(
            draft.busy
                ? '사진 분석 중…'
                : draft.analysis == null
                ? '사진 분석'
                : '다시 분석',
            draft.canAnalyze ? draft.analyze : null,
          ),
          if (draft.busy) ...[
            gap(),
            const LinearProgressIndicator(color: mint),
            gap(6),
            txt('음식과 사진 속 전체 분량을 살펴보고 있어요.', size: 12, color: muted),
          ],
          if (draft.error.isNotEmpty) ...[
            gap(14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xfffff3ee),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  txt(draft.error, size: 13, weight: FontWeight.w700),
                  gap(5),
                  txt(
                    draft.errorCode == 'provider_billing'
                        ? '추론 크레딧이 준비되면 다시 분석할 수 있어요. 지금은 음식 종류 선택·직접 입력으로 기록해요.'
                        : '입력한 내용은 유지돼요. 다시 시도하거나 직접 기록할 수 있어요.',
                    size: 12,
                    color: muted,
                  ),
                ],
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: draft.busy ? null : checkConnection,
              child: const Text('분석 연결 확인'),
            ),
          ),
          if (connection.isNotEmpty) txt(connection, size: 12, color: muted),
          if (draft.analysis != null) ...[
            gap(14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xffeff9f6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  pill(draft.edited ? '사진 분석 후 직접 수정' : '사진 분석 추정값'),
                  gap(8),
                  txt(draft.name, size: 20, weight: FontWeight.w800),
                  if (draft.ingredients.isNotEmpty)
                    txt(draft.ingredients.join(' · '), size: 12, color: muted),
                  gap(10),
                  txt(
                    '사진 속 전체 음식 약 ${number(numOf(draft.analysis!['nutrition']['calories']))} kcal',
                    size: 13,
                  ),
                  gap(10),
                  txt('실제로 먹은 양', weight: FontWeight.w700),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final ratio in [.25, .5, .75, 1.0])
                        ChoiceChip(
                          label: Text('${(ratio * 100).round()}%'),
                          selected: draft.portion == ratio,
                          onSelected: draft.busy || draft.edited
                              ? null
                              : (_) => draft.setPortion(ratio),
                        ),
                    ],
                  ),
                  txt(
                    draft.edited
                        ? '직접 수정한 영양값으로 저장해요.'
                        : '먹은 양 기준 ${number(numOf(draft.nutrition['calories']))} kcal',
                    size: 16,
                    weight: FontWeight.w800,
                  ),
                  gap(8),
                  txt(
                    '사진만으로 식재료와 양을 정확히 알 수는 없어요. 아래 음식명·영양값을 확인하고 수정해 주세요.',
                    size: 12,
                    color: muted,
                  ),
                ],
              ),
            ),
          ],
          gap(),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            shape: const Border(),
            collapsedShape: const Border(),
            title: txt('음식 종류로 입력', size: 14, weight: FontWeight.w700),
            subtitle: txt('등록된 메뉴의 기준량·영양값을 불러와요', size: 11, color: muted),
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final label in ['비빔밥', '국수', '샐러드'])
                    OutlinedButton(
                      onPressed: draft.busy || draft.saved
                          ? null
                          : () => draft.selectFood(label),
                      child: Text(label),
                    ),
                ],
              ),
            ],
          ),
          gap(14),
          TextField(
            controller: name,
            enabled: !draft.busy && !draft.saved,
            decoration: const InputDecoration(labelText: '음식 이름'),
          ),
          for (final k in nutrients)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                controller: fields[k],
                enabled: !draft.busy && !draft.saved,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: {
                    'calories': '열량 (kcal)',
                    'carbs': '탄수화물 (g)',
                    'protein': '단백질 (g)',
                    'fat': '지방 (g)',
                  }[k],
                ),
              ),
            ),
          gap(22),
          actionButton(
            '음식 기록 완료',
            !draft.canSave
                ? null
                : () {
                    try {
                      draft.save();
                      Navigator.pop(context);
                    } on StateError catch (e) {
                      toast(context, e.message);
                    }
                  },
          ),
        ],
      ),
    ),
  );
}
