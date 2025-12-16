import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/food_database_service.dart';

@immutable
class DailyLogState {
  final DateTime date;

  // Biomarkers
  final double glucoseMgDl;
  final double bhbMmol;
  final double? weightKg;

  const DailyLogState({
    required this.date,
    this.glucoseMgDl = 0,
    this.bhbMmol = 0,
    this.weightKg,
  });

  double get gki {
    // GKI = glucose (mmol/L) / ketones (mmol/L)
    if (bhbMmol <= 0) return 0;
    final glucoseMmol = glucoseMgDl / 18.0;
    return glucoseMmol / bhbMmol;
  }

  DailyLogState copyWith({
    DateTime? date,
    double? glucoseMgDl,
    double? bhbMmol,
    double? weightKg,
    bool clearWeight = false,
  }) {
    return DailyLogState(
      date: date ?? this.date,
      glucoseMgDl: glucoseMgDl ?? this.glucoseMgDl,
      bhbMmol: bhbMmol ?? this.bhbMmol,
      weightKg: clearWeight ? null : (weightKg ?? this.weightKg),
    );
  }
}

class DailyLogNotifier extends StateNotifier<DailyLogState> {
  DailyLogNotifier() : super(DailyLogState(date: DateUtils.dateOnly(DateTime.now()))) {
    loadDate(state.date);
  }

  Future<void> loadDate(DateTime date) async {
    final cleanDate = DateUtils.dateOnly(date);
    final data = await FoodDatabaseService.getBiomarkers(cleanDate);
    
    if (data != null) {
      state = state.copyWith(
        date: cleanDate,
        glucoseMgDl: data['glucose'] as double,
        bhbMmol: data['bhb'] as double,
        weightKg: data['weight'] as double?,
        clearWeight: data['weight'] == null,
      );
    } else {
      // Reset if no data found for this date
      state = DailyLogState(date: cleanDate);
    }
  }

  void setBiomarkers({
    required double glucoseMgDl,
    required double bhbMmol,
    double? weightKg,
    DateTime? date,
  }) {
    final cleanDate = DateUtils.dateOnly(date ?? state.date);
    
    // Optimistic Update
    state = state.copyWith(
      date: cleanDate,
      glucoseMgDl: glucoseMgDl,
      bhbMmol: bhbMmol,
      weightKg: weightKg,
      clearWeight: weightKg == null,
    );
    
    // Persist
    FoodDatabaseService.saveBiomarkers(
      date: cleanDate,
      glucose: glucoseMgDl,
      bhb: bhbMmol,
      weight: weightKg,
    );
  }

  void clearBiomarkers() {
    state = state.copyWith(glucoseMgDl: 0, bhbMmol: 0, clearWeight: true);
    // Ideally delete from DB, or save as 0/null
    FoodDatabaseService.saveBiomarkers(
      date: state.date,
      glucose: 0,
      bhb: 0,
      weight: null,
    );
  }
}

final dailyLogProvider =
    StateNotifierProvider<DailyLogNotifier, DailyLogState>((ref) {
  return DailyLogNotifier();
});


