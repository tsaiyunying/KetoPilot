import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class FoodDatabaseService {
  static Database? _db;
  static const String _dbName = "usda_foods.db";

  /// Initialize and open the database
  static Future<Database> get database async {
    if (_db != null) return _db!;

    Directory dir = await getApplicationDocumentsDirectory();
    String dbPath = p.join(dir.path, _dbName);

    // If DB does not exist → copy from assets
    if (!File(dbPath).existsSync()) {
      ByteData data = await rootBundle.load("assets/$_dbName");
      List<int> bytes = data.buffer.asUint8List();
      await File(dbPath).writeAsBytes(bytes, flush: true);
    }

    _db = await openDatabase(dbPath);
    return _db!;
  }

  /// Search foods by name
  static Future<List<Map<String, dynamic>>> searchFoods(String query) async {
    final db = await database;
    return db.rawQuery(
      """
      SELECT food_code, main_food_description
      FROM foods
      WHERE main_food_description LIKE ?
      LIMIT 25
      """,
      ['%$query%'],
    );
  }

  /// Get details for one food (all nutrients)
  static Future<List<Map<String, dynamic>>> getFoodNutrients(int foodCode) async {
    final db = await database;
    return db.rawQuery(
      """
      SELECT n.tagname, n.nutrient_description, fn.nutrient_value, n.unit
      FROM food_nutrients fn
      JOIN nutrients n ON fn.nutrient_code = n.nutrient_code
      WHERE fn.food_code = ?
      ORDER BY n.tagname
      """,
      [foodCode],
    );
  }

  /// Get serving sizes (portion options)
  static Future<List<Map<String, dynamic>>> getFoodPortions(int foodCode) async {
    final db = await database;
    return db.rawQuery(
      """
      SELECT portion_description, gram_weight
      FROM food_portions
      WHERE food_code = ?
      """,
      [foodCode],
    );
  }

  /// Calculate nutrient values for arbitrary grams
  static Future<Map<String, double>> getNutrientsForGrams(
      int foodCode,
      double grams,
      ) async {
    final nutrients = await getFoodNutrients(foodCode);
    Map<String, double> result = {};

    for (var row in nutrients) {
      final String tag = row['tagname'];
      final double value100g = row['nutrient_value'];

      // scale to desired grams
      result[tag] = double.parse((value100g * grams / 100).toStringAsFixed(2));
    }

    return result;
  }

  /// Special keto macros (net carbs, fat, protein, calories)
  static Future<Map<String, double>> getKetoMacros(
      int foodCode,
      double grams,
      ) async {
    final all = await getNutrientsForGrams(foodCode, grams);

    double carbs = all["CHOCDF"] ?? 0.0;
    double fiber = all["FIBTG"] ?? 0.0;
    double netCarbs = carbs - fiber;
    double fat = all["FAT"] ?? 0.0;
    double protein = all["PROT"] ?? 0.0;
    double calories = all["ENERC_KCAL"] ?? 0.0;

    return {
      "netCarbs": double.parse(netCarbs.toStringAsFixed(2)),
      "fat": fat,
      "protein": protein,
      "calories": calories,
    };
  }
}
