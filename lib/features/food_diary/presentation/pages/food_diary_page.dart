import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/themes/app_theme.dart';
import '../widgets/macro_bars_widget.dart';
import 'food_search_page.dart';
import '../../domain/entities/food_entry.dart';

@RoutePage()
class FoodDiaryPage extends StatefulWidget {
  const FoodDiaryPage({super.key});

  @override
  State<FoodDiaryPage> createState() => _FoodDiaryPageState();
}

class _FoodDiaryPageState extends State<FoodDiaryPage> {
  DateTime _selectedDate = DateTime.now();

  double _carbsConsumed = 0;
  double _proteinConsumed = 0;
  double _fatConsumed = 0;

  final double _carbsLimit = 20;
  final double _proteinGoal = 100;
  final double _fatGoal = 150;

  final List<_FoodEntryData> _todaysEntries = [];

  // ✅ View-only search (top-right icon)
  void _searchFoodViewOnly() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const FoodSearchPage(viewOnly: true),
      ),
    );
  }

  Future<void> _addFoodAtTime(DateTime time) async {
    final entry = await Navigator.push<FoodEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => FoodSearchPage(
          viewOnly: false,
          initialTime: time,
        ),
      ),
    );

    if (entry == null) return;

    setState(() {
      _todaysEntries.add(
        _FoodEntryData(
          name: entry.name,
          carbs: entry.macros.netCarbs, // tracking net carbs
          protein: entry.macros.protein,
          fat: entry.macros.fat,
          calories: entry.macros.calories,
          timestamp: entry.timestamp,
          servingSize: '${entry.servingSize} ${entry.servingUnit}',
        ),
      );

      _carbsConsumed += entry.macros.netCarbs;
      _proteinConsumed += entry.macros.protein;
      _fatConsumed += entry.macros.fat;
    });
  }

  void _addFood() => _addFoodAtTime(DateTime.now());

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Diary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _searchFoodViewOnly, // ✅ view-only search
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFood, // ✅ add-mode
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                DateFormat('EEE, MMM d').format(_selectedDate),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          MacroBarsWidget(
            carbsGrams: _carbsConsumed,
            proteinGrams: _proteinConsumed,
            fatGrams: _fatConsumed,
            carbsLimit: _carbsLimit,
            proteinGoal: _proteinGoal,
            fatGoal: _fatGoal,
          ),
          Expanded(child: _buildTimeline()),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    final sorted = [..._todaysEntries]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (sorted.isEmpty) {
      return const Center(
        child: Text('No entries yet. Tap + to add food.'),
      );
    }

    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (_, i) {
        final e = sorted[i];
        return ListTile(
          title: Text(e.name),
          subtitle: Text(
            '${DateFormat('h:mm a').format(e.timestamp)} • ${e.servingSize}',
          ),
          trailing: Text('${e.calories.toStringAsFixed(0)} kcal'),
        );
      },
    );
  }
}

class _FoodEntryData {
  final String name;
  final double carbs;
  final double protein;
  final double fat;
  final double calories;
  final DateTime timestamp;
  final String servingSize;

  _FoodEntryData({
    required this.name,
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.calories,
    required this.timestamp,
    required this.servingSize,
  });
}
