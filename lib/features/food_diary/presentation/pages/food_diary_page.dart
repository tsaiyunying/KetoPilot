import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/themes/app_theme.dart';
import '../widgets/macro_bars_widget.dart';
import 'food_search_page.dart';
import '../../domain/entities/food_entry.dart';

// ✅ make sure this path matches your project
import '../../../../core/state/nutrition_log_provider.dart';

@RoutePage()
class FoodDiaryPage extends ConsumerStatefulWidget {
  const FoodDiaryPage({super.key});

  @override
  ConsumerState<FoodDiaryPage> createState() => _FoodDiaryPageState();
}

class _FoodDiaryPageState extends ConsumerState<FoodDiaryPage> {
  // Local date state synced with provider
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Ensure provider is loaded for today (or sync)
    // Defer to next frame to avoid build conflicts if needed, but provider init handles today.
  }

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

    // ✅ 1) Update global nutrition provider (Dashboard + this page's bars read it)
    await ref.read(nutritionLogProvider.notifier).addEntry(entry);
    // No local set state needed, provider updates UI
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
      // ✅ Update provider to load selected date
      await ref.read(nutritionLogProvider.notifier).loadDate(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ READ GLOBAL NUTRITION STATE HERE
    final nutrition = ref.watch(nutritionLogProvider);

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
                DateFormat('EEE, MMM d').format(nutrition.date), // Use provider date
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),

          // ✅ IMPORTANT CHANGE: Bars now use provider totals + provider targets
          MacroBarsWidget(
            carbsGrams: nutrition.carbsConsumed,
            proteinGrams: nutrition.proteinConsumed,
            fatGrams: nutrition.fatConsumed,
            carbsLimit: nutrition.carbsTarget,
            proteinGoal: nutrition.proteinTarget,
            fatGoal: nutrition.fatTarget,
          ),

          Expanded(child: _buildTimeline(nutrition.entries)),
        ],
      ),
    );
  }

  Widget _buildTimeline(List<FoodEntry> entries) {
    if (entries.isEmpty) {
      return const Center(
        child: Text('No entries yet. Tap + to add food.'),
      );
    }

    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final e = entries[i];
        return ListTile(
          title: Text(e.name),
          subtitle: Text(
            '${DateFormat('h:mm a').format(e.timestamp)} • ${e.servingSize} ${e.servingUnit}',
          ),
          trailing: Text('${e.macros.calories.toStringAsFixed(0)} kcal'),
        );
      },
    );
  }
}


