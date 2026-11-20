import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Loaded once in main() and injected here (overridden in tests).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override in main() or tests'),
);

/// The real server needs the secret code; fake mode doesn't.
final appCodeRequiredProvider = Provider<bool>((ref) => supabaseUrl.isNotEmpty);

/// The secret code, remembered in this browser. null = not entered yet.
class AppCodeNotifier extends Notifier<String?> {
  static const _key = 'app_code';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  String? build() => _prefs.getString(_key);

  Future<void> save(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    await _prefs.setString(_key, trimmed);
    state = trimmed;
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
    state = null;
  }
}

final appCodeProvider = NotifierProvider<AppCodeNotifier, String?>(
  AppCodeNotifier.new,
);
