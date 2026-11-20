import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_fit/ai/job_analyzer.dart';
import 'package:job_fit/evaluation/app_code.dart';
import 'package:job_fit/evaluation/evaluation_controller.dart';
import 'package:job_fit/ui/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Always refuses the code, like the server with a wrong APP_CODE.
class _RefusingAnalyzer implements JobAnalyzer {
  @override
  Future<JobAnalysis> analyze(String jobDescription) async =>
      throw WrongAppCodeException();
}

Future<SharedPreferences> _prefs(Map<String, Object> values) {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

Future<void> _pump(
  WidgetTester tester,
  SharedPreferences prefs, {
  JobAnalyzer? analyzer,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appCodeRequiredProvider.overrideWithValue(true),
        if (analyzer != null) jobAnalyzerProvider.overrideWithValue(analyzer),
      ],
      child: const MaterialApp(home: HomePage()),
    ),
  );
}

const _linkHint = 'Open this site with your personal link to use it.';

void main() {
  group('codeFromLink', () {
    test('reads ?k= from the link', () {
      expect(
        codeFromLink(Uri.parse('https://x.github.io/job-fit/?k=abc123')),
        'abc123',
      );
    });

    test('no code or empty code → null', () {
      expect(codeFromLink(Uri.parse('https://x.github.io/job-fit/')), isNull);
      expect(
        codeFromLink(Uri.parse('https://x.github.io/job-fit/?k=')),
        isNull,
      );
    });
  });

  testWidgets('no saved code → hint shown, Evaluate disabled', (tester) async {
    await _pump(tester, await _prefs({}));

    expect(find.text(_linkHint), findsOneWidget);
    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Evaluate'),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('saved code → no hint', (tester) async {
    await _pump(tester, await _prefs({'app_code': 'my-code'}));
    expect(find.text(_linkHint), findsNothing);
  });

  testWidgets('code refused by server → forgotten, hint shown', (tester) async {
    final prefs = await _prefs({'app_code': 'old-code'});
    await _pump(tester, prefs, analyzer: _RefusingAnalyzer());

    await tester.enterText(find.byKey(const Key('jobText')), 'Some job ad');
    await tester.tap(find.text('Evaluate'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This link is not valid. Open the site with your personal link.',
      ),
      findsOneWidget,
    );
    expect(find.text(_linkHint), findsOneWidget);
    expect(prefs.getString('app_code'), isNull);
  });
}
