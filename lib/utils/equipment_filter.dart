import '../models/exercise_media.dart';
import 'muscle_filter.dart';

/// Bodyweight exercises are stored as `requiredEquipment: ['none']`.
const kBodyweightEquipmentId = 'none';

bool isBodyweightEquipment(List<String> requiredEquipment) {
  return requiredEquipment.isNotEmpty &&
      requiredEquipment.every((eq) => eq == kBodyweightEquipmentId);
}

/// True when [exerciseEquipment] is associated with a single [equipmentId].
bool exerciseUsesEquipment(
  List<String> exerciseEquipment,
  String equipmentId,
) {
  if (equipmentId == kBodyweightEquipmentId) {
    return isBodyweightEquipment(exerciseEquipment);
  }
  return exerciseEquipment.contains(equipmentId);
}

/// Counts exercises doable with only [equipmentId] selected (matches library filter).
Map<String, int> equipmentExerciseCounts(
  Iterable<LibraryExercise> exercises,
  Iterable<String> equipmentIds,
) {
  final list = exercises.toList();
  return {
    for (final equipmentId in equipmentIds)
      equipmentId: list
          .where(
            (e) => exerciseMatchesSelectedEquipment(
              e.requiredEquipment,
              {equipmentId},
            ),
          )
          .length,
  };
}

/// True when an exercise targets [bodyPartId], using normalized muscle IDs.
bool exerciseTargetsBodyPart({
  required List<String> muscleGroups,
  required List<String> secondaryMuscles,
  required String bodyPartId,
  bool primaryOnly = false,
}) {
  return exerciseMatchesBodyPart(
    muscleGroups,
    secondaryMuscles,
    bodyPartId,
    primaryOnly: primaryOnly,
  );
}

/// Counts exercises per body part, optionally filtered by selected equipment.
/// Body-step cards use [primaryOnly] so counts match primary `muscleGroups`.
Map<String, int> bodyPartExerciseCounts(
  Iterable<LibraryExercise> exercises,
  Iterable<String> bodyPartIds, {
  Iterable<String>? selectedEquipment,
  bool primaryOnly = true,
}) {
  if (selectedEquipment == null || selectedEquipment.isEmpty) {
    return {for (final bodyPartId in bodyPartIds) bodyPartId: 0};
  }

  return {
    for (final bodyPartId in bodyPartIds)
      bodyPartId: exercises.where((e) {
        if (!exerciseMatchesSelectedEquipment(
          e.requiredEquipment,
          selectedEquipment,
        )) {
          return false;
        }
        return exerciseTargetsBodyPart(
          muscleGroups: e.muscleGroups,
          secondaryMuscles: e.secondaryMuscles,
          bodyPartId: bodyPartId,
          primaryOnly: primaryOnly,
        );
      }).length,
  };
}

/// Returns true when [exerciseEquipment] is satisfied by [selectedEquipment].
///
/// Bodyweight exercises only appear when `none` is selected.
/// Equipped exercises require every listed item to be selected.
bool exerciseMatchesSelectedEquipment(
  List<String> exerciseEquipment,
  Iterable<String> selectedEquipment,
) {
  if (selectedEquipment.isEmpty || exerciseEquipment.isEmpty) return false;

  final selected = selectedEquipment.toSet();
  if (isBodyweightEquipment(exerciseEquipment)) {
    return selected.contains(kBodyweightEquipmentId);
  }

  return exerciseEquipment.every(selected.contains);
}
