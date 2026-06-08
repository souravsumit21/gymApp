import 'exercise_media.dart';

/// Snapshot of a workout for sharing — weights stripped, structure preserved.
class WorkoutShareSnapshot {
  final String name;
  final String? description;
  final List<CustomWorkoutExercise> exercises;
  final List<String> targetMuscles;
  final List<String> selectedEquipment;
  final List<String> targetBodyParts;
  final int estimatedMinutes;
  final int exerciseCount;
  final String creatorId;
  final String creatorUsername;
  final String creatorDisplayName;

  const WorkoutShareSnapshot({
    required this.name,
    this.description,
    required this.exercises,
    required this.targetMuscles,
    this.selectedEquipment = const [],
    this.targetBodyParts = const [],
    required this.estimatedMinutes,
    int? exerciseCount,
    required this.creatorId,
    required this.creatorUsername,
    required this.creatorDisplayName,
  }) : exerciseCount = exerciseCount ?? exercises.length;

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'exercises': exercises.map((e) => e.toMap()).toList(),
        'targetMuscles': targetMuscles,
        'selectedEquipment': selectedEquipment,
        'targetBodyParts': targetBodyParts,
        'estimatedMinutes': estimatedMinutes,
        'exerciseCount': exerciseCount,
        'creatorId': creatorId,
        'creatorUsername': creatorUsername,
        'creatorDisplayName': creatorDisplayName,
      };

  factory WorkoutShareSnapshot.fromMap(Map<String, dynamic> m) =>
      WorkoutShareSnapshot(
        name: m['name'],
        description: m['description'],
        exercises: (m['exercises'] as List)
            .map((e) => CustomWorkoutExercise.fromMap(
                Map<String, dynamic>.from(e)))
            .toList(),
        targetMuscles: List<String>.from(m['targetMuscles'] ?? []),
        selectedEquipment: List<String>.from(m['selectedEquipment'] ?? []),
        targetBodyParts: List<String>.from(m['targetBodyParts'] ?? []),
        estimatedMinutes: m['estimatedMinutes'] ?? 30,
        exerciseCount: m['exerciseCount'],
        creatorId: m['creatorId'],
        creatorUsername: m['creatorUsername'] ?? '',
        creatorDisplayName: m['creatorDisplayName'] ?? 'Athlete',
      );

  CustomWorkout toCustomWorkout({
    required String id,
    required String userId,
    bool importedFromShare = false,
    String? sourceShareId,
    bool importedFromCommunity = false,
    String? sourceCommunityWorkoutId,
  }) =>
      CustomWorkout(
        id: id,
        userId: userId,
        name: name,
        description: description,
        exercises: exercises,
        targetMuscles: targetMuscles,
        selectedEquipment: selectedEquipment,
        targetBodyParts: targetBodyParts,
        estimatedMinutes: estimatedMinutes,
        exerciseCount: exerciseCount,
        createdAt: DateTime.now(),
        importedFromShare: importedFromShare,
        sourceShareId: sourceShareId,
        importedFromCommunity: importedFromCommunity,
        sourceCommunityWorkoutId: sourceCommunityWorkoutId,
      );
}

/// Direct in-app share delivered to a recipient.
class InAppWorkoutShare {
  final String id;
  final String senderId;
  final String senderUsername;
  final String senderDisplayName;
  final String recipientId;
  final WorkoutShareSnapshot snapshot;
  final DateTime createdAt;
  final bool isRead;

  const InAppWorkoutShare({
    required this.id,
    required this.senderId,
    required this.senderUsername,
    required this.senderDisplayName,
    required this.recipientId,
    required this.snapshot,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'senderId': senderId,
        'senderUsername': senderUsername,
        'senderDisplayName': senderDisplayName,
        'recipientId': recipientId,
        'snapshot': snapshot.toMap(),
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
      };

  factory InAppWorkoutShare.fromMap(Map<String, dynamic> m) =>
      InAppWorkoutShare(
        id: m['id'],
        senderId: m['senderId'],
        senderUsername: m['senderUsername'] ?? '',
        senderDisplayName: m['senderDisplayName'] ?? 'Athlete',
        recipientId: m['recipientId'],
        snapshot: WorkoutShareSnapshot.fromMap(
            Map<String, dynamic>.from(m['snapshot'])),
        createdAt: DateTime.parse(m['createdAt']),
        isRead: m['isRead'] ?? false,
      );
}

/// Public link snapshot for external sharing.
class ExternalWorkoutShare {
  final String id;
  final WorkoutShareSnapshot snapshot;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const ExternalWorkoutShare({
    required this.id,
    required this.snapshot,
    required this.createdAt,
    this.expiresAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'snapshot': snapshot.toMap(),
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
      };

  factory ExternalWorkoutShare.fromMap(Map<String, dynamic> m) =>
      ExternalWorkoutShare(
        id: m['id'],
        snapshot: WorkoutShareSnapshot.fromMap(
            Map<String, dynamic>.from(m['snapshot'])),
        createdAt: DateTime.parse(m['createdAt']),
        expiresAt: m['expiresAt'] != null
            ? DateTime.parse(m['expiresAt'])
            : null,
      );
}

/// Workout published to the community library.
class CommunityWorkout {
  final String id;
  final String creatorId;
  final String creatorUsername;
  final String creatorDisplayName;
  final String name;
  final String description;
  final WorkoutShareSnapshot snapshot;
  final List<String> bodyParts;
  final List<String> equipment;
  final String experienceLevel;
  final int estimatedMinutes;
  final int exerciseCount;
  final String workoutMode;
  final int saveCount;
  final DateTime publishedAt;
  final List<String> searchKeywords;

  const CommunityWorkout({
    required this.id,
    required this.creatorId,
    required this.creatorUsername,
    required this.creatorDisplayName,
    required this.name,
    required this.description,
    required this.snapshot,
    required this.bodyParts,
    required this.equipment,
    required this.experienceLevel,
    required this.estimatedMinutes,
    required this.exerciseCount,
    this.workoutMode = 'standard',
    this.saveCount = 0,
    required this.publishedAt,
    this.searchKeywords = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'creatorId': creatorId,
        'creatorUsername': creatorUsername,
        'creatorDisplayName': creatorDisplayName,
        'name': name,
        'description': description,
        'snapshot': snapshot.toMap(),
        'bodyParts': bodyParts,
        'equipment': equipment,
        'experienceLevel': experienceLevel,
        'estimatedMinutes': estimatedMinutes,
        'exerciseCount': exerciseCount,
        'workoutMode': workoutMode,
        'saveCount': saveCount,
        'publishedAt': publishedAt.toIso8601String(),
        'searchKeywords': searchKeywords,
      };

  factory CommunityWorkout.fromMap(Map<String, dynamic> m) => CommunityWorkout(
        id: m['id'],
        creatorId: m['creatorId'],
        creatorUsername: m['creatorUsername'] ?? '',
        creatorDisplayName: m['creatorDisplayName'] ?? 'Athlete',
        name: m['name'],
        description: m['description'] ?? '',
        snapshot: WorkoutShareSnapshot.fromMap(
            Map<String, dynamic>.from(m['snapshot'])),
        bodyParts: List<String>.from(m['bodyParts'] ?? []),
        equipment: List<String>.from(m['equipment'] ?? []),
        experienceLevel: m['experienceLevel'] ?? 'beginner',
        estimatedMinutes: m['estimatedMinutes'] ?? 30,
        exerciseCount: m['exerciseCount'] ?? 0,
        workoutMode: m['workoutMode'] ?? 'standard',
        saveCount: m['saveCount'] ?? 0,
        publishedAt: DateTime.parse(m['publishedAt']),
        searchKeywords: List<String>.from(m['searchKeywords'] ?? []),
      );
}

enum NotificationType {
  workoutShared,
}

class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.data = const {},
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'type': type.name,
        'title': title,
        'body': body,
        'data': data,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
      };

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
        id: m['id'],
        userId: m['userId'],
        type: NotificationType.values.byName(m['type']),
        title: m['title'],
        body: m['body'],
        data: Map<String, dynamic>.from(m['data'] ?? {}),
        createdAt: DateTime.parse(m['createdAt']),
        isRead: m['isRead'] ?? false,
      );
}

enum CommunitySort { popular, newest, mostSaved }

class CommunityFilterState {
  final String query;
  final List<String> bodyParts;
  final List<String> equipment;
  final String experienceLevel;
  final int? maxDuration;
  final String workoutMode;
  final CommunitySort sort;

  const CommunityFilterState({
    this.query = '',
    this.bodyParts = const [],
    this.equipment = const [],
    this.experienceLevel = 'all',
    this.maxDuration,
    this.workoutMode = 'all',
    this.sort = CommunitySort.popular,
  });

  CommunityFilterState copyWith({
    String? query,
    List<String>? bodyParts,
    List<String>? equipment,
    String? experienceLevel,
    int? maxDuration,
    bool clearMaxDuration = false,
    String? workoutMode,
    CommunitySort? sort,
  }) =>
      CommunityFilterState(
        query: query ?? this.query,
        bodyParts: bodyParts ?? this.bodyParts,
        equipment: equipment ?? this.equipment,
        experienceLevel: experienceLevel ?? this.experienceLevel,
        maxDuration:
            clearMaxDuration ? null : (maxDuration ?? this.maxDuration),
        workoutMode: workoutMode ?? this.workoutMode,
        sort: sort ?? this.sort,
      );

  bool get hasActiveFilters =>
      query.isNotEmpty ||
      bodyParts.isNotEmpty ||
      equipment.isNotEmpty ||
      experienceLevel != 'all' ||
      maxDuration != null ||
      workoutMode != 'all';
}
