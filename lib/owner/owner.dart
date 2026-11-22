import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../ai/job_analyzer.dart';
import '../config.dart';
import 'passphrase_store.dart';

/// Sends my passphrase with every request (the server refuses requests without it).
class OwnerClient extends http.BaseClient {
  OwnerClient(this.passphrase, this._inner);

  final String passphrase;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['x-owner-key'] = passphrase;
    return _inner.send(request);
  }
}

/// True when the app was built with a server address (false in tests and local runs).
final serverConfiguredProvider = Provider<bool>(
  (ref) => supabaseUrl.isNotEmpty,
);

/// The plain HTTP client (replaced by a MockClient in tests).
final httpClientProvider = Provider<http.Client>((ref) => http.Client());

final passphraseStoreProvider = Provider<PassphraseStore>(
  (ref) => browserPassphraseStore(),
);

/// My passphrase, or null = demo mode (sample data, no server calls).
class OwnerController extends Notifier<String?> {
  @override
  String? build() => ref.read(passphraseStoreProvider).read();

  /// Checks the passphrase with the server, then remembers it on this device.
  Future<void> login(String passphrase) async {
    passphrase = passphrase.trim();
    if (passphrase.isEmpty) throw AnalyzerException('Enter your passphrase.');
    final http.Response res;
    try {
      res = await OwnerClient(
        passphrase,
        ref.read(httpClientProvider),
      ).get(jobFunctionUri).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw AnalyzerException('Could not reach the server.');
    }
    if (res.statusCode == 401) throw AnalyzerException('Wrong passphrase.');
    if (res.statusCode != 200) {
      throw AnalyzerException('Server error (${res.statusCode}).');
    }
    ref.read(passphraseStoreProvider).write(passphrase);
    state = passphrase;
  }

  void logout() {
    ref.read(passphraseStoreProvider).clear();
    state = null;
  }
}

final ownerProvider = NotifierProvider<OwnerController, String?>(
  OwnerController.new,
);

/// Client for the real server, or null in demo mode.
final serverClientProvider = Provider<http.Client?>((ref) {
  final passphrase = ref.watch(ownerProvider);
  if (!ref.watch(serverConfiguredProvider) || passphrase == null) return null;
  return OwnerClient(passphrase, ref.watch(httpClientProvider));
});
