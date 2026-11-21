import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../search/job_search.dart';
import 'open_url.dart';

/// "Find jobs": searches the web for matching ads; tap one to evaluate it.
class JobSearchSection extends ConsumerStatefulWidget {
  const JobSearchSection({super.key, required this.onEvaluate});

  /// Called with the ad's text when I tap "Evaluate" on a result.
  final ValueChanged<FoundJob> onEvaluate;

  @override
  ConsumerState<JobSearchSection> createState() => _JobSearchSectionState();
}

class _JobSearchSectionState extends ConsumerState<JobSearchSection> {
  final _where = TextEditingController();

  @override
  void dispose() {
    _where.dispose();
    super.dispose();
  }

  void _search() => ref.read(jobSearchProvider.notifier).search(_where.text);

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(jobSearchProvider);
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Find jobs',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Searches the web for open jobs that fit your profile.',
          style: text.bodyMedium?.copyWith(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('where'),
                controller: _where,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: 'Where? (optional, e.g. Germany, remote)',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: search.isLoading ? null : _search,
              icon: const Icon(Icons.travel_explore),
              label: const Text('Find jobs'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        search.when(
          // Show the spinner on every search, even when old results exist.
          skipLoadingOnRefresh: false,
          loading: () => const Row(
            children: [
              SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(child: Text('Searching the web… (up to a minute)')),
            ],
          ),
          error: (e, _) => Text(
            '$e',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          data: (jobs) {
            if (jobs == null) return const SizedBox.shrink();
            if (jobs.isEmpty) {
              return Text(
                'No matching jobs found. Try another place.',
                style: text.bodyMedium?.copyWith(color: Colors.grey.shade700),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final job in jobs)
                  _FoundJobCard(job, onEvaluate: () => widget.onEvaluate(job)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FoundJobCard extends StatelessWidget {
  const _FoundJobCard(this.job, {required this.onEvaluate});

  final FoundJob job;
  final VoidCallback onEvaluate;

  /// The ad's link, or a Google search for it when the AI gave no link.
  String get _link => job.url.isNotEmpty
      ? job.url
      : Uri.https('www.google.com', '/search', {
          'q': '${job.title} ${job.company} job',
        }).toString();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            job.title,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            [
              job.company,
              job.location,
              job.posted,
            ].where((s) => s.isNotEmpty).join(' · '),
            style: text.bodySmall?.copyWith(color: Colors.grey.shade700),
          ),
          if (job.why.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(job.why, style: text.bodyMedium),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => openUrl(_link),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open ad'),
              ),
              TextButton.icon(
                onPressed: onEvaluate,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Evaluate'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
