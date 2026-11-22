import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../ai/job_analyzer.dart';
import '../config.dart';
import '../owner/owner.dart';

/// "Hamburg  (+ 1 weiterer Standort)   •  über DEVjobs.de" → "Hamburg (+ 1 weiterer Standort)".
/// Drops the "via (site)" part and extra spaces.
String cleanLocation(String raw) {
  final parts = raw.split('•').map((p) => p.trim()).where((p) {
    final lower = p.toLowerCase();
    return p.isNotEmpty &&
        !lower.startsWith('über ') &&
        !lower.startsWith('via ');
  });
  return parts.join(' · ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// One job ad found on the web (not evaluated yet).
class FoundJob {
  const FoundJob({
    required this.title,
    required this.company,
    this.location = '',
    this.url = '',
    this.posted = '',
    this.summary = '',
    this.why = '',
  });

  /// Returns null when the title or company is missing.
  static FoundJob? tryFromJson(Object? json) {
    if (json is! Map) return null;
    String str(String key) => json[key] is String ? json[key] as String : '';
    if (str('title').isEmpty || str('company').isEmpty) return null;
    return FoundJob(
      title: str('title'),
      company: str('company'),
      location: cleanLocation(str('location')),
      url: str('url'),
      posted: str('posted'),
      summary: str('summary'),
      why: str('why'),
    );
  }

  final String title;
  final String company;
  final String location;
  final String url;
  final String posted;
  final String summary;
  final String why;

  /// Text sent to the normal evaluation when I tap "Evaluate".
  String get jobText => [
    title,
    company,
    if (location.isNotEmpty) location,
    if (summary.isNotEmpty) '\n$summary',
    if (url.isNotEmpty) '\nSource: $url',
  ].join('\n');
}

abstract interface class JobFinder {
  /// [where] is optional, e.g. "Germany" or "remote".
  Future<List<FoundJob>> find(String where);
}

/// Asks the Edge Function: POST { findJobs: where } → { jobs: [...] }.
class EdgeFunctionJobFinder implements JobFinder {
  EdgeFunctionJobFinder({required this.endpoint, http.Client? client})
    : _client = client ?? http.Client();

  final Uri endpoint;
  final http.Client _client;

  @override
  Future<List<FoundJob>> find(String where) async {
    final http.Response res;
    try {
      res = await _client
          .post(
            endpoint,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'findJobs': where.trim()}),
          )
          .timeout(const Duration(seconds: 130));
    } on TimeoutException {
      throw AnalyzerException('The search took too long. Please try again.');
    } catch (_) {
      throw AnalyzerException('Could not reach the server.');
    }

    final Object? body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      throw AnalyzerException('Unexpected server answer (${res.statusCode}).');
    }
    final jobs = body is Map ? body['jobs'] : null;
    if (res.statusCode != 200 || jobs is! List) {
      final error = body is Map ? body['error'] : null;
      throw AnalyzerException(
        '${error ?? 'Server error'} (${res.statusCode}). Please try again.',
      );
    }
    return [for (final j in jobs) ?FoundJob.tryFromJson(j)];
  }
}

/// No server (fake mode): fixed sample ads.
class FakeJobFinder implements JobFinder {
  const FakeJobFinder();

  @override
  Future<List<FoundJob>> find(String where) async => const [
    FoundJob(
      title: 'Flutter Developer',
      company: 'Sample Company',
      location: 'Remote, Europe',
      url: 'https://example.com/job/1',
      posted: '2 days ago',
      summary: 'Build our Flutter app. 3+ years Flutter, Riverpod, REST.',
      why: 'Flutter-first role open to remote in Europe.',
    ),
  ];
}

final jobFinderProvider = Provider<JobFinder>((ref) {
  final client = ref.watch(serverClientProvider);
  if (client == null) return const FakeJobFinder(); // demo mode
  return EdgeFunctionJobFinder(endpoint: jobFunctionUri, client: client);
});

/// null = no search yet.
class JobSearchController extends AsyncNotifier<List<FoundJob>?> {
  @override
  FutureOr<List<FoundJob>?> build() {
    ref.watch(jobFinderProvider); // log in / out → clear old results
    return null; // sync: ready on first frame
  }

  Future<void> search(String where) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(jobFinderProvider).find(where),
    );
  }
}

final jobSearchProvider =
    AsyncNotifierProvider<JobSearchController, List<FoundJob>?>(
      JobSearchController.new,
    );
