import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:metabolicapp/features/food_diary/domain/entities/food_entry.dart';
import '../../services/food_database_service.dart';

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
      : super(NutritionLogState(date: DateUtils.dateOnly(DateTime.now()))) {
    // Initial load
    _loadSettings();
    loadDate(state.date);
  }

  Future<void> _loadSettings() async {
    final carbs = await FoodDatabaseService.getUserSetting('carbs_target');
    final protein = await FoodDatabaseService.getUserSetting('protein_target');
    final fat = await FoodDatabaseService.getUserSetting('fat_target');

    if (carbs != null || protein != null || fat != null) {
      state = state.copyWith(
        carbsTarget: carbs != null ? double.tryParse(carbs) : null,
        proteinTarget: protein != null ? double.tryParse(protein) : null,
        fatTarget: fat != null ? double.tryParse(fat) : null,
      );
    }
  }

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
    // Persist
    FoodDatabaseService.saveUserSetting('carbs_target', carbs.toString());
    FoodDatabaseService.saveUserSetting('protein_target', protein.toString());
    FoodDatabaseService.saveUserSetting('fat_target', fat.toString());
  }

  Future<void> loadDate(DateTime date) async {
    final cleanDate = DateUtils.dateOnly(date);
    // You might want to set a loading state here if the UI supports it
    final entries = await FoodDatabaseService.getDiaryEntries(cleanDate);
    state = state.copyWith(date: cleanDate, entries: entries);
  }

  Future<void> addEntry(FoodEntry entry) async {
    await FoodDatabaseService.addDiaryEntry(entry);
    // Reload to ensure sync and sort order
    await loadDate(state.date);
  }

  Future<void> removeEntry(String id) async {
    await FoodDatabaseService.deleteDiaryEntry(id);
    await loadDate(state.date);
  }

  Future<void> clearDay() async {
    // Ideally delete all for day, but for now just clear local state 
    // or implement a deleteForDay in service if needed.
    // For this MVP, we iterate delete or just set empty if persistence of clearing isn't critical yet.
    // Let's implement correct deletion:
    for (var e in state.entries) {
      await FoodDatabaseService.deleteDiaryEntry(e.id);
    }
    await loadDate(state.date);
  }
}

final nutritionLogProvider =
StateNotifierProvider<NutritionLogNotifier, NutritionLogState>((ref) {
  return NutritionLogNotifier();
});
