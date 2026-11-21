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
  List<HistoryEntry> entries;

  @override
  Future<List<HistoryEntry>> recent() async => entries;

  @override
  Future<void> setStatus(int id, JobStatus status) async {
    entries = [
      for (final e in entries)
        e.id == id
            ? HistoryEntry(
                id: e.id,
                createdAt: e.createdAt,
                analysis: e.analysis,
                status: status,
              )
            : e,
    ];
  }

  @override
  Future<void> delete(int id) async {
    entries = [
      for (final e in entries)
        if (e.id != id) e,
    ];
  }
}

/// Tall window so the whole page (result, search, history) is on screen.
void _tallWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
    expect(entries.single.status, JobStatus.saved); // no status → saved
  });

  test('status is read; unknown status falls back to saved', () {
    expect(
      HistoryEntry.tryFromJson({..._row(1), 'status': 'interview'})!.status,
      JobStatus.interview,
    );
    expect(
      HistoryEntry.tryFromJson({..._row(1), 'status': 'weird'})!.status,
      JobStatus.saved,
    );
  });

  test('setStatus sends PATCH { id, status }', () async {
    late http.Request sent;
    final repo = EdgeFunctionHistoryRepository(
      endpoint: Uri.parse('https://example.test/functions/v1/analyze-job'),
      client: MockClient((req) async {
        sent = req;
        return http.Response('{}', 200);
      }),
    );

    await repo.setStatus(7, JobStatus.applied);

    expect(sent.method, 'PATCH');
    expect(jsonDecode(sent.body), {'id': 7, 'status': 'applied'});
  });

  testWidgets('history shows saved jobs; tap opens the result', (tester) async {
    _tallWindow(tester);
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
    expect(find.text('Acme · 21 Nov · SKIP'), findsOneWidget);

    await tester.tap(find.text('Flutter Developer'));
    await tester.pumpAndSettle();

    expect(find.text('80%'), findsOneWidget); // 80×1 + 20×0
    expect(find.text('Too senior for now'), findsOneWidget);
    expect(find.text('Improve your CV for this job'), findsOneWidget);
    // SKIP → no cover letter button.
    expect(find.text('Write cover letter'), findsNothing);
  });

  testWidgets('status menu changes the status', (tester) async {
    _tallWindow(tester);
    final repo = _FixedHistory([HistoryEntry.tryFromJson(_row(1))!]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [historyRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);

    await tester.tap(find.byKey(const Key('status-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Applied').last);
    await tester.pumpAndSettle();

    expect(repo.entries.single.status, JobStatus.applied);
    expect(find.text('Applied'), findsOneWidget);
  });

  testWidgets('status chips filter the history', (tester) async {
    _tallWindow(tester);
    HistoryEntry entry(int id, String title, JobStatus status) {
      final row = _row(id);
      (row['analysis'] as Map<String, dynamic>)['title'] = title;
      return HistoryEntry.tryFromJson({...row, 'status': status.name})!;
    }

    final repo = _FixedHistory([
      entry(1, 'Job One', JobStatus.saved),
      entry(2, 'Job Two', JobStatus.applied),
      entry(3, 'Job Three', JobStatus.applied),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [historyRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    // Only statuses in use get a chip.
    expect(find.text('All (3)'), findsOneWidget);
    expect(find.text('Saved (1)'), findsOneWidget);
    expect(find.text('Applied (2)'), findsOneWidget);
    expect(find.text('Interview (0)'), findsNothing);

    await tester.tap(find.text('Applied (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Job One'), findsNothing);
    expect(find.text('Job Two'), findsOneWidget);
    expect(find.text('Job Three'), findsOneWidget);

    await tester.tap(find.text('All (3)'));
    await tester.pumpAndSettle();
    expect(find.text('Job One'), findsOneWidget);
  });

  test('delete sends DELETE { id }', () async {
    late http.Request sent;
    final repo = EdgeFunctionHistoryRepository(
      endpoint: Uri.parse('https://example.test/functions/v1/analyze-job'),
      client: MockClient((req) async {
        sent = req;
        return http.Response('{}', 200);
      }),
    );

    await repo.delete(4);

    expect(sent.method, 'DELETE');
    expect(jsonDecode(sent.body), {'id': 4});
  });

  testWidgets('delete asks first, then removes the job', (tester) async {
    _tallWindow(tester);
    final repo = _FixedHistory([HistoryEntry.tryFromJson(_row(1))!]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [historyRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> openDelete() async {
      await tester.tap(find.byKey(const Key('status-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
    }

    // Cancel keeps it.
    await openDelete();
    expect(find.text('Delete this job?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.entries, hasLength(1));

    // Confirm removes it.
    await openDelete();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(repo.entries, isEmpty);
    expect(find.text('Jobs you evaluate will appear here.'), findsOneWidget);
  });
}
