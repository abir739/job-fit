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
  const Evaluation(
    this.analysis,
    this.result, {
    this.historyId,
    this.coverLetter,
  });

  /// Scores an analysis with the fixed rules (same input → same verdict).
  factory Evaluation.fromAnalysis(
    JobAnalysis analysis, {
    int? historyId,
    String? coverLetter,
  }) => Evaluation(
    analysis,
    evaluate(
      requirements: analysis.requirements,
      blockers: analysis.blockers,
      eligibility: analysis.eligibility,
    ),
    historyId: historyId,
    coverLetter: coverLetter,
  );

  final JobAnalysis analysis;
  final FitResult result;

  /// Id of the saved history entry (needed to write a cover letter).
  final int? historyId;

  /// Cover letter already written for this job, if any.
  final String? coverLetter;
}

class EvaluationController extends AsyncNotifier<Evaluation?> {
  @override
  Future<Evaluation?> build() async => null; // nothing evaluated yet

  Future<void> evaluateJob(String jobDescription) async {
    if (jobDescription.trim().isEmpty) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final saved = await ref.read(jobAnalyzerProvider).analyze(jobDescription);
      return Evaluation.fromAnalysis(
        saved.analysis,
        historyId: saved.historyId,
      );
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
