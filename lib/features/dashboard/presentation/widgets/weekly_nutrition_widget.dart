import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:metabolicapp/core/themes/app_theme.dart';
import 'package:metabolicapp/services/food_database_service.dart';

class WeeklyNutritionWidget extends StatelessWidget {
  const WeeklyNutritionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: FoodDatabaseService.getWeeklyNutritionSummary(DateTime.now()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final weekData = snapshot.hasData ? snapshot.data! : _getEmptyWeekData();
        
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLegend(),
              const SizedBox(height: 16),
              _buildChart(weekData),
              const SizedBox(height: 16),
              _buildSummary(weekData),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLegendItem('Carbs', Colors.red.shade400),
        _buildLegendItem('Protein', Colors.blue.shade400),
        _buildLegendItem('Fat', Colors.green.shade400),
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
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildChart(List<Map<String, dynamic>> weekData) {
    return Container(
      height: 140,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weekData.map((dayData) {
                return Expanded(child: _buildDayBar(dayData));
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: weekData.map((dayData) {
              // Convert date string to day abbreviation
              final dateStr = dayData['date'] as String;
              final date = DateTime.parse(dateStr);
              final dayLabel = DateFormat('EEE').format(date).substring(0, 1);
              
              return Expanded(
                child: Text(
                  dayLabel,
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

  Widget _buildDayBar(Map<String, dynamic> dayData) {
    final double carbs = (dayData['carbs'] as num?)?.toDouble() ?? 0.0;
    final double protein = (dayData['protein'] as num?)?.toDouble() ?? 0.0;
    final double fat = (dayData['fat'] as num?)?.toDouble() ?? 0.0;
    final double total = carbs + protein + fat;

    if (total == 0) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 24,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey.shade300,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: 24,
            height: (total / 300 * 100).clamp(4.0, 100.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.red.shade400,
                  Colors.blue.shade400,
                  Colors.green.shade400,
                ],
                stops: [0, carbs / total, (carbs + protein) / total],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(List<Map<String, dynamic>> weekData) {
    final avgCarbs =
        weekData.map((d) => (d['carbs'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a + b) / 7;
    final avgProtein =
        weekData.map((d) => (d['protein'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a + b) / 7;
    final avgFat =
        weekData.map((d) => (d['fat'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a + b) / 7;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Averages',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSummaryMetric(
                  '${avgCarbs.toStringAsFixed(1)}g',
                  'Carbs',
                  Colors.red.shade400,
                ),
              ),
              Expanded(
                child: _buildSummaryMetric(
                  '${avgProtein.toStringAsFixed(1)}g',
                  'Protein',
                  Colors.blue.shade400,
                ),
              ),
              Expanded(
                child: _buildSummaryMetric(
                  '${avgFat.toStringAsFixed(1)}g',
                  'Fat',
                  Colors.green.shade400,
                ),
              ),
            ],
          ),
        ],
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

  List<Map<String, dynamic>> _getEmptyWeekData() {
    final today = DateTime.now();
    final result = <Map<String, dynamic>>[];
    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      result.add({
        'date': date.toIso8601String().split('T').first,
        'carbs': 0.0,
        'protein': 0.0,
        'fat': 0.0,
      });
    }
    return result;
  }
}
