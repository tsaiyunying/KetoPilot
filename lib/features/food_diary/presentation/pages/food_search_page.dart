import 'package:flutter/material.dart';
import 'package:metabolicapp/services/food_database_service.dart';
import 'package:metabolicapp/features/food_diary/domain/entities/food_entry.dart';
import 'food_details_page.dart';

class FoodSearchPage extends StatefulWidget {
  final DateTime initialTime;

  const FoodSearchPage({
    super.key,
    required this.initialTime,
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

    setState(() {
      _results = foods;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Search Food")),
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
                  onTap: () async {
                    final entry = await Navigator.push<FoodEntry>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FoodDetailsPage(
                          foodCode: food["food_code"],
                          foodName: food["main_food_description"],
                          initialTime: widget.initialTime,
                        ),
                      ),
                    );

                    if (entry != null && mounted) {
                      Navigator.pop(context, entry);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
