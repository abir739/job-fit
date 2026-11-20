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

void main() {
  testWidgets('no saved code → asks for it; saving remembers it', (
    tester,
  ) async {
    final prefs = await _prefs({});
    await _pump(tester, prefs);

    expect(find.byKey(const Key('appCode')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('appCode')), ' my-code ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('appCode')), findsNothing);
    expect(prefs.getString('app_code'), 'my-code');
  });

  testWidgets('saved code → not asked again', (tester) async {
    await _pump(tester, await _prefs({'app_code': 'my-code'}));
    expect(find.byKey(const Key('appCode')), findsNothing);
  });

  testWidgets('code refused by server → forgotten and asked again', (
    tester,
  ) async {
    final prefs = await _prefs({'app_code': 'old-code'});
    await _pump(tester, prefs, analyzer: _RefusingAnalyzer());

    await tester.enterText(find.byKey(const Key('jobText')), 'Some job ad');
    await tester.tap(find.text('Evaluate'));
    await tester.pumpAndSettle();

    expect(
      find.text('Wrong secret code. Please enter it again.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('appCode')), findsOneWidget);
    expect(prefs.getString('app_code'), isNull);
  });
}
