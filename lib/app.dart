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
        // Updated seed color to match your gradient
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2596be)),
        useMaterial3: true,
        // Global AppBar theme: White background, Black icons
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white, // Ensures it stays white in Material 3
          iconTheme: IconThemeData(color: Colors.black),
          actionsIconTheme: IconThemeData(color: Colors.black),
          elevation: 0,
        ),
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