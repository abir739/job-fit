import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cover_letter/cover_letter.dart';
import '../history/history.dart';

/// "Write cover letter" button; then the letter with a Copy button.
class CoverLetterCard extends ConsumerStatefulWidget {
  const CoverLetterCard({
    super.key,
    required this.historyId,
    this.initialLetter,
  });

  final int historyId;
  final String? initialLetter;

  @override
  ConsumerState<CoverLetterCard> createState() => _CoverLetterCardState();
}

class _CoverLetterCardState extends ConsumerState<CoverLetterCard> {
  late String? _letter = widget.initialLetter;
  bool _loading = false;
  String? _error;

  Future<void> _write() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final letter = await ref
          .read(coverLetterWriterProvider)
          .write(widget.historyId);
      if (!mounted) return;
      setState(() => _letter = letter);
      ref.invalidate(historyProvider); // the server saved it with the job
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _letter!));
    if (mounted) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('Cover letter copied')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final letter = _letter;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cover letter',
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (letter != null)
                TextButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (letter != null)
            SelectableText(letter, style: text.bodyMedium)
          else if (_loading)
            const Row(
              children: [
                SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Writing your cover letter…'),
              ],
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: _write,
                icon: const Icon(Icons.edit),
                label: const Text('Write cover letter'),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
