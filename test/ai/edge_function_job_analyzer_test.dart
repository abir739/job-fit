import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:job_fit/ai/edge_function_job_analyzer.dart';
import 'package:job_fit/ai/job_analyzer.dart';

import 'job_analysis_json_test.dart' show sampleJson;

EdgeFunctionJobAnalyzer _analyzer(MockClientHandler handler) =>
    EdgeFunctionJobAnalyzer(
      endpoint: Uri.parse('https://example.test/functions/v1/analyze-job'),
      client: MockClient(handler),
    );

http.Response _json(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('sends job text, returns parsed analysis', () async {
    late http.Request sent;
    final analyzer = _analyzer((req) async {
      sent = req;
      return _json(sampleJson(), 200);
    });

    final a = (await analyzer.analyze('Some job ad')).analysis;

    expect(sent.method, 'POST');
    expect(jsonDecode(sent.body), {'jobText': 'Some job ad'});
    expect(a.title, 'Flutter Developer');
  });

  test('server error → readable message', () async {
    final analyzer = _analyzer(
      (_) async => _json({'error': 'AI request failed (503)'}, 502),
    );
    expect(
      analyzer.analyze('x'),
      throwsA(
        isA<AnalyzerException>().having(
          (e) => e.message,
          'message',
          contains('AI request failed (503)'),
        ),
      ),
    );
  });

  test('incomplete AI answer → AnalyzerException, not a crash', () async {
    final analyzer = _analyzer((_) async => _json({'title': 'only'}, 200));
    expect(analyzer.analyze('x'), throwsA(isA<AnalyzerException>()));
  });

  test('network failure → AnalyzerException', () async {
    final analyzer = _analyzer((_) async => throw http.ClientException('down'));
    expect(analyzer.analyze('x'), throwsA(isA<AnalyzerException>()));
  });
}
