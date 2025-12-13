import 'package:flutter/material.dart';
import 'package:metabolicapp/services/food_database_service.dart';

class FoodDetailsPage extends StatefulWidget {
  final int foodCode;
  final String foodName;

  const FoodDetailsPage({
    super.key,
    required this.foodCode,
    required this.foodName,
  });

  @override
  State<FoodDetailsPage> createState() => _FoodDetailsPageState();
}

class _FoodDetailsPageState extends State<FoodDetailsPage> {
  bool _loading = true;
  Map<String, double> _macros = {};

  @override
  void initState() {
    super.initState();
    _loadNutrition();
  }

  Future<void> _loadNutrition() async {
    final macros =
    await FoodDatabaseService.getKetoMacros(widget.foodCode, 100);

    setState(() {
      _macros = macros;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.foodName),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.foodName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Per 100g',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            _macroRow(
              'Calories',
              _macros['calories'] ?? 0,
              'kcal',
            ),
            _macroRow(
              'Protein',
              _macros['protein'] ?? 0,
              'g',
            ),
            _macroRow(
              'Fat',
              _macros['fat'] ?? 0,
              'g',
            ),
            _macroRow(
              'Net Carbs',
              _macros['netCarbs'] ?? 0,
              'g',
            ),
          ],
        ),
      ),
    );
  }

  Widget _macroRow(String label, double value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          Text(
            '${value.toStringAsFixed(1)} $unit',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
