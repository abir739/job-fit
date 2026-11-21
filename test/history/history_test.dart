import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:job_fit/history/history.dart';
import 'package:job_fit/ui/home_page.dart';

import '../ai/job_analysis_json_test.dart' show sampleJson;

Map<String, dynamic> _row(int id) => {
  'id': id,
  'created_at': '2026-11-21T10:00:00Z',
  'analysis': sampleJson(),
};

class _FixedHistory implements HistoryRepository {
  _FixedHistory(this.entries);
  final List<HistoryEntry> entries;

  @override
  Future<List<HistoryEntry>> recent() async => entries;
}

void main() {
  test('GET history: parses rows, skips unreadable ones', () async {
    final repo = EdgeFunctionHistoryRepository(
      endpoint: Uri.parse('https://example.test/functions/v1/analyze-job'),
      client: MockClient((req) async {
        expect(req.method, 'GET');
        return http.Response(
          jsonEncode([
            _row(2),
            {'id': 1, 'created_at': 'bad', 'analysis': {}},
          ]),
          200,
        );
      }),
    );

    final entries = await repo.recent();

    expect(entries, hasLength(1));
    expect(entries.single.id, 2);
    expect(entries.single.analysis.title, 'Flutter Developer');
  });

  testWidgets('history shows saved jobs; tap opens the result', (tester) async {
    final entry = HistoryEntry.tryFromJson(_row(1))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyRepositoryProvider.overrideWithValue(_FixedHistory([entry])),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    // sampleJson: 1 MUST strong, 1 NICE missing, blocker tooSenior → SKIP.
    expect(find.text('Flutter Developer'), findsOneWidget);
    expect(find.text('Acme · 21 Nov'), findsOneWidget);

    await tester.tap(find.text('Flutter Developer'));
    await tester.pumpAndSettle();

    expect(find.text('80%'), findsOneWidget); // 80×1 + 20×0
    expect(find.text('Too senior for now'), findsOneWidget);
    expect(find.text('Improve your CV for this job'), findsOneWidget);
  });
}
