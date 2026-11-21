import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../evaluation/evaluation_controller.dart';
import '../history/history.dart';
import 'result_view.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// Recent evaluated jobs. Tap one to see its result again.
/// Chips on top filter the list by application status.
class HistoryList extends ConsumerStatefulWidget {
  const HistoryList({super.key, this.onOpen});

  /// Called after an entry is opened (e.g. to scroll up to the result).
  final VoidCallback? onOpen;

  @override
  ConsumerState<HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends ConsumerState<HistoryList> {
  /// null = show all jobs.
  JobStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'History',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        history.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('$e'),
          data: (all) {
            if (all.isEmpty) {
              return Text(
                'Jobs you evaluate will appear here.',
                style: text.bodyMedium?.copyWith(color: Colors.grey.shade700),
              );
            }
            final entries = [
              for (final e in all)
                if (_filter == null || e.status == _filter) e,
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusFilter(
                  entries: all,
                  selected: _filter,
                  onSelected: (s) => setState(() => _filter = s),
                ),
                const SizedBox(height: 10),
                if (entries.isEmpty)
                  Text(
                    'No jobs with this status.',
                    style: text.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (final (i, entry) in entries.indexed) ...[
                          if (i > 0) const Divider(height: 1),
                          _HistoryTile(entry, onOpen: widget.onOpen),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile(this.entry, {this.onOpen});

  final HistoryEntry entry;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evaluation = Evaluation.fromAnalysis(
      entry.analysis,
      historyId: entry.id,
      coverLetter: entry.coverLetter,
    );
    final r = evaluation.result;
    final a = entry.analysis;
    final color = verdictColor(r.verdict);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Text(
          '${r.score}',
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ),
      title: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          a.company,
          shortDate(entry.createdAt),
          verdictLabel(r.verdict),
        ].where((s) => s.isNotEmpty).join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _StatusMenu(entry),
      onTap: () {
        ref.read(evaluationProvider.notifier).show(evaluation);
        onOpen?.call();
      },
    );
  }
}

Color statusColor(JobStatus s) => switch (s) {
  JobStatus.saved => Colors.grey.shade700,
  JobStatus.applied => const Color(0xFF2F6FDB),
  JobStatus.interview => const Color(0xFF7B4FD6),
  JobStatus.rejected => const Color(0xFFD64545),
  JobStatus.offer => const Color(0xFF1E8E5A),
};

/// Status pill; tap it to change where I am with this job.
class _StatusMenu extends ConsumerWidget {
  const _StatusMenu(this.entry);

  final HistoryEntry entry;

  Future<void> _change(
    BuildContext context,
    WidgetRef ref,
    JobStatus status,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref.read(historyRepositoryProvider).setStatus(entry.id, status);
      ref.invalidate(historyProvider);
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = statusColor(entry.status);
    return PopupMenuButton<JobStatus>(
      key: Key('status-${entry.id}'),
      tooltip: 'Change status',
      initialValue: entry.status,
      onSelected: (s) => _change(context, ref, s),
      itemBuilder: (_) => [
        for (final s in JobStatus.values)
          PopupMenuItem(value: s, child: Text(s.label)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              entry.status.label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 18, color: color),
          ],
        ),
      ),
    );
  }
}

/// "All (n)" plus one chip per status in use, e.g. "Applied (2)".
class _StatusFilter extends StatelessWidget {
  const _StatusFilter({
    required this.entries,
    required this.selected,
    required this.onSelected,
  });

  final List<HistoryEntry> entries;
  final JobStatus? selected;
  final ValueChanged<JobStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    int count(JobStatus s) => entries.where((e) => e.status == s).length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: Text('All (${entries.length})'),
          selected: selected == null,
          onSelected: (_) => onSelected(null),
        ),
        for (final s in JobStatus.values)
          if (count(s) > 0 || s == selected)
            ChoiceChip(
              label: Text('${s.label} (${count(s)})'),
              selected: s == selected,
              selectedColor: statusColor(s).withValues(alpha: 0.15),
              onSelected: (_) => onSelected(s),
            ),
      ],
    );
  }
}
