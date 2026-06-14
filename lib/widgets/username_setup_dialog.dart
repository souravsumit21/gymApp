import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Prompts the user to pick a unique @username before sharing.
class UsernameSetupDialog extends ConsumerStatefulWidget {
  final String userId;

  const UsernameSetupDialog({super.key, required this.userId});

  static Future<UserProfile?> show(
    BuildContext context,
    WidgetRef ref, {
    required String userId,
  }) {
    return showDialog<UserProfile>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UsernameSetupDialog(userId: userId),
    );
  }

  @override
  ConsumerState<UsernameSetupDialog> createState() =>
      _UsernameSetupDialogState();
}

class _UsernameSetupDialogState extends ConsumerState<UsernameSetupDialog> {
  final _controller = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Choose a username to continue.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final ok = await ref
          .read(authServiceProvider)
          .setUsername(widget.userId, value);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _saving = false;
          _error = 'That username is already taken.';
        });
        return;
      }

      ref.invalidate(userProfileProvider(widget.userId));
      final profile =
          await ref.read(authServiceProvider).loadUserProfile(widget.userId);
      if (!mounted) return;
      Navigator.pop(context, profile);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Choose your username'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pick a unique @username so others can find you when sharing workouts.',
            style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'your_username',
              prefixText: '@',
              errorText: _error,
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saving ? null : _save(),
          ),
          const SizedBox(height: 8),
          Text(
            '3+ characters · letters, numbers, underscores',
            style: TextStyle(color: AppTheme.textMuted, fontSize: AppTheme.textLabel),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Continue'),
        ),
      ],
    );
  }
}

/// Returns an updated profile with a username, or null if the user cancelled.
Future<UserProfile?> requireUsername(
  BuildContext context,
  WidgetRef ref,
  UserProfile profile,
) async {
  if (profile.hasUsername) return profile;
  return UsernameSetupDialog.show(context, ref, userId: profile.uid);
}
