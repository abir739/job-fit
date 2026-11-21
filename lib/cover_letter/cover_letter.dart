import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../ai/job_analyzer.dart';
import '../config.dart';

/// Writes a cover letter for a job saved in the history.
abstract interface class CoverLetterWriter {
  Future<String> write(int historyId);
}

/// Asks the Edge Function: POST { coverLetterFor: id } → { coverLetter }.
class EdgeFunctionCoverLetterWriter implements CoverLetterWriter {
  EdgeFunctionCoverLetterWriter({required this.endpoint, http.Client? client})
    : _client = client ?? http.Client();

  final Uri endpoint;
  final http.Client _client;

  @override
  Future<String> write(int historyId) async {
    final http.Response res;
    try {
      res = await _client
          .post(
            endpoint,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'coverLetterFor': historyId}),
          )
          .timeout(const Duration(seconds: 100));
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
    final letter = body is Map ? body['coverLetter'] : null;
    if (res.statusCode != 200 || letter is! String) {
      final error = body is Map ? body['error'] : null;
      throw AnalyzerException(
        '${error ?? 'Server error'} (${res.statusCode}). Please try again.',
      );
    }
    return letter;
  }
}

/// No server (fake mode): a fixed sample letter.
class FakeCoverLetterWriter implements CoverLetterWriter {
  const FakeCoverLetterWriter();

  @override
  Future<String> write(int historyId) async =>
      'Dear Hiring Team,\n\nSample cover letter: no real AI call.\n\nBest regards';
}

final coverLetterWriterProvider = Provider<CoverLetterWriter>((ref) {
  if (supabaseUrl.isEmpty) return const FakeCoverLetterWriter();
  return EdgeFunctionCoverLetterWriter(endpoint: jobFunctionUri);
});
