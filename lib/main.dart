import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/themes/app_theme.dart';
import 'services/food_database_service.dart';

void main() {
  runApp(const ProviderScope(child: MetabolicHealthApp()));
}

class MetabolicHealthApp extends StatelessWidget {
  const MetabolicHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appRouter = AppRouter();

    return MaterialApp.router(
      title: 'Metabolic Health Companion',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: appRouter.config(),
      debugShowCheckedModeBanner: false,
    );
  }
}

void testDB() async {
  var foods = await FoodDatabaseService.searchFoods("egg");
  print(foods);

  var nutrients = await FoodDatabaseService.getFoodNutrients(11111000);
  print(nutrients);

  var macros = await FoodDatabaseService.getKetoMacros(11111000, 150);
  print(macros);
}

