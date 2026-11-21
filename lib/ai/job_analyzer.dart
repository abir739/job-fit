import '../scoring/fit_score.dart';

/// What the AI returns for one job description: facts only, no score.
class JobAnalysis {
  const JobAnalysis({
    required this.title,
    required this.company,
    required this.requirements,
    this.location = '',
    this.blockers = const [],
    this.eligibility = Eligibility.unknown,
    this.reasons = const [],
  });

  /// Reads the JSON sent by the server function.
  /// Throws [FormatException] on missing fields or unknown values,
  /// so a bad AI answer never silently becomes a wrong verdict.
  factory JobAnalysis.fromJson(Map<String, dynamic> json) {
    T byName<T extends Enum>(List<T> values, Object? name) => values.firstWhere(
      (v) => v.name == name,
      orElse: () => throw FormatException('Unknown value "$name"'),
    );

    return JobAnalysis(
      title: json['title'] as String,
      company: json['company'] as String,
      location: json['location'] as String? ?? '',
      requirements: [
        for (final r in json['requirements'] as List)
          Requirement(
            r['name'] as String,
            byName(RequirementType.values, r['type']),
            byName(Match.values, r['match']),
            evidence: r['evidence'] as String? ?? '',
          ),
      ],
      blockers: [
        for (final b in json['blockers'] as List? ?? const [])
          byName(Blocker.values, b),
      ],
      eligibility: byName(Eligibility.values, json['eligibility']),
      reasons: [for (final r in json['reasons'] as List? ?? const []) '$r'],
    );
  }

  final String title;
  final String company;
  final String location;
  final List<Requirement> requirements;
  final List<Blocker> blockers;
  final Eligibility eligibility;
  final List<String> reasons;
}

/// Any AI provider (fake, Gemini, ...) implements this.
abstract interface class JobAnalyzer {
  Future<JobAnalysis> analyze(String jobDescription);
}

/// Any other failure, with a message that is safe to show.
class AnalyzerException implements Exception {
  AnalyzerException(this.message);
  final String message;

  @override
  String toString() => message;
}
