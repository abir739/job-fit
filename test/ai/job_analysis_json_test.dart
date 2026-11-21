import 'package:flutter_test/flutter_test.dart';
import 'package:job_fit/ai/job_analyzer.dart';
import 'package:job_fit/scoring/fit_score.dart';

Map<String, dynamic> sampleJson() => {
  'title': 'Flutter Developer',
  'company': 'Acme',
  'location': 'Remote, EMEA',
  'requirements': [
    {'name': 'Flutter', 'type': 'must', 'match': 'strong', 'evidence': 'PRO'},
    {'name': 'Fintech', 'type': 'nice', 'match': 'missing', 'evidence': ''},
  ],
  'blockers': ['tooSenior'],
  'eligibility': 'yes',
  'reasons': ['Good match'],
  'cvTips': ['Add Riverpod keyword'],
};

void main() {
  test('reads a valid server answer', () {
    final a = JobAnalysis.fromJson(sampleJson());
    expect(a.title, 'Flutter Developer');
    expect(a.location, 'Remote, EMEA');
    expect(a.requirements, hasLength(2));
    expect(a.requirements.first.type, RequirementType.must);
    expect(a.requirements.first.match, Match.strong);
    expect(a.requirements.first.evidence, 'PRO');
    expect(a.blockers, [Blocker.tooSenior]);
    expect(a.eligibility, Eligibility.yes);
    expect(a.reasons, ['Good match']);
    expect(a.cvTips, ['Add Riverpod keyword']);
  });

  test('old answers without cvTips still load', () {
    final json = sampleJson()..remove('cvTips');
    expect(JobAnalysis.fromJson(json).cvTips, isEmpty);
  });

  test('unknown value is rejected, never guessed', () {
    final json = sampleJson()..['eligibility'] = 'maybe';
    expect(() => JobAnalysis.fromJson(json), throwsFormatException);
  });

  test('unknown blocker is rejected', () {
    final json = sampleJson()..['blockers'] = ['somethingNew'];
    expect(() => JobAnalysis.fromJson(json), throwsFormatException);
  });
}
