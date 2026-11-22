import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../evaluation/evaluation_controller.dart';
import '../search/job_search.dart';
import 'history_list.dart';
import 'job_search_section.dart';
import 'owner_bar.dart';
import 'result_view.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _jobText = TextEditingController();
  final _resultKey = GlobalKey();

  /// After opening an old job, scroll up so its result is visible.
  void _scrollToResult() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _resultKey.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
        );
      }
    });
  }

  /// "Evaluate" on a found job: put its text in the box and evaluate it.
  void _evaluateFound(FoundJob job) {
    _jobText.text = job.jobText;
    ref.read(evaluationProvider.notifier).evaluateJob(job.jobText);
    _scrollToResult();
  }

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
                const SizedBox(height: 12),
                const OwnerBar(),
                const SizedBox(height: 16),
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
                KeyedSubtree(
                  key: _resultKey,
                  child: evaluation.when(
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
                ),
                const SizedBox(height: 24),
                JobSearchSection(onEvaluate: _evaluateFound),
                const SizedBox(height: 24),
                HistoryList(onOpen: _scrollToResult),
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
