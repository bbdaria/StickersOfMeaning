import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/preferences_screen.dart';
import 'screens/sticker_search_screen.dart';
import 'screens/todays_sticker_screen.dart';

class StickersApp extends StatelessWidget {
  const StickersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stickers of meaning',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: HomeScreen.routeName,
      routes: {
        HomeScreen.routeName: (_) => const HomeScreen(),
        PreferencesScreen.routeName: (_) => const PreferencesScreen(),
        StickerSearchScreen.routeName: (_) => const StickerSearchScreen(),
        TodaysStickerScreen.routeName: (_) => const TodaysStickerScreen(),
      },
    );
  }
}
