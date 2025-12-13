import 'package:flutter/material.dart';
import 'package:metabolicapp/services/food_database_service.dart';
import 'food_details_page.dart';

class FoodSearchPage extends StatefulWidget {
  const FoodSearchPage({Key? key}) : super(key: key);

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
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: "Search for foods (egg, chicken...)",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),

          if (_loading)
            const LinearProgressIndicator(),

          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (_, i) {
                final f = _results[i];
                return ListTile(
                  title: Text(f["main_food_description"]),
                  subtitle: Text("ID: ${f["food_code"]}"),
                  onTap: () {
                    Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => FoodDetailsPage(
                                foodCode: f["food_code"],
                                foodName: f["main_food_description"],
                            ),
                        ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
