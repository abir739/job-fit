import 'package:flutter_test/flutter_test.dart';
import 'package:job_fit/scoring/fit_score.dart';

const _must = RequirementType.must;
const _nice = RequirementType.nice;

Requirement _req(RequirementType type, Match match) =>
    Requirement('x', type, match);

void main() {
  group('score', () {
    test('all STRONG gives 100', () {
      final r = evaluate(
        requirements: [_req(_must, Match.strong), _req(_nice, Match.strong)],
      );
      expect(r.score, 100);
    });

    test('mixed matches follow the 80/20 formula', () {
      // must_avg = (1 + 0.5 + 0 + 1) / 4 = 0.625
      // nice_avg = (0.5 + 0) / 2 = 0.25
      // 80 × 0.625 + 20 × 0.25 = 50 + 5 = 55
      final r = evaluate(
        requirements: [
          _req(_must, Match.strong),
          _req(_must, Match.partial),
          _req(_must, Match.missing),
          _req(_must, Match.strong),
          _req(_nice, Match.partial),
          _req(_nice, Match.missing),
        ],
      );
      expect(r.mustAvg, 0.625);
      expect(r.niceAvg, 0.25);
      expect(r.score, 55);
    });

    test('no NICE items counts nice_avg as 1', () {
      final r = evaluate(requirements: [_req(_must, Match.partial)]);
      expect(r.niceAvg, 1);
      expect(r.niceCount, 0);
      expect(r.score, 60); // 80 × 0.5 + 20 × 1
    });

    test('rounds to nearest integer', () {
      // must_avg = 2/3 → 80 × 0.666… = 53.33…, + 20 × 0 = 53
      final r = evaluate(
        requirements: [
          _req(_must, Match.strong),
          _req(_must, Match.strong),
          _req(_must, Match.missing),
          _req(_nice, Match.missing),
        ],
      );
      expect(r.score, 53);
    });

    test('calculation line is readable', () {
      final r = evaluate(
        requirements: [_req(_must, Match.strong), _req(_must, Match.partial)],
      );
      expect(
        r.calculation,
        'must_avg = 0.75 (2 items), nice_avg = 1 (0 items) → 80',
      );
    });

    test('same input always gives the same result', () {
      final reqs = [_req(_must, Match.partial), _req(_nice, Match.strong)];
      expect(
        evaluate(requirements: reqs).score,
        evaluate(requirements: reqs).score,
      );
    });
  });

  group('verdict', () {
    final strong = [_req(_must, Match.strong)]; // score 100
    final weak = [_req(_must, Match.missing)]; // score 20

    test('high score + eligible → APPLY', () {
      final r = evaluate(requirements: strong, eligibility: Eligibility.yes);
      expect(r.verdict, Verdict.apply);
    });

    test('high score but eligibility unknown → CAUTION', () {
      final r = evaluate(requirements: strong);
      expect(r.verdict, Verdict.applyWithCaution);
    });

    test('any blocker → SKIP, even with score 100', () {
      final r = evaluate(
        requirements: strong,
        eligibility: Eligibility.yes,
        blockers: [Blocker.notMobileRole],
      );
      expect(r.score, 100);
      expect(r.verdict, Verdict.skip);
    });

    test('score below 45 → SKIP', () {
      final r = evaluate(requirements: weak, eligibility: Eligibility.yes);
      expect(r.verdict, Verdict.skip);
    });

    test('boundaries: 44 SKIP, 45 CAUTION, 59 CAUTION, 60 APPLY', () {
      Verdict at(int score) => decide(score, const [], Eligibility.yes);
      expect(at(44), Verdict.skip);
      expect(at(45), Verdict.applyWithCaution);
      expect(at(59), Verdict.applyWithCaution);
      expect(at(60), Verdict.apply);
    });
  });
}
