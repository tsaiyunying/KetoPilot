import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'daily_log_provider.dart';

@immutable
class WeeklyLogState {
  /// Always 7 entries, oldest -> newest (today is last).
  final List<DailyLogState> days;

  const WeeklyLogState({required this.days});
}

class WeeklyLogNotifier extends StateNotifier<WeeklyLogState> {
  WeeklyLogNotifier()
      : super(
          WeeklyLogState(days: _buildDefault7Days(DateTime.now())),
        );

  void upsertBiomarkersForToday({
    required double glucoseMgDl,
    required double bhbMmol,
    double? weightKg,
  }) {
    _upsertForDate(
      DateUtils.dateOnly(DateTime.now()),
      (old) => old.copyWith(
        glucoseMgDl: glucoseMgDl,
        bhbMmol: bhbMmol,
        weightKg: weightKg,
        clearWeight: weightKg == null,
      ),
    );
  }

  void clearBiomarkersForToday() {
    _upsertForDate(
      DateUtils.dateOnly(DateTime.now()),
      (old) => old.copyWith(glucoseMgDl: 0, bhbMmol: 0, clearWeight: true),
    );
  }

  void _upsertForDate(DateTime date, DailyLogState Function(DailyLogState) update) {
    final normalizedDate = DateUtils.dateOnly(date);
    final current = _ensureWindow(DateTime.now());

    final idx = current.indexWhere((d) => DateUtils.isSameDay(d.date, normalizedDate));
    if (idx == -1) {
      // If date isn't in our 7-day window, rebuild window and then try again.
      final rebuilt = _buildDefault7Days(date);
      final newIdx = rebuilt.indexWhere((d) => DateUtils.isSameDay(d.date, normalizedDate));
      if (newIdx == -1) return;
      rebuilt[newIdx] = update(rebuilt[newIdx]);
      state = WeeklyLogState(days: List.unmodifiable(rebuilt));
      return;
    }

    final next = [...current];
    next[idx] = update(next[idx]);
    state = WeeklyLogState(days: List.unmodifiable(next));
  }

  List<DailyLogState> _ensureWindow(DateTime now) {
    final today = DateUtils.dateOnly(now);
    final last = state.days.isEmpty ? null : state.days.last.date;
    if (last != null && DateUtils.isSameDay(last, today)) return state.days;

    // Shift window to end at today
    final rebuilt = _buildDefault7Days(today);
    // carry over overlapping days (by date)
    for (final existing in state.days) {
      final idx = rebuilt.indexWhere((d) => DateUtils.isSameDay(d.date, existing.date));
      if (idx != -1) rebuilt[idx] = existing;
    }
    state = WeeklyLogState(days: List.unmodifiable(rebuilt));
    return state.days;
  }

  static List<DailyLogState> _buildDefault7Days(DateTime endInclusive) {
    final end = DateUtils.dateOnly(endInclusive);
    return List.generate(7, (i) {
      final date = end.subtract(Duration(days: 6 - i));
      return DailyLogState(date: date);
    });
  }
}

final weeklyLogProvider =
    StateNotifierProvider<WeeklyLogNotifier, WeeklyLogState>((ref) {
  return WeeklyLogNotifier();
});


