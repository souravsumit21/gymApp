import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/share_models.dart';

const _uuid = Uuid();

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<AppNotification>> watchNotifications(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AppNotification.fromMap(d.data()))
            .toList());
  }

  Stream<int> watchUnreadCount(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<void> createNotification(AppNotification notification) async {
    await _db
        .collection('users')
        .doc(notification.userId)
        .collection('notifications')
        .doc(notification.id)
        .set(notification.toMap());
  }

  Future<void> markAsRead(String userId, String notificationId) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> markAllAsRead(String userId) async {
    final snap = await _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<AppNotification> notifyWorkoutShared({
    required String recipientId,
    required String senderUsername,
    required String senderDisplayName,
    required String shareId,
    required String workoutName,
  }) async {
    final notification = AppNotification(
      id: _uuid.v4(),
      userId: recipientId,
      type: NotificationType.workoutShared,
      title: 'Workout shared with you',
      body: '$senderUsername shared a workout with you',
      data: {
        'shareId': shareId,
        'workoutName': workoutName,
        'senderUsername': senderUsername,
        'senderDisplayName': senderDisplayName,
      },
      createdAt: DateTime.now(),
    );
    await createNotification(notification);
    return notification;
  }
}

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

final notificationsProvider =
    StreamProvider.family<List<AppNotification>, String>(
  (ref, userId) =>
      ref.watch(notificationServiceProvider).watchNotifications(userId),
);

final unreadNotificationCountProvider = StreamProvider.family<int, String>(
  (ref, userId) =>
      ref.watch(notificationServiceProvider).watchUnreadCount(userId),
);
