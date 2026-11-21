import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'job_analyzer.dart';

/// Calls the Supabase Edge Function, which holds the profile and the AI key.
class EdgeFunctionJobAnalyzer implements JobAnalyzer {
  EdgeFunctionJobAnalyzer({
    required this.endpoint,
    http.Client? client,
    this.timeout = const Duration(seconds: 100),
  }) : _client = client ?? http.Client();

  final Uri endpoint;

  final http.Client _client;
  final Duration timeout;

  @override
  Future<JobAnalysis> analyze(String jobDescription) async {
    final http.Response res;
    try {
      res = await _client
          .post(
            endpoint,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'jobText': jobDescription}),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw AnalyzerException('The AI took too long. Please try again.');
    } catch (_) {
      throw AnalyzerException('Could not reach the server.');
    }

    final Object? body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      throw AnalyzerException('Unexpected server answer (${res.statusCode}).');
    }

    if (res.statusCode != 200) {
      final error = body is Map ? body['error'] : null;
      throw AnalyzerException(
        '${error ?? 'Server error'} (${res.statusCode}). Please try again.',
      );
    }

    try {
      return JobAnalysis.fromJson(body as Map<String, dynamic>);
    } catch (_) {
      throw AnalyzerException(
        'The AI answer was incomplete. Please try again.',
      );
    }
  }
}
