import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../evaluation/evaluation_controller.dart';
import '../scoring/fit_score.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _jobText = TextEditingController();

  @override
  void dispose() {
    _jobText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final evaluation = ref.watch(evaluationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Job Fit')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  key: const Key('jobText'),
                  controller: _jobText,
                  minLines: 6,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: 'Paste a job description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: evaluation.isLoading
                      ? null
                      : () => ref
                            .read(evaluationProvider.notifier)
                            .evaluateJob(_jobText.text),
                  child: const Text('Evaluate'),
                ),
                const SizedBox(height: 24),
                evaluation.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Something went wrong: $e'),
                  data: (value) => value == null
                      ? const SizedBox.shrink()
                      : _ResultCard(value),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard(this.evaluation);

  final Evaluation evaluation;

  @override
  Widget build(BuildContext context) {
    final a = evaluation.analysis;
    final r = evaluation.result;
    final text = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${a.title} — ${a.company}', style: text.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Chip(
                  label: Text(_verdictLabel(r.verdict)),
                  backgroundColor: _verdictColor(r.verdict),
                ),
                const SizedBox(width: 12),
                Text('${r.score}/100', style: text.headlineSmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(r.calculation, style: text.bodySmall),
            const SizedBox(height: 8),
            Text(
              'Blockers: ${a.blockers.isEmpty ? 'none' : a.blockers.map((b) => b.name).join(', ')}',
            ),
            Text('Can I work there: ${a.eligibility.name}'),
            const Divider(height: 24),
            for (final req in a.requirements)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(req.name)),
                    SizedBox(
                      width: 56,
                      child: Text(req.type.name.toUpperCase()),
                    ),
                    SizedBox(
                      width: 72,
                      child: Text(req.match.name.toUpperCase()),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _verdictLabel(Verdict v) => switch (v) {
    Verdict.apply => 'APPLY',
    Verdict.applyWithCaution => 'APPLY WITH CAUTION',
    Verdict.skip => 'SKIP',
  };

  static Color _verdictColor(Verdict v) => switch (v) {
    Verdict.apply => Colors.green.shade200,
    Verdict.applyWithCaution => Colors.orange.shade200,
    Verdict.skip => Colors.red.shade200,
  };
}
