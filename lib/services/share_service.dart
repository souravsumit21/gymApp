import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/exercise_media.dart';
import '../models/models.dart';
import '../models/share_models.dart';
import '../utils/share_config.dart';
import '../utils/workout_share_utils.dart';
import '../widgets/workout_share_card.dart';
import 'library_service.dart';
import 'notification_service.dart';

const _uuid = Uuid();

class ShareService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<UserProfile?> findUserByUsername(String username) async {
    final normalized = username.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    final handleDoc =
        await _db.collection('usernames').doc(normalized).get();
    if (!handleDoc.exists) return null;

    final userId = handleDoc.data()?['userId'] as String?;
    if (userId == null) return null;

    final userDoc = await _db.collection('users').doc(userId).get();
    if (!userDoc.exists) return null;
    return UserProfile.fromMap(userDoc.data()!);
  }

  Future<List<UserProfile>> searchUsersByUsername(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.length < 2) return [];

    final snap = await _db
        .collection('usernames')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: normalized)
        .where(FieldPath.documentId, isLessThan: '$normalized\uf8ff')
        .limit(10)
        .get();

    final profiles = <UserProfile>[];
    for (final doc in snap.docs) {
      final userId = doc.data()['userId'] as String?;
      if (userId == null) continue;
      final userDoc = await _db.collection('users').doc(userId).get();
      if (userDoc.exists) {
        profiles.add(UserProfile.fromMap(userDoc.data()!));
      }
    }
    return profiles;
  }

  Future<String> shareInApp({
    required CustomWorkout workout,
    required UserProfile sender,
    required String recipientId,
    WorkoutShareSnapshot? snapshotOverride,
  }) async {
    if (recipientId == sender.uid) {
      throw ShareException('You cannot share a workout with yourself.');
    }

    final shareId = _uuid.v4();
    final snapshot = snapshotOverride ??
        buildShareSnapshot(workout: workout, creator: sender);

    final share = InAppWorkoutShare(
      id: shareId,
      senderId: sender.uid,
      senderUsername: sender.shareHandle,
      senderDisplayName: sender.displayName,
      recipientId: recipientId,
      snapshot: snapshot,
      createdAt: DateTime.now(),
    );

    await _db
        .collection('users')
        .doc(recipientId)
        .collection('received_shares')
        .doc(shareId)
        .set(share.toMap());

    await NotificationService().notifyWorkoutShared(
      recipientId: recipientId,
      senderUsername: sender.shareHandle,
      senderDisplayName: sender.displayName,
      shareId: shareId,
      workoutName: workout.name,
    );

    return shareId;
  }

  Future<String> createExternalShare({
    required CustomWorkout workout,
    required UserProfile creator,
    WorkoutShareSnapshot? snapshotOverride,
  }) async {
    final shareId = _uuid.v4();
    final snapshot = snapshotOverride ??
        buildShareSnapshot(workout: workout, creator: creator);

    final external = ExternalWorkoutShare(
      id: shareId,
      snapshot: snapshot,
      createdAt: DateTime.now(),
    );

    await _db
        .collection('shared_workouts')
        .doc(shareId)
        .set(external.toMap());

    return shareId;
  }

  Future<ExternalWorkoutShare?> getExternalShare(String shareId) async {
    final doc = await _db.collection('shared_workouts').doc(shareId).get();
    if (!doc.exists) return null;
    return ExternalWorkoutShare.fromMap(doc.data()!);
  }

  Future<InAppWorkoutShare?> getInAppShare(
    String userId,
    String shareId,
  ) async {
    final doc = await _db
        .collection('users')
        .doc(userId)
        .collection('received_shares')
        .doc(shareId)
        .get();
    if (!doc.exists) return null;
    return InAppWorkoutShare.fromMap(doc.data()!);
  }

  Future<void> markInAppShareRead(String userId, String shareId) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('received_shares')
        .doc(shareId)
        .update({'isRead': true});
  }

  Stream<List<InAppWorkoutShare>> watchReceivedShares(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('received_shares')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => InAppWorkoutShare.fromMap(d.data()))
            .toList());
  }

  Future<CustomWorkout> saveSharedWorkoutCopy({
    required String userId,
    required WorkoutShareSnapshot snapshot,
    String? sourceShareId,
    bool fromCommunity = false,
    String? sourceCommunityWorkoutId,
  }) async {
    final workout = snapshot.toCustomWorkout(
      id: _uuid.v4(),
      userId: userId,
      importedFromShare: !fromCommunity,
      sourceShareId: fromCommunity ? null : sourceShareId,
      importedFromCommunity: fromCommunity,
      sourceCommunityWorkoutId: sourceCommunityWorkoutId,
    );
    await LibraryService().saveCustomWorkout(workout);
    return workout;
  }

  Future<void> shareExternally({
    required BuildContext context,
    required CustomWorkout workout,
    required UserProfile creator,
    WorkoutShareSnapshot? snapshotOverride,
  }) async {
    final snapshot = snapshotOverride ??
        buildShareSnapshot(workout: workout, creator: creator);
    final shareId = await createExternalShare(
      workout: workout,
      creator: creator,
      snapshotOverride: snapshot,
    );
    final link = ShareConfig.workoutDeepLink(shareId);
    final text =
        '${formatShareText(snapshot)}\n\nOpen in ${ShareConfig.appName}: $link';

    if (!context.mounted) return;

    final key = GlobalKey();
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: -1000,
        child: RepaintBoundary(
          key: key,
          child: WorkoutShareCard(snapshot: snapshot),
        ),
      ),
    );
    overlay.insert(entry);
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final imageBytes = await _captureWidget(key);
      if (imageBytes != null) {
        final file = await _writeTempPng(imageBytes, shareId);
        await SharePlus.instance.share(
          ShareParams(
            text: text,
            subject: '${snapshot.name} — ${ShareConfig.appName} Workout',
            files: [XFile(file.path)],
          ),
        );
      } else {
        await SharePlus.instance.share(ShareParams(text: text));
      }
    } finally {
      entry.remove();
    }
  }

  Future<Uint8List?> _captureWidget(GlobalKey key) async {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<File> _writeTempPng(Uint8List bytes, String shareId) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/workout_share_$shareId.png');
    await file.writeAsBytes(bytes);
    return file;
  }
}

class ShareException implements Exception {
  final String message;
  ShareException(this.message);
  @override
  String toString() => message;
}

final shareServiceProvider = Provider<ShareService>((ref) => ShareService());

final receivedSharesProvider =
    StreamProvider.family<List<InAppWorkoutShare>, String>(
  (ref, userId) => ref.watch(shareServiceProvider).watchReceivedShares(userId),
);
