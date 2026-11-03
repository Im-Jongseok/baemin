import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:baemin_flutter/core/network/analysis_service.dart';
import 'package:baemin_flutter/core/state/app_store.dart';

typedef PhotoAnalyzer = Future<Json> Function(
  String image, {
  required bool consent,
});

String foodPhotoDataUrl(Uint8List bytes) {
  if (bytes.length > 5 * 1024 * 1024) {
    throw StateError('5MB 이하 사진을 사용해 주세요.');
  }
  final png =
      bytes.length >= 8 &&
      listEquals(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
  final jpeg =
      bytes.length >= 3 &&
      bytes[0] == 255 &&
      bytes[1] == 216 &&
      bytes[2] == 255;
  final webp =
      bytes.length >= 12 &&
      ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
      ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP';
  if (!png && !jpeg && !webp) {
    throw StateError('JPG·PNG·WEBP 사진을 선택해 주세요.');
  }
  return 'data:image/${png
      ? 'png'
      : jpeg
      ? 'jpeg'
      : 'webp'};base64,${base64Encode(bytes)}';
}

class PhotoRecordController extends ChangeNotifier {
  PhotoRecordController({
    required this.store,
    required this.date,
    PhotoAnalyzer? analyzer,
  }) : _analyzer = analyzer ?? analyzeFoodPhoto;
  final AppStore store;
  final String date;
  final PhotoAnalyzer _analyzer;
  String? image;
  String name = '', source = 'manual', error = '';
  String? errorCode;
  Json nutrition = {};
  Json? analysis;
  bool consent = false, busy = false, saved = false, edited = false;
  double portion = 1;
  int formRevision = 0, _generation = 0;
  bool _closed = false;
  bool get canSave =>
      !busy && !saved && name.trim().isNotEmpty && validN(nutrition);
  bool get canAnalyze => image != null && consent && !busy && !saved;
  List<String> get ingredients =>
      List<String>.from(analysis?['ingredients'] ?? []);

  void setImage(String value) {
    if (saved) return;
    _generation++;
    image = value;
    consent = false;
    busy = false;
    analysis = null;
    nutrition = {};
    name = '';
    source = 'manual';
    portion = 1;
    edited = false;
    error = '';
    errorCode = null;
    formRevision++;
    notifyListeners();
  }

  void setConsent(bool value) {
    if (busy || saved) return;
    consent = value;
    notifyListeners();
  }

  Future<void> analyze() async {
    if (!canAnalyze) return;
    final generation = ++_generation;
    final selectedImage = image!;
    busy = true;
    error = '';
    errorCode = null;
    notifyListeners();
    try {
      final result = await _analyzer(selectedImage, consent: consent);
      if (_closed || generation != _generation) return;
      if (result['source'] != 'hf-estimate' ||
          result['name'] is! String ||
          (result['name'] as String).trim().isEmpty ||
          !validN(result['nutrition'])) {
        throw StateError('분석 결과를 확인하지 못했어요. 다시 분석하거나 직접 입력해 주세요.');
      }
      analysis = copy(result);
      name = result['name'];
      source = 'hf-estimate';
      nutrition = copy(obj(result['nutrition']));
      portion = 1;
      edited = false;
      formRevision++;
    } on StateError catch (e) {
      if (!_closed && generation == _generation) {
        error = e.message;
        errorCode = e is PhotoAnalysisException ? e.code : null;
      }
    } catch (_) {
      if (!_closed && generation == _generation) {
        error = '사진 분석을 완료하지 못했어요. 다시 시도하거나 직접 입력해 주세요.';
      }
    } finally {
      if (!_closed && generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void selectFood(String label) {
    if (busy || saved) return;
    final menuId = {
      '비빔밥': 'bibimbap',
      '국수': 'noodles',
      '샐러드': 'salad-poke',
    }[label];
    final item = store.catalog.where((m) => m['id'] == menuId).firstOrNull;
    if (item == null || !validN(item['nutrition'])) return;
    analysis = null;
    name = item['name'];
    nutrition = copy(obj(item['nutrition']));
    source = 'photo-demo';
    portion = 1;
    edited = false;
    error = '';
    errorCode = null;
    formRevision++;
    notifyListeners();
  }

  void setPortion(double value) {
    if (busy ||
        saved ||
        edited ||
        analysis == null ||
        !value.isFinite ||
        value <= 0 ||
        value > 1) {
      return;
    }
    portion = value;
    nutrition = {
      for (final k in nutrients)
        k: (numOf(analysis!['nutrition'][k]) * portion * 10).round() / 10,
    };
    formRevision++;
    notifyListeners();
  }

  void editName(String value) {
    if (busy || saved) return;
    name = value;
    notifyListeners();
  }

  void editNutrient(String key, String value) {
    if (busy || saved || !nutrients.contains(key)) return;
    nutrition[key] = double.tryParse(value) ?? -1;
    edited = analysis != null || edited;
    notifyListeners();
  }

  void save() {
    if (!canSave) throw StateError('음식 이름과 올바른 영양값을 입력해 주세요.');
    final details = analysis == null
        ? null
        : {
            'source': 'hf-estimate',
            'modelId': analysis!['modelId'],
            'originalName': analysis!['name'],
            'basis': 'whole-photo',
            'wholePhotoNutrition': copy(obj(analysis!['nutrition'])),
            'ingredients': ingredients,
            'consumedFraction': portion,
            'userEdited':
                edited || name.trim() != analysis!['name'].toString().trim(),
          };
    store.recordPhoto(
      name: name,
      date: date,
      nutrition: copy(nutrition),
      image: image,
      source: source,
      analysis: details,
    );
    saved = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    _generation++;
    super.dispose();
  }
}
