import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/edge_function_job_analyzer.dart';
import '../ai/fake_job_analyzer.dart';
import '../ai/job_analyzer.dart';
import '../config.dart';
import '../history/history.dart';
import '../scoring/fit_score.dart';

/// Which AI provider to use: the real server function, or fake data
/// when no SUPABASE_URL is given (UI work, tests).
final jobAnalyzerProvider = Provider<JobAnalyzer>((ref) {
  if (supabaseUrl.isEmpty) return const FakeJobAnalyzer();
  return EdgeFunctionJobAnalyzer(endpoint: jobFunctionUri);
});

/// The AI's facts plus the score computed by our own rules.
class Evaluation {
  const Evaluation(this.analysis, this.result);

  /// Scores an analysis with the fixed rules (same input → same verdict).
  factory Evaluation.fromAnalysis(JobAnalysis analysis) => Evaluation(
    analysis,
    evaluate(
      requirements: analysis.requirements,
      blockers: analysis.blockers,
      eligibility: analysis.eligibility,
    ),
  );

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
      return Evaluation.fromAnalysis(analysis);
    });
    // The server saved it: refresh the history list.
    if (state.hasValue) ref.invalidate(historyProvider);
  }

  /// Shows an old job from the history again (no new AI call).
  void show(Evaluation evaluation) => state = AsyncData(evaluation);
}

final evaluationProvider =
    AsyncNotifierProvider<EvaluationController, Evaluation?>(
      EvaluationController.new,
    );
