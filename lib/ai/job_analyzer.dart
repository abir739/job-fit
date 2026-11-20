import '../scoring/fit_score.dart';

/// What the AI returns for one job description: facts only, no score.
class JobAnalysis {
  const JobAnalysis({
    required this.title,
    required this.company,
    required this.requirements,
    this.blockers = const [],
    this.eligibility = Eligibility.unknown,
  });

  final String title;
  final String company;
  final List<Requirement> requirements;
  final List<Blocker> blockers;
  final Eligibility eligibility;
}

/// Any AI provider (fake, Gemini, ...) implements this.
abstract interface class JobAnalyzer {
  Future<JobAnalysis> analyze(String jobDescription);
}
