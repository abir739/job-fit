// Pure Dart scoring rules. No Flutter, no AI.
// The AI only fills in requirements, blockers and eligibility;
// this code turns them into a score and a verdict.

enum RequirementType { must, nice }

enum Match {
  strong(1.0),
  partial(0.5),
  missing(0.0);

  const Match(this.points);
  final double points;
}

class Requirement {
  const Requirement(this.name, this.type, this.match);

  final String name;
  final RequirementType type;
  final Match match;
}

/// Any one of these means SKIP, whatever the score.
enum Blocker {
  notMobileRole,
  tooSenior,
  locationNotAllowed,
  noSponsorship,
  remoteRegionExcluded,
  unsupportedLanguage,
  mainFrameworkMissing,
}

/// Can I legally work this job (location compatible or sponsorship offered)?
enum Eligibility { yes, unknown }

enum Verdict { apply, applyWithCaution, skip }

class FitResult {
  const FitResult({
    required this.mustAvg,
    required this.mustCount,
    required this.niceAvg,
    required this.niceCount,
    required this.score,
    required this.verdict,
  });

  final double mustAvg;
  final int mustCount;
  final double niceAvg;
  final int niceCount;
  final int score;
  final Verdict verdict;

  /// One-line calculation, e.g. "must_avg = 0.75 (4 items), nice_avg = 1 (0 items) → 80".
  String get calculation =>
      'must_avg = ${_fmt(mustAvg)} ($mustCount items), '
      'nice_avg = ${_fmt(niceAvg)} ($niceCount items) → $score';

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

const int skipBelow = 45;
const int applyFrom = 60;

FitResult evaluate({
  required List<Requirement> requirements,
  List<Blocker> blockers = const [],
  Eligibility eligibility = Eligibility.unknown,
}) {
  final must = requirements.where((r) => r.type == RequirementType.must);
  final nice = requirements.where((r) => r.type == RequirementType.nice);

  final mustAvg = _average(must);
  final niceAvg = _average(nice);
  // Same as round(100 × (0.8 × must + 0.2 × nice)), written to avoid float noise.
  final score = (80 * mustAvg + 20 * niceAvg).round();

  return FitResult(
    mustAvg: mustAvg,
    mustCount: must.length,
    niceAvg: niceAvg,
    niceCount: nice.length,
    score: score,
    verdict: decide(score, blockers, eligibility),
  );
}

/// Average points. An empty group counts as 1 (it can't pull the score down).
double _average(Iterable<Requirement> items) {
  if (items.isEmpty) return 1.0;
  final total = items.fold<double>(0, (sum, r) => sum + r.match.points);
  return total / items.length;
}

Verdict decide(int score, List<Blocker> blockers, Eligibility eligibility) {
  if (blockers.isNotEmpty || score < skipBelow) return Verdict.skip;
  if (score >= applyFrom && eligibility == Eligibility.yes) {
    return Verdict.apply;
  }
  return Verdict.applyWithCaution;
}
