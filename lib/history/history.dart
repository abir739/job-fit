import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../ai/job_analyzer.dart';
import '../config.dart';

/// Where I am with a job. Same names as JOB_STATUSES in the Edge Function.
enum JobStatus {
  saved('Saved'),
  applied('Applied'),
  interview('Interview'),
  rejected('Rejected'),
  offer('Offer');

  const JobStatus(this.label);
  final String label;

  /// Unknown or missing values fall back to [saved].
  static JobStatus parse(Object? value) =>
      values.asNameMap()[value] ?? JobStatus.saved;
}

/// One saved evaluation. The score is recomputed by the app's rules.
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.createdAt,
    required this.analysis,
    this.status = JobStatus.saved,
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
        status: JobStatus.parse(json['status']),
      );
    } catch (_) {
      return null;
    }
  }

  final int id;
  final DateTime createdAt;
  final JobAnalysis analysis;
  final JobStatus status;
}

abstract interface class HistoryRepository {
  Future<List<HistoryEntry>> recent();
  Future<void> setStatus(int id, JobStatus status);
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

  @override
  Future<void> setStatus(int id, JobStatus status) async {
    final res = await _client
        .patch(
          endpoint,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id': id, 'status': status.name}),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw AnalyzerException('Could not save status (${res.statusCode}).');
    }
  }
}

/// No server (fake mode): no history.
class EmptyHistoryRepository implements HistoryRepository {
  const EmptyHistoryRepository();

  @override
  Future<List<HistoryEntry>> recent() async => const [];

  @override
  Future<void> setStatus(int id, JobStatus status) async {}
}

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  if (supabaseUrl.isEmpty) return const EmptyHistoryRepository();
  return EdgeFunctionHistoryRepository(endpoint: jobFunctionUri);
});

final historyProvider = FutureProvider<List<HistoryEntry>>(
  (ref) => ref.watch(historyRepositoryProvider).recent(),
);
