import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Loaded once in main() and injected here (overridden in tests).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override in main() or tests'),
);

/// The real server needs the secret code; fake mode doesn't.
final appCodeRequiredProvider = Provider<bool>((ref) => supabaseUrl.isNotEmpty);

/// Reads the code from my personal link: https://…/job-fit/?k=CODE
/// Returns null when the link has no code.
String? codeFromLink(Uri link) {
  final code = link.queryParameters['k']?.trim();
  return (code == null || code.isEmpty) ? null : code;
}

/// The secret code, remembered in this browser. null = not opened with my link yet.
class AppCodeNotifier extends Notifier<String?> {
  static const key = 'app_code';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  String? build() => _prefs.getString(key);

  Future<void> save(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    await _prefs.setString(key, trimmed);
    state = trimmed;
  }

  Future<void> clear() async {
    await _prefs.remove(key);
    state = null;
  }
}

final appCodeProvider = NotifierProvider<AppCodeNotifier, String?>(
  AppCodeNotifier.new,
);
