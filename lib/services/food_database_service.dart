import 'dart:io';
import 'package:flutter/material.dart';
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

    Future<void> copyFromAsset() async {
      await Directory(dbDir).create(recursive: true);
      final data = await rootBundle.load("assets/$_dbName");
      final bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(dbPath).writeAsBytes(bytes, flush: true);
    }

    if (!await File(dbPath).exists()) {
      await copyFromAsset();
    }

    try {
      _db = await openDatabase(
        dbPath,
        readOnly: false,
        onOpen: (db) async {
          await _initUserTables(db);
        },
      );
    } catch (e) {
      // ✅ Handle case where old DB was read-only
      if (e.toString().contains('readonly') || e.toString().contains('READONLY')) {
        print("⚠️ Database read-only error detected. Recreating database...");
        await File(dbPath).delete();
        await copyFromAsset();

        _db = await openDatabase(
          dbPath,
          readOnly: false,
          onOpen: (db) async {
            await _initUserTables(db);
          },
        );
      } else {
        rethrow;
      }
    }
    return _db!;
  }

  static Future<void> _initUserTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS food_diary (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        timestamp_ms INTEGER NOT NULL,
        serving_size REAL NOT NULL,
        serving_unit TEXT NOT NULL,
        calories REAL NOT NULL,
        carbs REAL NOT NULL,
        protein REAL NOT NULL,
        fat REAL NOT NULL,
        fiber REAL NOT NULL,
        net_carbs REAL NOT NULL,
        notes TEXT,
        brand TEXT,
        meal_type TEXT
      )
    ''');
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS biomarkers (
        date TEXT PRIMARY KEY,
        glucose REAL,
        bhb REAL,
        weight REAL
      )
    ''');
  }

  // ─── SETTINGS METHODS ──────────────────────────────────────────────
  // ... (keep existing settings methods)

  // ─── BIOMARKER METHODS ──────────────────────────────────────────────

  static Future<void> saveBiomarkers({
    required DateTime date,
    required double glucose,
    required double bhb,
    double? weight,
  }) async {
    final db = await database;
    final dateStr = DateUtils.dateOnly(date).toIso8601String().split('T').first;
    
    await db.insert(
      'biomarkers',
      {
        'date': dateStr,
        'glucose': glucose,
        'bhb': bhb,
        'weight': weight,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Map<String, dynamic>?> getBiomarkers(DateTime date) async {
    final db = await database;
    final dateStr = DateUtils.dateOnly(date).toIso8601String().split('T').first;

    final maps = await db.query(
      'biomarkers',
      where: 'date = ?',
      whereArgs: [dateStr],
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> getBiomarkersHistory(
      DateTime startDate, int days) async {
    final db = await database;
    // We want the last N days up to startDate
    // Actually typically we want [startDate - days, startDate]
    // Let's assume startDate is the latest day.
    
    final end = DateUtils.dateOnly(startDate);
    final start = end.subtract(Duration(days: days - 1));
    
    final startStr = start.toIso8601String().split('T').first;
    final endStr = end.toIso8601String().split('T').first;

    return db.query(
      'biomarkers',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startStr, endStr],
      orderBy: 'date DESC',
    );
  }

  // ─── SETTINGS METHODS ──────────────────────────────────────────────

  static Future<void> saveUserSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'user_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<String?> getUserSetting(String key) async {
    final db = await database;
    final maps = await db.query(
      'user_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String;
    }
    return null;
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
      const ['CHOCDF', 'FIBTG', 'FAT', 'PROCNT', 'ENERC_KCAL', 'SUGAR'],
    );

    final carbs = all['CHOCDF'] ?? 0.0;
    final fiber = all['FIBTG'] ?? 0.0;
    final netCarbs = carbs - fiber;

    return {
      'netCarbs': double.parse(netCarbs.toStringAsFixed(2)),
      'fat': all['FAT'] ?? 0.0,
      'protein': all['PROCNT'] ?? 0.0,
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
      const ['CHOCDF', 'FIBTG', 'FAT', 'PROCNT', 'ENERC_KCAL'],
    );

    final carbs = all['CHOCDF'] ?? 0.0;
    final fiber = all['FIBTG'] ?? 0.0;
    final netCarbs = double.parse((carbs - fiber).toStringAsFixed(2));

    return Macronutrients(
      carbs: carbs,
      protein: all['PROCNT'] ?? 0.0,
      fat: all['FAT'] ?? 0.0,
      fiber: fiber,
      netCarbs: netCarbs,
      calories: all['ENERC_KCAL'] ?? 0.0,
    );
  }

  // ─── USER DIARY METHODS ──────────────────────────────────────────────

  static Future<void> addDiaryEntry(FoodEntry entry) async {
    final db = await database;
    await db.insert(
      'food_diary',
      {
        'id': entry.id,
        'name': entry.name,
        'timestamp_ms': entry.timestamp.millisecondsSinceEpoch,
        'serving_size': entry.servingSize,
        'serving_unit': entry.servingUnit,
        'calories': entry.macros.calories,
        'carbs': entry.macros.carbs,
        'protein': entry.macros.protein,
        'fat': entry.macros.fat,
        'fiber': entry.macros.fiber,
        'net_carbs': entry.macros.netCarbs,
        'notes': entry.notes,
        'brand': entry.brand,
        'meal_type': entry.mealType,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> deleteDiaryEntry(String id) async {
    final db = await database;
    await db.delete('food_diary', where: 'id = ?', whereArgs: [id]);
  }

  /// Get entries for a specific day
  static Future<List<FoodEntry>> getDiaryEntries(DateTime date) async {
    final db = await database;
    
    // Filter by START and END of the local day
    final start = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59, 999).millisecondsSinceEpoch;

    final maps = await db.query(
      'food_diary',
      where: 'timestamp_ms BETWEEN ? AND ?',
      whereArgs: [start, end],
      orderBy: 'timestamp_ms ASC',
    );

    return maps.map((m) {
      return FoodEntry(
        id: m['id'] as String,
        name: m['name'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(m['timestamp_ms'] as int),
        servingSize: m['serving_size'] as double,
        servingUnit: m['serving_unit'] as String,
        macros: Macronutrients(
          carbs: m['carbs'] as double,
          protein: m['protein'] as double,
          fat: m['fat'] as double,
          fiber: m['fiber'] as double,
          netCarbs: m['net_carbs'] as double,
          calories: m['calories'] as double,
        ),
        notes: m['notes'] as String?,
        brand: m['brand'] as String?,
        mealType: m['meal_type'] as String?,
      );
    }).toList();
  }
}
