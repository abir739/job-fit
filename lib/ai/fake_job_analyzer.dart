import '../scoring/fit_score.dart';
import 'job_analyzer.dart';

/// Returns fixed sample data so the UI can be built before the real AI exists.
class FakeJobAnalyzer implements JobAnalyzer {
  const FakeJobAnalyzer({this.delay = const Duration(milliseconds: 400)});

  final Duration delay;

  @override
  Future<JobAnalysis> analyze(String jobDescription) async {
    await Future<void>.delayed(delay);
    return const JobAnalysis(
      title: 'Flutter Developer',
      company: 'Sample Company',
      requirements: [
        Requirement('Flutter', RequirementType.must, Match.strong),
        Requirement('Dart', RequirementType.must, Match.strong),
        Requirement('Riverpod', RequirementType.must, Match.partial),
        Requirement('REST APIs', RequirementType.must, Match.strong),
        Requirement('CI/CD', RequirementType.nice, Match.partial),
        Requirement('Firebase', RequirementType.nice, Match.missing),
      ],
      reasons: ['Sample data: no real AI call.'],
      cvTips: ['Add "Firebase" if you have used it.'],
    );
  }
}
