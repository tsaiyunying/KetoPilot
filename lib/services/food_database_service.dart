import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

// Needed to return Macronutrients for FoodEntry
import 'package:metabolicapp/features/food_diary/domain/entities/food_entry.dart';

class FoodDatabaseService {
  static Database? _db;
  static const String _dbName = "usda_foods.db";

  /// Open database (copy from assets on first run)
  static Future<Database> get database async {
    if (_db != null) return _db!;

    final dbDir = await getDatabasesPath();
    final dbPath = p.join(dbDir, _dbName);

    final exists = await File(dbPath).exists();
    if (!exists) {
      await Directory(dbDir).create(recursive: true);
      final data = await rootBundle.load("assets/$_dbName");
      final bytes =
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(dbPath).writeAsBytes(bytes, flush: true);
    }

    _db = await openDatabase(dbPath, readOnly: true);
    return _db!;
  }

  /// Search foods by name
  static Future<List<Map<String, dynamic>>> searchFoods(String query) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT food_code, main_food_description
      FROM foods
      WHERE main_food_description LIKE ?
      ORDER BY main_food_description
      LIMIT 25
      ''',
      ['%$query%'],
    );
  }

  /// Get portion options (cups, tbsp, etc.)
  static Future<List<Map<String, dynamic>>> getFoodPortions(int foodCode) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT portion_description, gram_weight
      FROM food_portions
      WHERE food_code = ?
      ORDER BY gram_weight
      ''',
      [foodCode],
    );
  }

  /// Get ALL nutrients for a food (per 100g)
  /// Used for debugging or detailed nutrient views
  static Future<List<Map<String, dynamic>>> getFoodNutrients(
      int foodCode,
      ) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT
        n.tagname,
        n.nutrient_description,
        fn.nutrient_value,
        n.unit
      FROM food_nutrients fn
      JOIN nutrients n
        ON fn.nutrient_code = n.nutrient_code
      WHERE fn.food_code = ?
      ORDER BY n.tagname
      ''',
      [foodCode],
    );
  }

  /// Fetch specific nutrients and scale by grams
  static Future<Map<String, double>> getNutrientsForGramsByTags(
      int foodCode,
      double grams,
      List<String> tags,
      ) async {
    final db = await database;

    final placeholders = List.filled(tags.length, '?').join(',');
    final rows = await db.rawQuery(
      '''
      SELECT n.tagname, fn.nutrient_value
      FROM food_nutrients fn
      JOIN nutrients n ON fn.nutrient_code = n.nutrient_code
      WHERE fn.food_code = ?
        AND n.tagname IN ($placeholders)
      ''',
      [foodCode, ...tags],
    );

    final factor = grams / 100.0;
    final out = <String, double>{};

    for (final row in rows) {
      final tag = row['tagname'] as String;
      final v100 = (row['nutrient_value'] as num?)?.toDouble() ?? 0.0;
      out[tag] = double.parse((v100 * factor).toStringAsFixed(2));
    }

    return out;
  }

  /// Keto-focused macro map (legacy / utility use)
  static Future<Map<String, double>> getKetoMacros(
      int foodCode,
      double grams,
      ) async {
    final all = await getNutrientsForGramsByTags(
      foodCode,
      grams,
      const ['CHOCDF', 'FIBTG', 'FAT', 'PROT', 'ENERC_KCAL', 'SUGAR'],
    );

    final carbs = all['CHOCDF'] ?? 0.0;
    final fiber = all['FIBTG'] ?? 0.0;
    final netCarbs = carbs - fiber;

    return {
      'netCarbs': double.parse(netCarbs.toStringAsFixed(2)),
      'fat': all['FAT'] ?? 0.0,
      'protein': all['PROT'] ?? 0.0,
      'calories': all['ENERC_KCAL'] ?? 0.0,
      'carbs': carbs,
      'fiber': fiber,
      'sugar': all['SUGAR'] ?? 0.0,
    };
  }

  /// ✅ Main method used by FoodDetailsPage → FoodEntry
  static Future<Macronutrients> getMacrosForFoodEntry(
      int foodCode,
      double grams,
      ) async {
    final all = await getNutrientsForGramsByTags(
      foodCode,
      grams,
      const ['CHOCDF', 'FIBTG', 'FAT', 'PROT', 'ENERC_KCAL'],
    );

    final carbs = all['CHOCDF'] ?? 0.0;
    final fiber = all['FIBTG'] ?? 0.0;
    final netCarbs = double.parse((carbs - fiber).toStringAsFixed(2));

    return Macronutrients(
      carbs: carbs,
      protein: all['PROT'] ?? 0.0,
      fat: all['FAT'] ?? 0.0,
      fiber: fiber,
      netCarbs: netCarbs,
      calories: all['ENERC_KCAL'] ?? 0.0,
    );
  }
}
