import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/models.dart';

const _uuid = Uuid();

class WorkoutService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── CRUD: Workout Plans ──────────────────────────────────
  Future<List<WorkoutPlan>> getPlans(String userId) async {
    final snap = await _db
        .collection('users')
        .doc(userId)
        .collection('plans')
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => WorkoutPlan.fromMap(d.data())).toList();
  }

  Stream<List<WorkoutPlan>> watchPlans(String userId) {
    if (userId.isEmpty) return Stream.value(const []);
    return _db
        .collection('users')
        .doc(userId)
        .collection('plans')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => WorkoutPlan.fromMap(d.data())).toList());
  }

  Future<void> savePlan(WorkoutPlan plan) async {
    await _db
        .collection('users')
        .doc(plan.userId)
        .collection('plans')
        .doc(plan.id)
        .set(plan.toMap());
  }

  Future<void> deletePlan(String userId, String planId) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('plans')
        .doc(planId)
        .delete();
  }

  // ── CRUD: Sessions ───────────────────────────────────────
  Future<void> saveSession(WorkoutSession session) async {
    await _db
        .collection('users')
        .doc(session.userId)
        .collection('sessions')
        .doc(session.id)
        .set(session.toMap());
  }

  Stream<List<WorkoutSession>> watchSessions(String userId) {
    if (userId.isEmpty) return Stream.value(const []);
    return _db
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => WorkoutSession.fromMap(d.data())).toList());
  }

  Future<List<WorkoutSession>> getSessionsInRange(
    String userId,
    DateTime from,
    DateTime to,
  ) async {
    final snap = await _db
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .where('startTime', isGreaterThanOrEqualTo: from.toIso8601String())
        .where('startTime', isLessThanOrEqualTo: to.toIso8601String())
        .orderBy('startTime')
        .get();
    return snap.docs.map((d) => WorkoutSession.fromMap(d.data())).toList();
  }

  // ── AI Plan Generation via Claude ────────────────────────
  /// Calls Claude Sonnet to generate a structured workout plan JSON
  Future<WorkoutPlan> generateAIPlan({
    required UserProfile user,
    required PlanType type,
    required String targetDescription, // e.g. "Full body 5-day split" or "Chest and shoulders"
  }) async {
    const apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
    final prompt = _buildPlanPrompt(user, type, targetDescription);

    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': 'claude-sonnet-4-20250514',
        'max_tokens': 4096,
        'system':
            'You are an expert personal trainer. Always respond ONLY with valid JSON, '
            'no markdown, no explanation. Follow the schema exactly.',
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Claude API error: ${response.body}');
    }

    final body = jsonDecode(response.body);
    final text = (body['content'] as List)
        .firstWhere((c) => c['type'] == 'text')['text'] as String;

    final planJson = jsonDecode(text) as Map<String, dynamic>;
    return _parsePlanFromAI(planJson, user.uid, type);
  }

  String _buildPlanPrompt(
    UserProfile user,
    PlanType type,
    String targetDescription,
  ) {
    final equipment = user.equipment.join(', ');
    final goals = user.goals.join(', ');
    final limitations = user.limitations?.trim().isNotEmpty == true
        ? user.limitations
        : 'none';
    final planTypeStr = type == PlanType.bodyPart ? 'body-part split' : 'weekly schedule';

    return '''
Create a $planTypeStr home workout plan for:
- Age: ${user.age}, Gender: ${user.gender}, Fitness level: ${user.fitnessLevel}
- Weight: ${user.weightKg}kg, Height: ${user.heightCm}cm
- Primary goal: ${user.primaryGoal ?? 'general_fitness'}
- Available equipment: $equipment
- Goals: $goals
- Training location: ${user.trainingLocation ?? 'home'}
- Preferred training type: ${user.trainingType}
- Weekly workout days: ${user.weeklyWorkoutDays ?? 3}
- Preferred workout length: ${user.preferredWorkoutMinutes ?? 30} minutes
- Limitations or movements to avoid: $limitations
- Plan description: $targetDescription

Return ONLY this JSON schema:
{
  "title": "Plan title",
  "description": "Brief description",
  "days": [
    {
      "name": "Day name",
      "targetBodyPart": "primary muscle group",
      "estimatedMinutes": 35,
      "exercises": [
        {
          "exerciseId": "snake_case_name",
          "name": "Exercise name",
          "sets": 3,
          "reps": 12,
          "seconds": null,
          "restSeconds": 60,
          "muscleGroups": ["chest", "triceps"],
          "instructions": "How to perform"
        }
      ]
    }
  ]
}
Only include exercises doable with the user's equipment. Include 4-6 exercises per day.
''';
  }

  WorkoutPlan _parsePlanFromAI(
    Map<String, dynamic> json,
    String userId,
    PlanType type,
  ) {
    final days = (json['days'] as List).map((d) {
      final exercises = (d['exercises'] as List).map((e) {
        return WorkoutSet(
          exerciseId: e['exerciseId'] ?? _uuid.v4(),
          sets: e['sets'] ?? 3,
          reps: e['reps'],
          seconds: e['seconds'],
          restSeconds: e['restSeconds'] ?? 60,
          notes: e['instructions'],
        );
      }).toList();

      return WorkoutDay(
        id: _uuid.v4(),
        name: d['name'],
        targetBodyPart: d['targetBodyPart'],
        exercises: exercises,
        estimatedMinutes: d['estimatedMinutes'] ?? 30,
      );
    }).toList();

    return WorkoutPlan(
      id: _uuid.v4(),
      userId: userId,
      title: json['title'],
      description: json['description'],
      type: type,
      days: days,
      targetGoals: [],
      difficulty: 'intermediate',
      isAiGenerated: true,
      createdAt: DateTime.now(),
    );
  }
}

final workoutServiceProvider = Provider<WorkoutService>((ref) => WorkoutService());

final plansStreamProvider = StreamProvider.family<List<WorkoutPlan>, String>(
  (ref, userId) => ref.watch(workoutServiceProvider).watchPlans(userId),
);

final sessionsStreamProvider = StreamProvider.family<List<WorkoutSession>, String>(
  (ref, userId) => ref.watch(workoutServiceProvider).watchSessions(userId),
);
