import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:metabolicapp/features/food_diary/domain/entities/food_entry.dart';

@immutable
class NutritionLogState {
  final DateTime date;

  // targets (user-defined)
  final double carbsTarget;
  final double proteinTarget;
  final double fatTarget;

  // entries for the day
  final List<FoodEntry> entries;

  const NutritionLogState({
    required this.date,
    this.carbsTarget = 20,
    this.proteinTarget = 100,
    this.fatTarget = 150,
    this.entries = const [],
  });

  // totals (computed)
  double get carbsConsumed =>
      entries.fold(0, (s, e) => s + e.macros.netCarbs); // net carbs
  double get proteinConsumed =>
      entries.fold(0, (s, e) => s + e.macros.protein);
  double get fatConsumed => entries.fold(0, (s, e) => s + e.macros.fat);

  double get carbsPct =>
      carbsTarget <= 0 ? 0 : (carbsConsumed / carbsTarget).clamp(0, 1);
  double get proteinPct =>
      proteinTarget <= 0 ? 0 : (proteinConsumed / proteinTarget).clamp(0, 1);
  double get fatPct =>
      fatTarget <= 0 ? 0 : (fatConsumed / fatTarget).clamp(0, 1);

  NutritionLogState copyWith({
    DateTime? date,
    double? carbsTarget,
    double? proteinTarget,
    double? fatTarget,
    List<FoodEntry>? entries,
  }) {
    return NutritionLogState(
      date: date ?? this.date,
      carbsTarget: carbsTarget ?? this.carbsTarget,
      proteinTarget: proteinTarget ?? this.proteinTarget,
      fatTarget: fatTarget ?? this.fatTarget,
      entries: entries ?? this.entries,
    );
  }
}

class NutritionLogNotifier extends StateNotifier<NutritionLogState> {
  NutritionLogNotifier()
      : super(NutritionLogState(date: DateUtils.dateOnly(DateTime.now())));

  void setTargets({
    required double carbs,
    required double protein,
    required double fat,
  }) {
    state = state.copyWith(
      carbsTarget: carbs,
      proteinTarget: protein,
      fatTarget: fat,
    );
  }

  void addEntry(FoodEntry entry) {
    final next = [...state.entries, entry]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    state = state.copyWith(entries: next);
  }

  void removeEntry(String id) {
    state = state.copyWith(
      entries: state.entries.where((e) => e.id != id).toList(),
    );
  }

  void clearDay() {
    state = state.copyWith(entries: const []);
  }
}

final nutritionLogProvider =
StateNotifierProvider<NutritionLogNotifier, NutritionLogState>((ref) {
  return NutritionLogNotifier();
});
