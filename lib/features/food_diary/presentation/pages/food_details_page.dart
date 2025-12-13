import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:metabolicapp/services/food_database_service.dart';
import 'package:metabolicapp/features/food_diary/domain/entities/food_entry.dart';

class FoodDetailsPage extends StatefulWidget {
  final int foodCode;
  final String foodName;
  final DateTime initialTime;

  const FoodDetailsPage({
    super.key,
    required this.foodCode,
    required this.foodName,
    required this.initialTime,
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
  late DateTime _time;

  @override
  void initState() {
    super.initState();
    _time = widget.initialTime;
    _recalculate();
  }

  Future<void> _recalculate() async {
    setState(() => _loading = true);

    final grams = double.tryParse(_gramsController.text) ?? 100;
    final macros = await FoodDatabaseService.getMacrosForFoodEntry(
      widget.foodCode,
      grams,
    );

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
  Widget build(BuildContext context) {
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

            ElevatedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.access_time),
              label: const Text('Pick Time'),
            ),

            const SizedBox(height: 24),

            if (_loading)
              const CircularProgressIndicator()
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Calories: ${_macros!.calories} kcal'),
                  Text('Protein: ${_macros!.protein} g'),
                  Text('Fat: ${_macros!.fat} g'),
                  Text('Net Carbs: ${_macros!.netCarbs} g'),
                ],
              ),

            const Spacer(),

            ElevatedButton.icon(
              onPressed: _addToDiary,
              icon: const Icon(Icons.add),
              label: const Text('Add to Diary'),
            ),
          ],
        ),
      ),
    );
  }
}
