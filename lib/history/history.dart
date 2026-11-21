import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../ai/job_analyzer.dart';
import '../config.dart';

/// One saved evaluation. The score is recomputed by the app's rules.
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.createdAt,
    required this.analysis,
  });

  /// Returns null for an entry that can't be read, so one bad row
  /// never hides the whole history.
  static HistoryEntry? tryFromJson(Map<String, dynamic> json) {
    try {
      return HistoryEntry(
        id: json['id'] as int,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        analysis: JobAnalysis.fromJson(
          json['analysis'] as Map<String, dynamic>,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  final int id;
  final DateTime createdAt;
  final JobAnalysis analysis;
}

abstract interface class HistoryRepository {
  Future<List<HistoryEntry>> recent();
}

/// Reads the history from the Edge Function (GET).
class EdgeFunctionHistoryRepository implements HistoryRepository {
  EdgeFunctionHistoryRepository({required this.endpoint, http.Client? client})
    : _client = client ?? http.Client();

  final Uri endpoint;
  final http.Client _client;

  @override
  Future<List<HistoryEntry>> recent() async {
    final res = await _client
        .get(endpoint)
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw AnalyzerException('Could not load history (${res.statusCode}).');
    }
    final rows = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    return [
      for (final row in rows)
        ?HistoryEntry.tryFromJson(row as Map<String, dynamic>),
    ];
  }
}

/// No server (fake mode): no history.
class EmptyHistoryRepository implements HistoryRepository {
  const EmptyHistoryRepository();

  @override
  Future<List<HistoryEntry>> recent() async => const [];
}

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  if (supabaseUrl.isEmpty) return const EmptyHistoryRepository();
  return EdgeFunctionHistoryRepository(endpoint: jobFunctionUri);
});

final historyProvider = FutureProvider<List<HistoryEntry>>(
  (ref) => ref.watch(historyRepositoryProvider).recent(),
);
