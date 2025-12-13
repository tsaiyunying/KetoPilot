import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:metabolicapp/core/themes/app_theme.dart';
import 'package:metabolicapp/core/state/weekly_log_provider.dart';
import 'package:metabolicapp/core/state/daily_log_provider.dart';

class WeeklyMoleculesWidget extends ConsumerWidget {
  const WeeklyMoleculesWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(weeklyLogProvider).days;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLegend(),
          const SizedBox(height: 16),
          _buildChart(week),
          const SizedBox(height: 16),
          _buildSummary(week),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLegendItem('Glucose (mg/dL)', Colors.orange.shade400),
        _buildLegendItem('BHB (mmol/L)', Colors.amber.shade600),
        _buildLegendItem('GKI', Colors.blue.shade400),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildChart(List<DailyLogState> week) {
    return Container(
      height: 140,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: week.map((day) {
                return Expanded(child: _buildDayBar(day));
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: week.map((day) {
              return Expanded(
                child: Text(
                  _weekdayLabel(day.date),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDayBar(DailyLogState day) {
    final double glucose = day.glucoseMgDl;
    final double bhb = day.bhbMmol;
    final double gki = day.gki;

    // Normalize values for visualization
    final double normalizedGlucose = (glucose / 150 * 80).clamp(4.0, 80.0);
    final double normalizedBhb = (bhb / 3 * 60).clamp(4.0, 60.0);
    final double normalizedGki = (gki / 10 * 100).clamp(4.0, 100.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Glucose bar
          Container(
            width: 6,
            height: normalizedGlucose,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: Colors.orange.shade400,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 2),
          // BHB bar
          Container(
            width: 6,
            height: normalizedBhb,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: Colors.amber.shade600,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 2),
          // GKI bar
          Container(
            width: 6,
            height: normalizedGki,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: Colors.blue.shade400,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(List<DailyLogState> week) {
    final avgGlucose =
        week.map((d) => d.glucoseMgDl).fold(0.0, (a, b) => a + b) / 7;
    final avgBhb = week.map((d) => d.bhbMmol).fold(0.0, (a, b) => a + b) / 7;
    final avgGki = week.map((d) => d.gki).fold(0.0, (a, b) => a + b) / 7;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Weekly Averages',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const Spacer(),
              _buildHealthStatus(avgGlucose, avgBhb, avgGki),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSummaryMetric(
                  '${avgGlucose.toStringAsFixed(0)}',
                  'Glucose',
                  Colors.orange.shade400,
                ),
              ),
              Expanded(
                child: _buildSummaryMetric(
                  '${avgBhb.toStringAsFixed(1)}',
                  'BHB',
                  Colors.amber.shade600,
                ),
              ),
              Expanded(
                child: _buildSummaryMetric(
                  '${avgGki.toStringAsFixed(1)}',
                  'GKI',
                  Colors.blue.shade400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthStatus(double glucose, double bhb, double gki) {
    String status;
    Color color;

    if (glucose < 100 && bhb > 0.5 && gki < 3) {
      status = 'Optimal';
      color = Colors.green;
    } else if (glucose < 120 && bhb > 0.2 && gki < 6) {
      status = 'Good';
      color = Colors.orange;
    } else {
      status = 'Fair';
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSummaryMetric(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  String _weekdayLabel(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
      default:
        return 'Sun';
    }
  }
}
