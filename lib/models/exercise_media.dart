// lib/models/exercise_media.dart
// Extends the base Exercise model with rich media and library management

enum MediaType { gif, video, image }

class ExerciseMedia {
  final String exerciseId;
  final MediaType primaryType;
  final String? gifUrl;        // Animated GIF demonstrating the movement
  final String? videoUrl;      // MP4 for higher quality / longer demos
  final String? thumbnailUrl;  // Static preview image
  final String? storageRef;    // Firebase Storage path (if hosted there)
  final String provider;       // exercisedb | firebase_storage | internal
  final String? gender;        // male | female | neutral
  final String status;         // active | broken | replaced
  final Duration? videoDuration;

  const ExerciseMedia({
    required this.exerciseId,
    required this.primaryType,
    this.gifUrl,
    this.videoUrl,
    this.thumbnailUrl,
    this.storageRef,
    this.provider = 'local',
    this.gender,
    this.status = 'active',
    this.videoDuration,
  });

  // Resolve best available URL for display
  String? get displayUrl => gifUrl ?? videoUrl ?? thumbnailUrl;

  Map<String, dynamic> toMap() => {
    'exerciseId': exerciseId,
    'primaryType': primaryType.name,
    'gifUrl': gifUrl,
    'videoUrl': videoUrl,
    'thumbnailUrl': thumbnailUrl,
    'storageRef': storageRef,
    'provider': provider,
    'gender': gender,
    'status': status,
    'videoDurationSeconds': videoDuration?.inSeconds,
  };

  factory ExerciseMedia.fromMap(Map<String, dynamic> m) => ExerciseMedia(
    exerciseId: m['exerciseId'],
    primaryType: MediaType.values.byName(m['primaryType'] ?? 'image'),
    gifUrl: m['gifUrl'],
    videoUrl: m['videoUrl'],
    thumbnailUrl: m['thumbnailUrl'] ?? m['imageUrl'],
    storageRef: m['storageRef'] ?? m['storagePath'],
    provider: m['provider'] ?? 'unknown',
    gender: m['gender'],
    status: m['status'] ?? 'active',
    videoDuration: m['videoDurationSeconds'] != null
        ? Duration(seconds: m['videoDurationSeconds'])
        : null,
  );
}

/// Full exercise entry in the library — combines Exercise + ExerciseMedia
class LibraryExercise {
  final String id;
  final String name;
  final String description;
  final String instructions;       // Step-by-step cues
  final List<String> tips;         // Common mistakes / coaching tips
  final List<String> muscleGroups; // Primary muscles
  final List<String> secondaryMuscles;
  final List<String> requiredEquipment;
  final String difficulty;         // beginner | intermediate | advanced
  final String category;           // strength | cardio | core | flexibility | plyometric
  final ExerciseMedia? media;
  final int defaultSets;
  final int? defaultReps;
  final int? defaultSeconds;       // For time-based exercises
  final int restSeconds;
  final List<String> tags;         // searchable tags e.g. ['push', 'compound', 'chest']
  final bool isFeatured;
  final double? metValue;          // MET value for calorie estimation
  final String source;             // local | exercisedb | manual | internal
  final String? sourceExerciseId;
  final List<ExerciseMedia> mediaItems;

  const LibraryExercise({
    required this.id,
    required this.name,
    required this.description,
    required this.instructions,
    this.tips = const [],
    required this.muscleGroups,
    this.secondaryMuscles = const [],
    required this.requiredEquipment,
    required this.difficulty,
    required this.category,
    this.media,
    this.defaultSets = 3,
    this.defaultReps,
    this.defaultSeconds,
    this.restSeconds = 60,
    this.tags = const [],
    this.isFeatured = false,
    this.metValue,
    this.source = 'local',
    this.sourceExerciseId,
    this.mediaItems = const [],
  });

  bool get isTimeBased => defaultSeconds != null;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'instructions': instructions,
    'tips': tips,
    'muscleGroups': muscleGroups,
    'secondaryMuscles': secondaryMuscles,
    'requiredEquipment': requiredEquipment,
    'difficulty': difficulty,
    'category': category,
    'media': media?.toMap(),
    'defaultSets': defaultSets,
    'defaultReps': defaultReps,
    'defaultSeconds': defaultSeconds,
    'restSeconds': restSeconds,
    'tags': tags,
    'isFeatured': isFeatured,
    'metValue': metValue,
    'source': source,
    'sourceExerciseId': sourceExerciseId,
    'mediaItems': mediaItems.map((m) => m.toMap()).toList(),
  };

  factory LibraryExercise.fromMap(Map<String, dynamic> m) {
    final mediaItems = (m['mediaItems'] as List? ?? [])
        .map((item) => ExerciseMedia.fromMap(Map<String, dynamic>.from(item)))
        .toList();
    final activeMedia = mediaItems.where((item) => item.status == 'active');
    final embeddedMedia = m['media'] != null
        ? ExerciseMedia.fromMap(Map<String, dynamic>.from(m['media']))
        : activeMedia.isNotEmpty
            ? activeMedia.first
            : mediaItems.isNotEmpty
                ? mediaItems.first
                : null;
    final instructionsValue = m['instructions'];
    final instructions = instructionsValue is List
        ? instructionsValue.map((item) => item.toString()).join('\n')
        : instructionsValue?.toString() ?? '';

    return LibraryExercise(
      id: m['id'],
      name: m['name'],
      description: m['description'] ?? m['overview'] ?? '',
      instructions: instructions,
      tips: List<String>.from(m['tips'] ?? m['exerciseTips'] ?? []),
      muscleGroups: List<String>.from(
        m['muscleGroups'] ?? m['targetMuscles'] ?? m['bodyParts'] ?? [],
      ),
      secondaryMuscles: List<String>.from(m['secondaryMuscles'] ?? []),
      requiredEquipment: List<String>.from(
        m['requiredEquipment'] ?? m['equipment'] ?? m['equipments'] ?? [],
      ),
      difficulty: m['difficulty'] ?? 'beginner',
      category: m['category'] ?? m['exerciseType'] ?? 'strength',
      media: embeddedMedia,
      defaultSets: m['defaultSets'] ?? 3,
      defaultReps: m['defaultReps'],
      defaultSeconds: m['defaultSeconds'],
      restSeconds: m['restSeconds'] ?? 60,
      tags: List<String>.from(m['tags'] ?? m['keywords'] ?? []),
      isFeatured: m['isFeatured'] ?? false,
      metValue: (m['metValue'] as num?)?.toDouble(),
      source: m['source'] ?? 'unknown',
      sourceExerciseId: m['sourceExerciseId'],
      mediaItems: mediaItems,
    );
  }
}

/// A custom workout built by a user by picking exercises from the library
class CustomWorkout {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final List<CustomWorkoutExercise> exercises;
  final List<String> targetMuscles;
  final List<String> selectedEquipment;
  final List<String> targetBodyParts;
  final int estimatedMinutes;
  final int exerciseCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastPerformed;
  final bool importedFromShare;
  final bool importedFromCommunity;
  final String? sourceShareId;
  final String? sourceCommunityWorkoutId;

  const CustomWorkout({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.exercises,
    required this.targetMuscles,
    this.selectedEquipment = const [],
    this.targetBodyParts = const [],
    required this.estimatedMinutes,
    int? exerciseCount,
    required this.createdAt,
    this.updatedAt,
    this.lastPerformed,
    this.importedFromShare = false,
    this.importedFromCommunity = false,
    this.sourceShareId,
    this.sourceCommunityWorkoutId,
  }) : exerciseCount = exerciseCount ?? exercises.length;

  bool get canPublishToCommunity =>
      !importedFromShare && !importedFromCommunity;

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'name': name,
    'description': description,
    'exercises': exercises.map((e) => e.toMap()).toList(),
    'targetMuscles': targetMuscles,
    'selectedEquipment': selectedEquipment,
    'targetBodyParts': targetBodyParts,
    'estimatedMinutes': estimatedMinutes,
    'exerciseCount': exerciseCount,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'lastPerformed': lastPerformed?.toIso8601String(),
    'importedFromShare': importedFromShare,
    'importedFromCommunity': importedFromCommunity,
    'sourceShareId': sourceShareId,
    'sourceCommunityWorkoutId': sourceCommunityWorkoutId,
  };

  factory CustomWorkout.fromMap(Map<String, dynamic> m) => CustomWorkout(
    id: m['id'],
    userId: m['userId'],
    name: m['name'],
    description: m['description'],
    exercises: (m['exercises'] as List)
        .map((e) => CustomWorkoutExercise.fromMap(e))
        .toList(),
    targetMuscles: List<String>.from(m['targetMuscles'] ?? []),
    selectedEquipment: List<String>.from(m['selectedEquipment'] ?? []),
    targetBodyParts: List<String>.from(m['targetBodyParts'] ?? []),
    estimatedMinutes: m['estimatedMinutes'] ?? 30,
    exerciseCount: m['exerciseCount'],
    createdAt: DateTime.parse(m['createdAt']),
    updatedAt: m['updatedAt'] != null
        ? DateTime.parse(m['updatedAt'])
        : null,
    lastPerformed: m['lastPerformed'] != null
        ? DateTime.parse(m['lastPerformed'])
        : null,
    importedFromShare: m['importedFromShare'] ?? false,
    importedFromCommunity: m['importedFromCommunity'] ?? false,
    sourceShareId: m['sourceShareId'],
    sourceCommunityWorkoutId: m['sourceCommunityWorkoutId'],
  );
}

class CustomWorkoutExercise {
  final String exerciseId;
  final String exerciseName;   // Denormalized for display without fetching
  final String? thumbnailUrl;  // Denormalized
  final int sets;
  final int? reps;
  final int? seconds;
  final double? weightKg;
  final int restSeconds;
  final String? notes;
  final int order;
  final List<String> bodyParts;
  final List<String> equipment;

  const CustomWorkoutExercise({
    required this.exerciseId,
    required this.exerciseName,
    this.thumbnailUrl,
    required this.sets,
    this.reps,
    this.seconds,
    this.weightKg,
    this.restSeconds = 60,
    this.notes,
    required this.order,
    this.bodyParts = const [],
    this.equipment = const [],
  });

  CustomWorkoutExercise copyWith({
    int? sets,
    int? reps,
    int? seconds,
    double? weightKg,
    int? restSeconds,
    String? notes,
    int? order,
    List<String>? bodyParts,
    List<String>? equipment,
  }) =>
      CustomWorkoutExercise(
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        thumbnailUrl: thumbnailUrl,
        sets: sets ?? this.sets,
        reps: reps ?? this.reps,
        seconds: seconds ?? this.seconds,
        weightKg: weightKg ?? this.weightKg,
        restSeconds: restSeconds ?? this.restSeconds,
        notes: notes ?? this.notes,
        order: order ?? this.order,
        bodyParts: bodyParts ?? this.bodyParts,
        equipment: equipment ?? this.equipment,
      );

  Map<String, dynamic> toMap() => {
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'thumbnailUrl': thumbnailUrl,
    'sets': sets,
    'reps': reps,
    'seconds': seconds,
    'weightKg': weightKg,
    'restSeconds': restSeconds,
    'notes': notes,
    'order': order,
    'bodyParts': bodyParts,
    'equipment': equipment,
  };

  factory CustomWorkoutExercise.fromMap(Map<String, dynamic> m) =>
      CustomWorkoutExercise(
        exerciseId: m['exerciseId'],
        exerciseName: m['exerciseName'],
        thumbnailUrl: m['thumbnailUrl'],
        sets: m['sets'] ?? 3,
        reps: m['reps'],
        seconds: m['seconds'],
        weightKg: (m['weightKg'] as num?)?.toDouble(),
        restSeconds: m['restSeconds'] ?? 60,
        notes: m['notes'],
        order: m['order'] ?? 0,
        bodyParts: List<String>.from(m['bodyParts'] ?? []),
        equipment: List<String>.from(m['equipment'] ?? []),
      );
}

class CustomWorkoutPreset {
  final String id;
  final String userId;
  final String workoutId;
  final String name;
  final String mode; // 'standard' | 'circuit'
  final bool warmupEnabled;
  final bool shuffleEnabled;
  final int rounds;
  final int getReadySeconds;
  final int restBetweenSets;
  final int restBetweenExercises;
  final int restBetweenRounds;
  final int estimatedMinutes;
  final int estimatedCalories;
  final List<CustomWorkoutPresetExercise> exercises;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastUsedAt;

  const CustomWorkoutPreset({
    required this.id,
    required this.userId,
    required this.workoutId,
    required this.name,
    required this.mode,
    required this.warmupEnabled,
    required this.shuffleEnabled,
    required this.rounds,
    this.getReadySeconds = 5,
    required this.restBetweenSets,
    required this.restBetweenExercises,
    this.restBetweenRounds = 60,
    required this.estimatedMinutes,
    required this.estimatedCalories,
    required this.exercises,
    required this.createdAt,
    this.updatedAt,
    this.lastUsedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'workoutId': workoutId,
        'name': name,
        'mode': mode,
        'warmupEnabled': warmupEnabled,
        'shuffleEnabled': shuffleEnabled,
        'rounds': rounds,
        'getReadySeconds': getReadySeconds,
        'restBetweenSets': restBetweenSets,
        'restBetweenExercises': restBetweenExercises,
        'restBetweenRounds': restBetweenRounds,
        'estimatedMinutes': estimatedMinutes,
        'estimatedCalories': estimatedCalories,
        'exercises': exercises.map((e) => e.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'lastUsedAt': lastUsedAt?.toIso8601String(),
      };

  factory CustomWorkoutPreset.fromMap(Map<String, dynamic> m) =>
      CustomWorkoutPreset(
        id: m['id'],
        userId: m['userId'],
        workoutId: m['workoutId'],
        name: m['name'],
        mode: m['mode'] ?? 'standard',
        warmupEnabled: m['warmupEnabled'] ?? true,
        shuffleEnabled: m['shuffleEnabled'] ?? false,
        rounds: m['rounds'] ?? 3,
        getReadySeconds: m['getReadySeconds'] ?? 5,
        restBetweenSets: m['restBetweenSets'] ?? 60,
        restBetweenExercises: m['restBetweenExercises'] ?? 60,
        restBetweenRounds: m['restBetweenRounds'] ?? 60,
        estimatedMinutes: m['estimatedMinutes'] ?? 30,
        estimatedCalories: m['estimatedCalories'] ?? 0,
        exercises: (m['exercises'] as List? ?? [])
            .map((e) => CustomWorkoutPresetExercise.fromMap(e))
            .toList(),
        createdAt: DateTime.parse(m['createdAt']),
        updatedAt:
            m['updatedAt'] != null ? DateTime.parse(m['updatedAt']) : null,
        lastUsedAt:
            m['lastUsedAt'] != null ? DateTime.parse(m['lastUsedAt']) : null,
      );
}

class CustomWorkoutPresetExercise {
  final String exerciseId;
  final int order;
  final int sets;
  final int? reps;
  final int? seconds;
  final int restBetweenSets;
  final int restBetweenExercises;

  const CustomWorkoutPresetExercise({
    required this.exerciseId,
    required this.order,
    required this.sets,
    this.reps,
    this.seconds,
    required this.restBetweenSets,
    required this.restBetweenExercises,
  });

  Map<String, dynamic> toMap() => {
        'exerciseId': exerciseId,
        'order': order,
        'sets': sets,
        'reps': reps,
        'seconds': seconds,
        'restBetweenSets': restBetweenSets,
        'restBetweenExercises': restBetweenExercises,
      };

  factory CustomWorkoutPresetExercise.fromMap(Map<String, dynamic> m) =>
      CustomWorkoutPresetExercise(
        exerciseId: m['exerciseId'],
        order: m['order'] ?? 0,
        sets: m['sets'] ?? 3,
        reps: m['reps'],
        seconds: m['seconds'],
        restBetweenSets: m['restBetweenSets'] ?? 60,
        restBetweenExercises: m['restBetweenExercises'] ?? 60,
      );
}
