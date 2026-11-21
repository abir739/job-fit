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
class HistoryList extends ConsumerWidget {
  const HistoryList({super.key, this.onOpen});

  /// Called after an entry is opened (e.g. to scroll up to the result).
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          data: (entries) => entries.isEmpty
              ? Text(
                  'Jobs you evaluate will appear here.',
                  style: text.bodyMedium?.copyWith(color: Colors.grey.shade700),
                )
              : Container(
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
                        _HistoryTile(entry, onOpen: onOpen),
                      ],
                    ],
                  ),
                ),
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
    final evaluation = Evaluation.fromAnalysis(entry.analysis);
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
        [a.company, shortDate(entry.createdAt)].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        verdictLabel(r.verdict),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      onTap: () {
        ref.read(evaluationProvider.notifier).show(evaluation);
        onOpen?.call();
      },
    );
  }
}
