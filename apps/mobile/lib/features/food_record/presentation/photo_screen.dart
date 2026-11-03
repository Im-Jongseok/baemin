import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:baemin_flutter/core/state/app_store.dart';
import 'package:baemin_flutter/core/network/analysis_service.dart';
import 'package:baemin_flutter/shared/widgets/ui.dart';

class PhotoScreen extends StatefulWidget {
  const PhotoScreen({super.key, required this.store, required this.date});
  final AppStore store;
  final String date;
  @override
  State<PhotoScreen> createState() => _PhotoState();
}

class _PhotoState extends State<PhotoScreen> {
  final name = TextEditingController();
  final fields = {for (final k in nutrients) k: TextEditingController()};
  String? image;
  String source = 'manual';
  bool busy = false, saved = false, consent = false;
  String error = '';
  @override
  void dispose() {
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
      if (file == null) {
        return;
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        throw StateError('5MB 이하 사진을 사용해 주세요.');
      }
      final mime =
          file.mimeType ??
          (file.name.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg');
      if (mounted) {
        setState(() {
          image = 'data:$mime;base64,${base64Encode(bytes)}';
          source = 'manual';
          error = '';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = '사진을 열지 못했어요. 앨범에서 선택하거나 권한을 확인해 주세요.');
      }
    }
  }

  Future<void> analyze() async {
    if (image == null || busy || !consent) {
      return;
    }
    setState(() => busy = true);
    try {
      final data = await analyzeFoodPhoto(image!, consent: consent);
      if (!mounted) {
        return;
      }
      name.text = data['name'] ?? '';
      for (final k in nutrients) {
        fields[k]!.text = decimal(numOf(data['nutrition'][k]));
      }
      setState(() {
        source = 'hf-estimate';
        error = '사진 분석값이에요. 음식과 먹은 양을 확인해 주세요.';
      });
    } on StateError catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = '자동 분석에 연결하지 못했어요. 음식과 영양값을 직접 입력할 수 있어요.');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  void selectFood(String value) {
    const samples = {
      '비빔밥': {
        'name': '채소 비빔밥',
        'nutrition': {'calories': 620, 'carbs': 88, 'protein': 21, 'fat': 20},
      },
      '국수': {
        'name': '잔치국수',
        'nutrition': {'calories': 480, 'carbs': 83, 'protein': 16, 'fat': 8},
      },
      '샐러드': {
        'name': '닭가슴살 샐러드',
        'nutrition': {'calories': 350, 'carbs': 22, 'protein': 31, 'fat': 16},
      },
    };
    final selected = samples[value]!;
    name.text = selected['name'] as String;
    final n = selected['nutrition'] as Map;
    for (final k in nutrients) {
      fields[k]!.text = decimal(numOf(n[k]));
    }
    setState(() {
      source = 'photo-demo';
      error = '선택한 음식의 기본 영양정보예요. 먹은 양에 맞게 확인해 주세요.';
    });
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: '음식 촬영·등록',
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        txt('${widget.date}의 한 끼', size: 20, weight: FontWeight.w800),
        gap(15),
        if (image != null) FoodImage({'image': image}, height: 230),
        gap(),
        Row(
          children: [
            Expanded(
              child: actionButton(
                '앨범에서 선택',
                () => pick(ImageSource.gallery),
                secondary: true,
                icon: Icons.photo_outlined,
              ),
            ),
            const SizedBox(width: 10),
            if (!kIsWeb && defaultTargetPlatform != TargetPlatform.macOS)
              Expanded(
                child: actionButton(
                  '촬영하기',
                  () => pick(ImageSource.camera),
                  icon: Icons.camera_alt_outlined,
                ),
              ),
          ],
        ),
        gap(),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: consent,
          onChanged: busy ? null : (v) => setState(() => consent = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: txt(
            '사진 분석을 위해 Hugging Face와 추론 제공자에게 사진을 전송하는 데 동의해요.',
            size: 12,
            color: muted,
          ),
        ),
        actionButton(
          busy ? '사진 분석 중…' : '사진 분석',
          image == null || busy || !consent ? null : analyze,
          secondary: true,
        ),
        if (error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: txt(error, size: 12, color: muted),
          ),
        gap(),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          shape: const Border(),
          collapsedShape: const Border(),
          title: txt('음식 종류로 입력', size: 14, weight: FontWeight.w700),
          subtitle: txt('직접 고른 음식의 기본값을 불러와요', size: 11, color: muted),
          children: [
            Wrap(
              spacing: 8,
              children: ['비빔밥', '국수', '샐러드']
                  .map(
                    (label) => OutlinedButton(
                      onPressed: busy ? null : () => selectFood(label),
                      child: Text(label),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
        gap(14),
        field(name, '음식 이름'),
        ...nutrients.map(
          (k) => field(
            fields[k]!,
            {
              'calories': '열량 (kcal)',
              'carbs': '탄수화물 (g)',
              'protein': '단백질 (g)',
              'fat': '지방 (g)',
            }[k]!,
            type: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        gap(),
        actionButton(
          '음식 기록 완료',
          busy || saved
              ? null
              : () {
                  final n = {
                    for (final k in nutrients)
                      k: double.tryParse(fields[k]!.text) ?? -1,
                  };
                  try {
                    widget.store.recordPhoto(
                      name: name.text,
                      date: widget.date,
                      nutrition: n,
                      image: image,
                      source: source,
                    );
                    setState(() => saved = true);
                    Navigator.pop(context);
                  } catch (_) {
                    setState(() => error = '음식 이름과 올바른 영양값을 입력해 주세요.');
                  }
                },
        ),
      ],
    ),
  );
}
