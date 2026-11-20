import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/fake_job_analyzer.dart';
import '../ai/job_analyzer.dart';
import '../scoring/fit_score.dart';

/// Which AI provider to use. Swap the fake for the real one later.
final jobAnalyzerProvider = Provider<JobAnalyzer>(
  (ref) => const FakeJobAnalyzer(),
);

/// The AI's facts plus the score computed by our own rules.
class Evaluation {
  const Evaluation(this.analysis, this.result);

  final JobAnalysis analysis;
  final FitResult result;
}

class EvaluationController extends AsyncNotifier<Evaluation?> {
  @override
  Future<Evaluation?> build() async => null; // nothing evaluated yet

  Future<void> evaluateJob(String jobDescription) async {
    if (jobDescription.trim().isEmpty) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final analysis = await ref
          .read(jobAnalyzerProvider)
          .analyze(jobDescription);
      final result = evaluate(
        requirements: analysis.requirements,
        blockers: analysis.blockers,
        eligibility: analysis.eligibility,
      );
      return Evaluation(analysis, result);
    });
  }
}

final evaluationProvider =
    AsyncNotifierProvider<EvaluationController, Evaluation?>(
      EvaluationController.new,
    );
