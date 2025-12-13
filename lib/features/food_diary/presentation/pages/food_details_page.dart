import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:metabolicapp/services/food_database_service.dart';
import 'package:metabolicapp/features/food_diary/domain/entities/food_entry.dart';

class FoodDetailsPage extends StatefulWidget {
  final int foodCode;
  final String foodName;

  /// If viewOnly = true, we just show nutrients and DO NOT return a FoodEntry.
  final bool viewOnly;

  /// Only needed when viewOnly = false (add mode).
  final DateTime? initialTime;

  const FoodDetailsPage({
    super.key,
    required this.foodCode,
    required this.foodName,
    this.viewOnly = false,
    this.initialTime,
  });

  @override
  State<FoodDetailsPage> createState() => _FoodDetailsPageState();
}

class _FoodDetailsPageState extends State<FoodDetailsPage> {
  final TextEditingController _gramsController =
  TextEditingController(text: '100');
  final _uuid = const Uuid();

  bool _loading = true;
  Macronutrients? _macros;

  // Only used for add mode
  late DateTime _time;

  @override
  void initState() {
    super.initState();

    // In viewOnly mode, time is irrelevant; in add mode, we need a time.
    _time = widget.initialTime ?? DateTime.now();

    _recalculate();
  }

  Future<void> _recalculate() async {
    setState(() => _loading = true);

    final grams = double.tryParse(_gramsController.text) ?? 100;

    final macros = await FoodDatabaseService.getMacrosForFoodEntry(
      widget.foodCode,
      grams,
    );

    if (!mounted) return;

    setState(() {
      _macros = macros;
      _loading = false;
    });
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_time),
    );
    if (t == null) return;

    setState(() {
      _time = DateTime(
        _time.year,
        _time.month,
        _time.day,
        t.hour,
        t.minute,
      );
    });
  }

  void _addToDiary() {
    if (_macros == null) return;

    final grams = double.tryParse(_gramsController.text) ?? 100;

    final entry = FoodEntry(
      id: _uuid.v4(),
      name: widget.foodName,
      timestamp: _time,
      servingSize: grams,
      servingUnit: 'g',
      macros: _macros!,
    );

    Navigator.pop(context, entry);
  }

  @override
  void dispose() {
    _gramsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grams = double.tryParse(_gramsController.text) ?? 100;

    return Scaffold(
      appBar: AppBar(title: Text(widget.foodName)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _gramsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Weight (grams)'),
              onChanged: (_) => _recalculate(),
            ),

            const SizedBox(height: 12),

            // ✅ Only show time picker in ADD mode
            if (!widget.viewOnly) ...[
              ElevatedButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.access_time),
                label: Text(
                  'Time: ${TimeOfDay.fromDateTime(_time).format(context)}',
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
              const SizedBox(height: 12),
            ],

            if (_loading)
              const CircularProgressIndicator()
            else if (_macros != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'For ${grams.toStringAsFixed(0)} g',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Text('Calories: ${_macros!.calories.toStringAsFixed(0)} kcal'),
                  Text('Protein: ${_macros!.protein.toStringAsFixed(1)} g'),
                  Text('Fat: ${_macros!.fat.toStringAsFixed(1)} g'),
                  Text('Net Carbs: ${_macros!.netCarbs.toStringAsFixed(1)} g'),
                  Text('Fiber: ${_macros!.fiber.toStringAsFixed(1)} g'),
                ],
              ),

            const Spacer(),

            // ✅ Only show "Add to Diary" in ADD mode
            if (!widget.viewOnly)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _addToDiary,
                  icon: const Icon(Icons.add),
                  label: const Text('Add to Diary'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
