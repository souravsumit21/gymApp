import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/share_models.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/back_navigation.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final notificationsAsync = ref.watch(notificationsProvider(uid));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        AppBackNavigation.navigateBack(context);
      },
      child: Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => ref
                .read(notificationServiceProvider)
                .markAllAsRead(uid),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: Text(
                'No notifications yet',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final n = notifications[i];
              return _NotificationTile(notification: n);
            },
          );
        },
      ),
    ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final AppNotification notification;

  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = DateFormat.MMMd().add_jm().format(notification.createdAt);

    return Material(
      color: notification.isRead
          ? AppTheme.cardBg
          : AppTheme.primary.withOpacity(0.04),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _handleTap(context, ref),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fitness_center_rounded,
                    color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontWeight: notification.isRead
                            ? FontWeight.w500
                            : FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (notification.data['workoutName'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.data['workoutName'].toString(),
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: AppTheme.textCaption,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(time,
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: AppTheme.textLabel,
                        )),
                  ],
                ),
              ),
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleTap(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid != null) {
      await ref
          .read(notificationServiceProvider)
          .markAsRead(uid, notification.id);
    }

    if (notification.type == NotificationType.workoutShared) {
      final shareId = notification.data['shareId']?.toString();
      if (shareId != null && context.mounted) {
        context.push('/share/$shareId');
      }
    }
  }
}
