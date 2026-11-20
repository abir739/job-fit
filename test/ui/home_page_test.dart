import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_fit/ai/fake_job_analyzer.dart';
import 'package:job_fit/evaluation/evaluation_controller.dart';
import 'package:job_fit/main.dart';

void main() {
  testWidgets('paste a job → see score and verdict', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobAnalyzerProvider.overrideWithValue(
            const FakeJobAnalyzer(delay: Duration.zero),
          ),
        ],
        child: const MainApp(),
      ),
    );

    await tester.enterText(find.byKey(const Key('jobText')), 'Some job ad');
    await tester.tap(find.text('Evaluate'));
    await tester.pumpAndSettle();

    // Fake data: must_avg 0.875, nice_avg 0.25 → 80×0.875 + 20×0.25 = 75.
    expect(find.text('75/100'), findsOneWidget);
    // Eligibility unknown → caution, even with a good score.
    expect(find.text('APPLY WITH CAUTION'), findsOneWidget);
  });

  testWidgets('empty text does nothing', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MainApp()));
    await tester.tap(find.text('Evaluate'));
    await tester.pumpAndSettle();
    expect(find.textContaining('/100'), findsNothing);
  });
}
