import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:baemin_flutter/core/state/app_store.dart';

const analysisBase = String.fromEnvironment(
  'ANALYSIS_BASE_URL',
  defaultValue: 'http://127.0.0.1:4182',
);

Json _readResponse(http.Response response) {
  final value = jsonDecode(utf8.decode(response.bodyBytes));
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected a JSON object');
  }
  return value;
}

class PhotoAnalysisException extends StateError {
  PhotoAnalysisException(super.message, {this.code});
  final String? code;
}

Future<Json> analyzeFoodPhoto(
  String image, {
  required bool consent,
  http.Client? client,
}) async {
  if (!consent) {
    throw StateError('사진 전송에 동의해 주세요.');
  }
  if (!RegExp(r'^data:image/(jpeg|png|webp);base64,').hasMatch(image)) {
    throw StateError('지원하는 음식 사진을 선택해 주세요.');
  }
  final transport = client ?? http.Client();
  try {
    final response = await transport
        .post(
          Uri.parse('$analysisBase/api/photo-analyze'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'image': image,
            'mode': 'huggingface',
            'consent': true,
          }),
        )
        .timeout(const Duration(seconds: 65));
    final data = _readResponse(response);
    if (response.statusCode != 200 ||
        !validN(data['nutrition']) ||
        data['name'] is! String ||
        (data['name'] as String).trim().isEmpty ||
        data['source'] != 'hf-estimate') {
      throw PhotoAnalysisException(
        data['error'] is String ? data['error'] : '분석 결과를 확인하지 못했어요.',
        code: data['code'] is String ? data['code'] : null,
      );
    }
    return data;
  } on TimeoutException {
    throw StateError('사진 분석이 지연되고 있어요. 잠시 후 다시 시도해 주세요.');
  } on http.ClientException {
    throw StateError(
      '사진 분석 서버에 연결할 수 없어요. Mac과 같은 Wi-Fi인지, 로컬 네트워크 접근이 허용됐는지 확인해 주세요.',
    );
  } on FormatException {
    throw StateError('사진 분석 응답을 읽지 못했어요. 다시 시도해 주세요.');
  } finally {
    if (client == null) {
      transport.close();
    }
  }
}

Future<Json> analysisConnection({http.Client? client}) async {
  final transport = client ?? http.Client();
  try {
    final response = await transport
        .get(Uri.parse('$analysisBase/api/config'))
        .timeout(const Duration(seconds: 10));
    final data = _readResponse(response);
    if (response.statusCode != 200 || data['hfConfigured'] is! bool) {
      throw StateError('사진 분석 서버의 설정을 확인할 수 없어요.');
    }
    return data;
  } on TimeoutException {
    throw StateError('사진 분석 서버가 응답하지 않아요. Mac의 분석 서버를 확인해 주세요.');
  } on http.ClientException {
    throw StateError('사진 분석 서버에 연결할 수 없어요. 같은 Wi-Fi와 로컬 네트워크 접근 허용을 확인해 주세요.');
  } on FormatException {
    throw StateError('사진 분석 서버의 응답을 확인할 수 없어요.');
  } finally {
    if (client == null) transport.close();
  }
}
