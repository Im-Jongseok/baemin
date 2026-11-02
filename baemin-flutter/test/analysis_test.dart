import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:baemin_flutter/analysis_service.dart';

void main() {
  const image = 'data:image/png;base64,aGVsbG8=';
  test('photo analysis uses the unchanged backend contract and validates successful estimates', () async {
    final client = MockClient((r) async {
      expect(r.url.path, '/api/photo-analyze');
      expect(r.headers['Content-Type'], 'application/json');
      final payload = jsonDecode(r.body);
      expect(payload['mode'], 'huggingface');
      expect(payload['consent'], true);
      expect(payload['image'], image);
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'name': '비빔밥',
            'nutrition': {
              'calories': 620,
              'carbs': 88,
              'protein': 21,
              'fat': 20,
            },
            'source': 'hf-estimate',
          }),
        ),
        200,
      );
    });
    final result = await analyzeFoodPhoto(image, consent: true, client: client);
    expect(result['name'], '비빔밥');
    expect(result['nutrition']['calories'], 620);
  });
  test('no photo leaves the client before consent', () async {
    var calls = 0;
    final client = MockClient((r) async {
      calls++;
      return http.Response('{}', 200);
    });
    await expectLater(
      analyzeFoodPhoto(image, consent: false, client: client),
      throwsStateError,
    );
    expect(calls, 0);
  });
  test('missing tokens and malformed model nutrition fail without fabricating nutrients', () async {
    for (final response in [
      http.Response('{"error":"not configured"}', 503),
      http.Response(
        '{"name":"food","source":"hf-estimate","nutrition":{"calories":-10}}',
        200,
      ),
    ]) {
      await expectLater(
        analyzeFoodPhoto(
          image,
          consent: true,
          client: MockClient((_) async => response),
        ),
        throwsStateError,
      );
    }
  });
  test('connection check distinguishes a reachable server without HF and sends no photo', () async {
    final c = MockClient((r) async {
      expect(r.method, 'GET');
      expect(r.url.path, '/api/config');
      expect(r.body, isEmpty);
      return http.Response(
        '{"hfConfigured":false,"modelId":"example/model"}',
        200,
      );
    });
    expect((await analysisConnection(client: c))['hfConfigured'], false);
  });
  test('network failures provide a local network connection message', () async {
    await expectLater(
      analysisConnection(
        client: MockClient((r) async {
          throw http.ClientException('offline');
        }),
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Wi-Fi'),
        ),
      ),
    );
  });
  test('backend setup errors remain visible instead of a generic connection failure', () async {
    await expectLater(
      analyzeFoodPhoto(
        image,
        consent: true,
        client: MockClient(
          (r) async => http.Response.bytes(
            utf8.encode(jsonEncode({'error': 'Hugging Face 설정 필요'})),
            503,
          ),
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'Hugging Face 설정 필요',
        ),
      ),
    );
  });
}
