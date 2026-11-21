import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:job_fit/ai/job_analyzer.dart';
import 'package:job_fit/evaluation/evaluation_controller.dart';
import 'package:job_fit/scoring/fit_score.dart';
import 'package:job_fit/ui/result_view.dart';

void main() {
  testWidgets('long skill names wrap on a phone, never cut off', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2400); // phone width
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const long =
        '4+ years of experience as a Full Stack Engineer with PHP and Go';
    final evaluation = Evaluation.fromAnalysis(
      const JobAnalysis(
        title: 'Job',
        company: 'Co',
        requirements: [Requirement(long, RequirementType.must, Match.partial)],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: ResultView(evaluation)),
        ),
      ),
    );

    expect(tester.takeException(), isNull); // no overflow error
    final label = find.text(long);
    expect(label, findsOneWidget);
    // Wrapped: taller than one line of text.
    expect(tester.getSize(label).height, greaterThan(30));
  });

  testWidgets('a job evaluated before shows a note', (tester) async {
    final evaluation = Evaluation.fromAnalysis(
      const JobAnalysis(title: 'Job', company: 'Co', requirements: []),
      alreadySaved: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: ResultView(evaluation)),
        ),
      ),
    );

    expect(
      find.text('You already evaluated this job. Showing the saved result.'),
      findsOneWidget,
    );
  });
}
