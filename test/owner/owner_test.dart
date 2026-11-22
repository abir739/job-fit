import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:job_fit/ai/edge_function_job_analyzer.dart';
import 'package:job_fit/ai/fake_job_analyzer.dart';
import 'package:job_fit/evaluation/evaluation_controller.dart';
import 'package:job_fit/history/history.dart';
import 'package:job_fit/main.dart';
import 'package:job_fit/owner/owner.dart';
import 'package:job_fit/owner/passphrase_store.dart';

const _right = 'correct horse battery staple';

/// A fake server: 200 with an empty history for the right passphrase, else 401.
/// Records every passphrase it received.
MockClient _server(List<String?> seen) => MockClient((req) async {
  seen.add(req.headers['x-owner-key']);
  return req.headers['x-owner-key'] == _right
      ? http.Response('[]', 200)
      : http.Response('{"error":"Wrong or missing passphrase"}', 401);
});

ProviderContainer _container(
  List<String?> seen, {
  PassphraseStore? store,
  bool configured = true,
}) {
  final container = ProviderContainer(
    overrides: [
      serverConfiguredProvider.overrideWithValue(configured),
      httpClientProvider.overrideWithValue(_server(seen)),
      passphraseStoreProvider.overrideWithValue(
        store ?? MemoryPassphraseStore(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('no passphrase → demo mode with sample data, no server', () {
    final c = _container([]);
    expect(c.read(serverClientProvider), isNull);
    expect(c.read(jobAnalyzerProvider), isA<FakeJobAnalyzer>());
    expect(c.read(historyRepositoryProvider), isA<EmptyHistoryRepository>());
  });

  test('wrong passphrase → refused, nothing saved', () async {
    final store = MemoryPassphraseStore();
    final c = _container([], store: store);
    await expectLater(
      c.read(ownerProvider.notifier).login('wrong guess'),
      throwsA(predicate((e) => '$e' == 'Wrong passphrase.')),
    );
    expect(c.read(ownerProvider), isNull);
    expect(store.read(), isNull);
  });

  test(
    'right passphrase → saved, real server used, sent on every request',
    () async {
      final seen = <String?>[];
      final store = MemoryPassphraseStore();
      final c = _container(seen, store: store);

      await c.read(ownerProvider.notifier).login('  $_right  '); // trimmed
      expect(store.read(), _right);
      expect(c.read(jobAnalyzerProvider), isA<EdgeFunctionJobAnalyzer>());

      await c.read(historyRepositoryProvider).recent();
      expect(seen, [_right, _right]); // login check + history

      c.read(ownerProvider.notifier).logout();
      expect(store.read(), isNull);
      expect(c.read(jobAnalyzerProvider), isA<FakeJobAnalyzer>());
    },
  );

  test('saved passphrase → owner mode right away after reload', () {
    final c = _container([], store: MemoryPassphraseStore(_right));
    expect(c.read(serverClientProvider), isNotNull);
  });

  test('app built without a server → always demo', () {
    final c = _container(
      [],
      store: MemoryPassphraseStore(_right),
      configured: false,
    );
    expect(c.read(serverClientProvider), isNull);
  });

  testWidgets('demo label → Owner login → owner mode → log out', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverConfiguredProvider.overrideWithValue(true),
          httpClientProvider.overrideWithValue(_server([])),
          passphraseStoreProvider.overrideWithValue(MemoryPassphraseStore()),
        ],
        child: const MainApp(),
      ),
    );
    expect(find.textContaining('Demo mode'), findsOneWidget);

    await tester.tap(find.text('Owner login'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('passphrase')), 'nope');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Wrong passphrase.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('passphrase')), _right);
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('Owner mode'), findsOneWidget);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Demo mode'), findsOneWidget);
  });

  testWidgets('no server configured → no login button', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MainApp()));
    expect(find.textContaining('Demo mode'), findsOneWidget);
    expect(find.text('Owner login'), findsNothing);
  });
}
