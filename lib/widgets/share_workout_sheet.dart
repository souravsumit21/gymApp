import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/exercise_media.dart';
import '../models/models.dart';
import '../models/share_models.dart';
import '../services/share_service.dart';
import '../theme/app_theme.dart';
import '../utils/share_config.dart';
import 'username_setup_dialog.dart';

class ShareWorkoutSheet extends ConsumerStatefulWidget {
  final CustomWorkout workout;
  final UserProfile creator;
  final WorkoutShareSnapshot? snapshotOverride;

  const ShareWorkoutSheet({
    super.key,
    required this.workout,
    required this.creator,
    this.snapshotOverride,
  });

  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    required CustomWorkout workout,
    required UserProfile creator,
    WorkoutShareSnapshot? snapshotOverride,
  }) async {
    final ready = await requireUsername(context, ref, creator);
    if (ready == null || !context.mounted) return;

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ShareWorkoutSheet(
            workout: workout,
            creator: ready,
            snapshotOverride: snapshotOverride,
          ),
    );
  }

  @override
  ConsumerState<ShareWorkoutSheet> createState() => _ShareWorkoutSheetState();
}

class _ShareWorkoutSheetState extends ConsumerState<ShareWorkoutSheet> {
  final _searchController = TextEditingController();
  List<UserProfile> _results = [];
  bool _searching = false;
  bool _sharing = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results =
          await ref.read(shareServiceProvider).searchUsersByUsername(query);
      if (!mounted) return;
      setState(() {
        _results = results
            .where((u) => u.uid != widget.creator.uid)
            .toList();
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _shareToUser(UserProfile recipient) async {
    setState(() {
      _sharing = true;
      _error = null;
    });
    try {
      await ref.read(shareServiceProvider).shareInApp(
            workout: widget.workout,
            sender: widget.creator,
            recipientId: recipient.uid,
            snapshotOverride: widget.snapshotOverride,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Shared "${widget.workout.name}" with @${recipient.shareHandle}',
          ),
        ),
      );
    } on ShareException catch (e) {
      if (!mounted) return;
      setState(() {
        _sharing = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sharing = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _shareExternal() async {
    setState(() {
      _sharing = true;
      _error = null;
    });
    try {
      if (!mounted) return;
      await ref.read(shareServiceProvider).shareExternally(
            context: context,
            workout: widget.workout,
            creator: widget.creator,
            snapshotOverride: widget.snapshotOverride,
          );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sharing = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Share Workout',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            widget.workout.name,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          Text('Share in ${ShareConfig.appName}',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by username',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            onChanged: _search,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppTheme.accent)),
          ],
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final user = _results[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.surfaceElevated,
                      backgroundImage: user.photoUrl != null
                          ? NetworkImage(user.photoUrl!)
                          : null,
                      child: user.photoUrl == null
                          ? Text(user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : '?')
                          : null,
                    ),
                    title: Text('@${user.shareHandle}'),
                    subtitle: Text(user.displayName),
                    trailing: _sharing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send_rounded),
                            onPressed: () => _shareToUser(user),
                          ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Text('Share externally',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          const Text(
            'Share a visual workout card with a deep link via WhatsApp, Instagram, and more.',
            style: TextStyle(color: AppTheme.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _sharing ? null : _shareExternal,
              icon: const Icon(Icons.ios_share_rounded),
              label: Text(_sharing ? 'Preparing...' : 'Share Workout Card'),
            ),
          ),
        ],
      ),
    );
  }
}
