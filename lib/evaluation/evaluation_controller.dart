import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/edge_function_job_analyzer.dart';
import '../ai/fake_job_analyzer.dart';
import '../ai/job_analyzer.dart';
import '../config.dart';
import '../scoring/fit_score.dart';
import 'app_code.dart';

/// Which AI provider to use: the real server function, or fake data
/// when no SUPABASE_URL is given (UI work, tests).
final jobAnalyzerProvider = Provider<JobAnalyzer>((ref) {
  if (supabaseUrl.isEmpty) return const FakeJobAnalyzer();
  return EdgeFunctionJobAnalyzer(
    endpoint: Uri.parse('$supabaseUrl/functions/v1/$jobFunctionName'),
    appCode: () => ref.read(appCodeProvider) ?? '',
  );
});

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
    // A refused code is forgotten, so the app asks for it again.
    if (state.error is WrongAppCodeException) {
      await ref.read(appCodeProvider.notifier).clear();
    }
  }
}

final evaluationProvider =
    AsyncNotifierProvider<EvaluationController, Evaluation?>(
      EvaluationController.new,
    );
