import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../evaluation/evaluation_controller.dart';
import 'result_view.dart';

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
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              children: [
                Text(
                  'Job Fit',
                  style: text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Paste a job. Get a clear answer: apply or not.',
                  style: text.bodyLarge?.copyWith(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 20),
                TextField(
                  key: const Key('jobText'),
                  controller: _jobText,
                  minLines: 6,
                  maxLines: 12,
                  decoration: InputDecoration(
                    hintText: 'Paste the job description here…',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Evaluate'),
                    onPressed: evaluation.isLoading
                        ? null
                        : () => ref
                              .read(evaluationProvider.notifier)
                              .evaluateJob(_jobText.text),
                  ),
                ),
                const SizedBox(height: 24),
                evaluation.when(
                  loading: () => const _Loading(),
                  error: (e, _) => Text(
                    '$e',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  data: (value) => value == null
                      ? const SizedBox.shrink()
                      : ResultView(value),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 12),
        Text('Comparing the job with your profile… (about 15 seconds)'),
      ],
    );
  }
}
