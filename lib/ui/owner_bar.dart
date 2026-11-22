import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../owner/owner.dart';

/// Demo mode: a label + "Owner login". Owner mode: a small "Log out".
class OwnerBar extends ConsumerWidget {
  const OwnerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(serverClientProvider) != null;
    final canLogIn = ref.watch(serverConfiguredProvider);
    final small = Theme.of(context).textTheme.bodySmall;

    if (isOwner) {
      return Row(
        children: [
          Icon(Icons.lock_open, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Owner mode: real AI and your history',
              style: small?.copyWith(color: Colors.grey.shade700),
            ),
          ),
          TextButton(
            onPressed: ref.read(ownerProvider.notifier).logout,
            child: const Text('Log out'),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Demo mode – sample data, no real AI',
              style: small?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (canLogIn)
            TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const _LoginDialog(),
              ),
              child: const Text('Owner login'),
            ),
        ],
      ),
    );
  }
}

class _LoginDialog extends ConsumerStatefulWidget {
  const _LoginDialog();

  @override
  ConsumerState<_LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends ConsumerState<_LoginDialog> {
  final _passphrase = TextEditingController();
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _passphrase.dispose();
    super.dispose();
  }

  Future<void> _logIn() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      await ref.read(ownerProvider.notifier).login(_passphrase.text);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _checking = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Owner login'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Remembered on this device until you log out.'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('passphrase'),
            controller: _passphrase,
            obscureText: true,
            autofocus: true,
            enabled: !_checking,
            onSubmitted: (_) => _logIn(),
            decoration: const InputDecoration(labelText: 'Passphrase'),
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
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _checking ? null : _logIn,
          child: Text(_checking ? 'Checking…' : 'Log in'),
        ),
      ],
    );
  }
}
