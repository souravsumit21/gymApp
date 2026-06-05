import 'package:equatable/equatable.dart';

// ─────────────────────────────────────────────
// USER MODEL
// ─────────────────────────────────────────────
class UserProfile extends Equatable {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final int? age;
  final String? gender;       // 'male' | 'female' | 'other'
  final double? weightKg;
  final double? heightCm;
  final String fitnessLevel;  // 'beginner' | 'intermediate' | 'advanced'
  final List<String> equipment;
  final List<String> goals;   // 'weight_loss' | 'muscle_gain' | 'endurance' | 'flexibility'
  final String? primaryGoal;
  final int? weeklyWorkoutDays;
  final int? preferredWorkoutMinutes;
  final String? limitations;
  final String? trainingLocation;
  final String trainingType;
  final bool isPremium;
  final DateTime createdAt;
  final bool onboardingComplete;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.age,
    this.gender,
    this.weightKg,
    this.heightCm,
    this.fitnessLevel = 'beginner',
    this.equipment = const [],
    this.goals = const [],
    this.primaryGoal,
    this.weeklyWorkoutDays,
    this.preferredWorkoutMinutes,
    this.limitations,
    this.trainingLocation,
    this.trainingType = 'mixed',
    this.isPremium = false,
    required this.createdAt,
    this.onboardingComplete = false,
  });

  double? get bmi {
    if (weightKg == null || heightCm == null) return null;
    final hm = heightCm! / 100;
    return weightKg! / (hm * hm);
  }

  UserProfile copyWith({
    String? displayName,
    String? photoUrl,
    int? age,
    String? gender,
    double? weightKg,
    double? heightCm,
    String? fitnessLevel,
    List<String>? equipment,
    List<String>? goals,
    String? primaryGoal,
    int? weeklyWorkoutDays,
    int? preferredWorkoutMinutes,
    String? limitations,
    String? trainingLocation,
    String? trainingType,
    bool? isPremium,
    bool? onboardingComplete,
  }) {
    return UserProfile(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      equipment: equipment ?? this.equipment,
      goals: goals ?? this.goals,
      primaryGoal: primaryGoal ?? this.primaryGoal,
      weeklyWorkoutDays: weeklyWorkoutDays ?? this.weeklyWorkoutDays,
      preferredWorkoutMinutes:
          preferredWorkoutMinutes ?? this.preferredWorkoutMinutes,
      limitations: limitations ?? this.limitations,
      trainingLocation: trainingLocation ?? this.trainingLocation,
      trainingType: trainingType ?? this.trainingType,
      isPremium: isPremium ?? this.isPremium,
      createdAt: createdAt,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'age': age,
    'gender': gender,
    'weightKg': weightKg,
    'heightCm': heightCm,
    'fitnessLevel': fitnessLevel,
    'equipment': equipment,
    'goals': goals,
    'primaryGoal': primaryGoal,
    'weeklyWorkoutDays': weeklyWorkoutDays,
    'preferredWorkoutMinutes': preferredWorkoutMinutes,
    'limitations': limitations,
    'trainingLocation': trainingLocation,
    'trainingType': trainingType,
    'isPremium': isPremium,
    'createdAt': createdAt.toIso8601String(),
    'onboardingComplete': onboardingComplete,
  };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    uid: map['uid'],
    email: map['email'],
    displayName: map['displayName'],
    photoUrl: map['photoUrl'],
    age: map['age'],
    gender: map['gender'],
    weightKg: (map['weightKg'] as num?)?.toDouble(),
    heightCm: (map['heightCm'] as num?)?.toDouble(),
    fitnessLevel: map['fitnessLevel'] ?? 'beginner',
    equipment: List<String>.from(map['equipment'] ?? []),
    goals: List<String>.from(map['goals'] ?? []),
    primaryGoal: map['primaryGoal'],
    weeklyWorkoutDays: map['weeklyWorkoutDays'],
    preferredWorkoutMinutes: map['preferredWorkoutMinutes'],
    limitations: map['limitations'],
    trainingLocation: map['trainingLocation'],
    trainingType: map['trainingType'] ?? 'mixed',
    isPremium: map['isPremium'] ?? false,
    createdAt: DateTime.parse(map['createdAt']),
    onboardingComplete: map['onboardingComplete'] ?? false,
  );

  @override
  List<Object?> get props => [
        uid,
        email,
        displayName,
        isPremium,
        onboardingComplete,
        primaryGoal,
        weeklyWorkoutDays,
        preferredWorkoutMinutes,
        limitations,
        trainingLocation,
        trainingType,
      ];
}

// ─────────────────────────────────────────────
// EQUIPMENT
// ─────────────────────────────────────────────
class Equipment extends Equatable {
  final String id;
  final String name;
  final String icon;       // emoji or asset path
  final String category;  // 'bodyweight' | 'resistance' | 'cardio' | 'weights'

  const Equipment({
    required this.id,
    required this.name,
    required this.icon,
    required this.category,
  });

  @override
  List<Object?> get props => [id];
}

final List<Equipment> allEquipment = [
  // Bodyweight (always available)
  const Equipment(id: 'none', name: 'No Equipment', icon: '🙌', category: 'bodyweight'),
  const Equipment(id: 'pull_up_bar', name: 'Pull-Up Bar', icon: '🔩', category: 'bodyweight'),
  const Equipment(id: 'dip_bars', name: 'Dip Bars', icon: '🏗️', category: 'bodyweight'),
  const Equipment(id: 'gymnastic_rings', name: 'Gymnastic Rings', icon: '⭕', category: 'bodyweight'),
  // Resistance
  const Equipment(id: 'resistance_bands', name: 'Resistance Bands', icon: '🔗', category: 'resistance'),
  const Equipment(id: 'trx', name: 'TRX / Suspension', icon: '🪢', category: 'resistance'),
  // Weights
  const Equipment(id: 'dumbbells', name: 'Dumbbells', icon: '🏋️', category: 'weights'),
  const Equipment(id: 'barbell', name: 'Barbell', icon: '🏋️‍♂️', category: 'weights'),
  const Equipment(id: 'kettlebell', name: 'Kettlebell', icon: '⚫', category: 'weights'),
  const Equipment(id: 'weight_bench', name: 'Bench', icon: '🛋️', category: 'weights'),
  // Cardio
  const Equipment(id: 'jump_rope', name: 'Jump Rope', icon: '🪢', category: 'cardio'),
  const Equipment(id: 'box', name: 'Plyo Box', icon: '📦', category: 'cardio'),
  const Equipment(id: 'treadmill', name: 'Treadmill', icon: '🏃', category: 'cardio'),
  const Equipment(id: 'stationary_bike', name: 'Stationary Bike', icon: '🚴', category: 'cardio'),
  const Equipment(id: 'yoga_mat', name: 'Yoga / Exercise Mat', icon: '🟩', category: 'bodyweight'),
];

// ─────────────────────────────────────────────
// EXERCISE MODEL
// ─────────────────────────────────────────────
class Exercise extends Equatable {
  final String id;
  final String name;
  final String description;
  final List<String> muscleGroups;  // primary muscles
  final List<String> requiredEquipment;
  final String difficulty;          // 'beginner' | 'intermediate' | 'advanced'
  final String category;            // 'strength' | 'cardio' | 'flexibility' | 'core'
  final int? defaultSets;
  final int? defaultReps;
  final int? defaultSeconds;
  final String? videoUrl;
  final String? imageUrl;
  final String? instructions;

  const Exercise({
    required this.id,
    required this.name,
    required this.description,
    required this.muscleGroups,
    required this.requiredEquipment,
    required this.difficulty,
    required this.category,
    this.defaultSets,
    this.defaultReps,
    this.defaultSeconds,
    this.videoUrl,
    this.imageUrl,
    this.instructions,
  });

  bool get isTimeBased => defaultSeconds != null;

  @override
  List<Object?> get props => [id];
}

// ─────────────────────────────────────────────
// WORKOUT PLAN
// ─────────────────────────────────────────────
enum PlanType { bodyPart, weeklySchedule }

class WorkoutSet extends Equatable {
  final String exerciseId;
  final int sets;
  final int? reps;
  final int? seconds;
  final int restSeconds;
  final String? notes;

  const WorkoutSet({
    required this.exerciseId,
    required this.sets,
    this.reps,
    this.seconds,
    this.restSeconds = 60,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
    'exerciseId': exerciseId,
    'sets': sets,
    'reps': reps,
    'seconds': seconds,
    'restSeconds': restSeconds,
    'notes': notes,
  };

  factory WorkoutSet.fromMap(Map<String, dynamic> m) => WorkoutSet(
    exerciseId: m['exerciseId'],
    sets: m['sets'],
    reps: m['reps'],
    seconds: m['seconds'],
    restSeconds: m['restSeconds'] ?? 60,
    notes: m['notes'],
  );

  @override
  List<Object?> get props => [exerciseId, sets, reps, seconds];
}

class WorkoutDay extends Equatable {
  final String id;
  final String name;    // e.g. "Push Day", "Monday", "Chest & Triceps"
  final String? targetBodyPart;
  final List<WorkoutSet> exercises;
  final int estimatedMinutes;

  const WorkoutDay({
    required this.id,
    required this.name,
    this.targetBodyPart,
    required this.exercises,
    required this.estimatedMinutes,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'targetBodyPart': targetBodyPart,
    'exercises': exercises.map((e) => e.toMap()).toList(),
    'estimatedMinutes': estimatedMinutes,
  };

  factory WorkoutDay.fromMap(Map<String, dynamic> m) => WorkoutDay(
    id: m['id'],
    name: m['name'],
    targetBodyPart: m['targetBodyPart'],
    exercises: (m['exercises'] as List).map((e) => WorkoutSet.fromMap(e)).toList(),
    estimatedMinutes: m['estimatedMinutes'] ?? 30,
  );

  @override
  List<Object?> get props => [id];
}

class WorkoutPlan extends Equatable {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final PlanType type;
  final List<WorkoutDay> days;
  final List<String> targetGoals;
  final String difficulty;
  final bool isAiGenerated;
  final DateTime createdAt;
  final DateTime? lastModified;

  const WorkoutPlan({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.type,
    required this.days,
    required this.targetGoals,
    required this.difficulty,
    this.isAiGenerated = false,
    required this.createdAt,
    this.lastModified,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'title': title,
    'description': description,
    'type': type.name,
    'days': days.map((d) => d.toMap()).toList(),
    'targetGoals': targetGoals,
    'difficulty': difficulty,
    'isAiGenerated': isAiGenerated,
    'createdAt': createdAt.toIso8601String(),
    'lastModified': lastModified?.toIso8601String(),
  };

  factory WorkoutPlan.fromMap(Map<String, dynamic> m) => WorkoutPlan(
    id: m['id'],
    userId: m['userId'],
    title: m['title'],
    description: m['description'],
    type: PlanType.values.firstWhere((e) => e.name == m['type']),
    days: (m['days'] as List).map((d) => WorkoutDay.fromMap(d)).toList(),
    targetGoals: List<String>.from(m['targetGoals'] ?? []),
    difficulty: m['difficulty'],
    isAiGenerated: m['isAiGenerated'] ?? false,
    createdAt: DateTime.parse(m['createdAt']),
    lastModified: m['lastModified'] != null ? DateTime.parse(m['lastModified']) : null,
  );

  @override
  List<Object?> get props => [id];
}

// ─────────────────────────────────────────────
// WORKOUT SESSION (Progress Tracking)
// ─────────────────────────────────────────────
class WorkoutSession extends Equatable {
  final String id;
  final String userId;
  final String planId;
  final String dayId;
  final String dayName;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationMinutes;
  final List<String> completedExerciseIds;
  final int totalSets;
  final double? totalVolumeKg;
  final int caloriesBurned;
  final String? notes;
  final Map<String, dynamic>? weightLog;
  final String? workoutMode;
  final String? sourceType;
  final int mood;   // 1–5
  final int energy; // 1–5

  const WorkoutSession({
    required this.id,
    required this.userId,
    required this.planId,
    required this.dayId,
    required this.dayName,
    required this.startTime,
    this.endTime,
    required this.durationMinutes,
    required this.completedExerciseIds,
    required this.totalSets,
    this.totalVolumeKg,
    this.caloriesBurned = 0,
    this.notes,
    this.weightLog,
    this.workoutMode,
    this.sourceType,
    this.mood = 3,
    this.energy = 3,
  });

  bool get isCompleted => endTime != null;

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'planId': planId,
    'dayId': dayId,
    'dayName': dayName,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'durationMinutes': durationMinutes,
    'completedExerciseIds': completedExerciseIds,
    'totalSets': totalSets,
    'totalVolumeKg': totalVolumeKg,
    'caloriesBurned': caloriesBurned,
    'notes': notes,
    'weightLog': weightLog,
    'workoutMode': workoutMode,
    'sourceType': sourceType,
    'mood': mood,
    'energy': energy,
  };

  factory WorkoutSession.fromMap(Map<String, dynamic> m) => WorkoutSession(
    id: m['id'],
    userId: m['userId'],
    planId: m['planId'],
    dayId: m['dayId'],
    dayName: m['dayName'],
    startTime: DateTime.parse(m['startTime']),
    endTime: m['endTime'] != null ? DateTime.parse(m['endTime']) : null,
    durationMinutes: m['durationMinutes'] ?? 0,
    completedExerciseIds: List<String>.from(m['completedExerciseIds'] ?? []),
    totalSets: m['totalSets'] ?? 0,
    totalVolumeKg: (m['totalVolumeKg'] as num?)?.toDouble(),
    caloriesBurned: m['caloriesBurned'] ?? 0,
    notes: m['notes'],
    weightLog: m['weightLog'] != null
        ? Map<String, dynamic>.from(m['weightLog'])
        : null,
    workoutMode: m['workoutMode'],
    sourceType: m['sourceType'],
    mood: m['mood'] ?? 3,
    energy: m['energy'] ?? 3,
  );

  @override
  List<Object?> get props => [id];
}
