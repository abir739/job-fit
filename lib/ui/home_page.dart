import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../evaluation/app_code.dart';
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
    final needsCode =
        ref.watch(appCodeRequiredProvider) &&
        ref.watch(appCodeProvider) == null;

    return Scaffold(
      appBar: AppBar(title: const Text('Job Fit')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (needsCode) ...[
                  const _AppCodeCard(),
                  const SizedBox(height: 16),
                ],
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
                  onPressed: evaluation.isLoading || needsCode
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
                  error: (e, _) => Text(
                    '$e',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
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

/// Asks once for the secret code; it is then remembered in this browser.
class _AppCodeCard extends ConsumerStatefulWidget {
  const _AppCodeCard();

  @override
  ConsumerState<_AppCodeCard> createState() => _AppCodeCardState();
}

class _AppCodeCardState extends ConsumerState<_AppCodeCard> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _save() => ref.read(appCodeProvider.notifier).save(_code.text);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('appCode'),
                controller: _code,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Secret code'),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
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
            if (a.location.isNotEmpty) Text('Location: ${a.location}'),
            Text('Can I work there: ${a.eligibility.name}'),
            if (a.reasons.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final reason in a.reasons) Text('• $reason'),
            ],
            const Divider(height: 24),
            for (final req in a.requirements)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(req.name),
                          if (req.evidence.isNotEmpty)
                            Text(req.evidence, style: text.bodySmall),
                        ],
                      ),
                    ),
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
