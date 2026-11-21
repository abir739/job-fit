import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:job_fit/ai/fake_job_analyzer.dart';
import 'package:job_fit/evaluation/evaluation_controller.dart';
import 'package:job_fit/search/job_search.dart';
import 'package:job_fit/ui/home_page.dart';

void main() {
  test('sends POST { findJobs }, keeps only complete jobs', () async {
    late http.Request sent;
    final finder = EdgeFunctionJobFinder(
      endpoint: Uri.parse('https://example.test/functions/v1/analyze-job'),
      client: MockClient((req) async {
        sent = req;
        return http.Response(
          jsonEncode({
            'jobs': [
              {'title': 'Flutter Dev', 'company': 'Acme', 'url': 'https://a.b'},
              {'title': 'No company'},
            ],
          }),
          200,
        );
      }),
    );

    final jobs = await finder.find(' Germany ');

    expect(jsonDecode(sent.body), {'findJobs': 'Germany'});
    expect(jobs, hasLength(1));
    expect(jobs.single.company, 'Acme');
  });

  test('jobText holds what the evaluation needs', () {
    const job = FoundJob(
      title: 'Flutter Dev',
      company: 'Acme',
      location: 'Berlin',
      summary: '3+ years Flutter',
    );
    expect(job.jobText, contains('Flutter Dev'));
    expect(job.jobText, contains('Acme'));
    expect(job.jobText, contains('3+ years Flutter'));
  });

  testWidgets('find jobs, then evaluate one', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobAnalyzerProvider.overrideWithValue(
            const FakeJobAnalyzer(delay: Duration.zero),
          ),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );

    await tester.tap(find.text('Find jobs').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Flutter-first role open to remote in Europe.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Evaluate'));
    await tester.pumpAndSettle();
    expect(find.text('75%'), findsOneWidget); // fake analyzer result
  });
}
