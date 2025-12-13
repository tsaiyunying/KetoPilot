import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  DailyLogNotifier() : super(DailyLogState(date: DateUtils.dateOnly(DateTime.now())));

  void setBiomarkers({
    required double glucoseMgDl,
    required double bhbMmol,
    double? weightKg,
    DateTime? date,
  }) {
    state = state.copyWith(
      date: DateUtils.dateOnly(date ?? DateTime.now()),
      glucoseMgDl: glucoseMgDl,
      bhbMmol: bhbMmol,
      weightKg: weightKg,
      clearWeight: weightKg == null,
    );
  }

  void clearBiomarkers() {
    state = state.copyWith(glucoseMgDl: 0, bhbMmol: 0, clearWeight: true);
  }
}

final dailyLogProvider =
    StateNotifierProvider<DailyLogNotifier, DailyLogState>((ref) {
  return DailyLogNotifier();
});


