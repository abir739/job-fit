import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:job_fit/ai/edge_function_job_analyzer.dart';
import 'package:job_fit/ai/job_analyzer.dart';
import 'package:job_fit/cover_letter/cover_letter.dart';

import '../ai/job_analysis_json_test.dart' show sampleJson;

final _endpoint = Uri.parse('https://example.test/functions/v1/analyze-job');

void main() {
  test('sends POST { coverLetterFor: id }, returns the letter', () async {
    late http.Request sent;
    final writer = EdgeFunctionCoverLetterWriter(
      endpoint: _endpoint,
      client: MockClient((req) async {
        sent = req;
        return http.Response(jsonEncode({'coverLetter': 'Dear team'}), 200);
      }),
    );

    expect(await writer.write(5), 'Dear team');
    expect(jsonDecode(sent.body), {'coverLetterFor': 5});
  });

  test('server error → readable message', () async {
    final writer = EdgeFunctionCoverLetterWriter(
      endpoint: _endpoint,
      client: MockClient(
        (_) async => http.Response(jsonEncode({'error': 'Job not found'}), 404),
      ),
    );

    expect(
      writer.write(5),
      throwsA(
        isA<AnalyzerException>().having(
          (e) => e.message,
          'message',
          contains('Job not found'),
        ),
      ),
    );
  });

  test('analysis answer carries the saved history id', () async {
    final analyzer = EdgeFunctionJobAnalyzer(
      endpoint: _endpoint,
      client: MockClient(
        (_) async =>
            http.Response(jsonEncode({...sampleJson(), 'historyId': 9}), 200),
      ),
    );

    expect((await analyzer.analyze('job')).historyId, 9);
  });
}
