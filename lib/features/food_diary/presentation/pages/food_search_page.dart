import 'package:flutter/material.dart';
import 'package:metabolicapp/services/food_database_service.dart';
import 'package:metabolicapp/features/food_diary/domain/entities/food_entry.dart';
import 'food_details_page.dart';

class FoodSearchPage extends StatefulWidget {
  /// If viewOnly = true, search opens FoodDetailsPage in view mode and does NOT return FoodEntry.
  final bool viewOnly;

  /// Only used when viewOnly = false (add mode).
  final DateTime? initialTime;

  const FoodSearchPage({
    super.key,
    this.viewOnly = false,
    this.initialTime,
  });

  @override
  State<FoodSearchPage> createState() => _FoodSearchPageState();
}

class _FoodSearchPageState extends State<FoodSearchPage> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() => _loading = true);

    final foods = await FoodDatabaseService.searchFoods(query);

    if (!mounted) return;

    setState(() {
      _results = foods;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openFood(Map<String, dynamic> food) async {
    final int code = food["food_code"];
    final String name = food["main_food_description"];

    if (widget.viewOnly) {
      // ✅ View-only: just push details, no return value
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FoodDetailsPage(
            foodCode: code,
            foodName: name,
            viewOnly: true,
          ),
        ),
      );
      return;
    }

    // ✅ Add-mode: push details and expect a FoodEntry back
    final entry = await Navigator.push<FoodEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => FoodDetailsPage(
          foodCode: code,
          foodName: name,
          viewOnly: false,
          initialTime: widget.initialTime ?? DateTime.now(),
        ),
      ),
    );

    if (entry != null && mounted) {
      Navigator.pop(context, entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.viewOnly ? "Search Food" : "Add Food"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: "Search foods (egg, chicken...)",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),

          if (_loading) const LinearProgressIndicator(),

          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (_, i) {
                final food = _results[i];
                return ListTile(
                  title: Text(food["main_food_description"]),
                  subtitle: Text('ID: ${food["food_code"]}'),
                  onTap: () => _openFood(food),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
